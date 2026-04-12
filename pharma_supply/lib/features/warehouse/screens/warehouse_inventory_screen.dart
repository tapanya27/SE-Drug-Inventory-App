import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class WarehouseInventoryScreen extends StatefulWidget {
  const WarehouseInventoryScreen({super.key});

  @override
  State<WarehouseInventoryScreen> createState() => _WarehouseInventoryScreenState();
}

class _WarehouseInventoryScreenState extends State<WarehouseInventoryScreen> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final data = await ApiService.getInventory();
      setState(() {
        _inventory = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCatalogDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Products from Catalog'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: FutureBuilder<List<dynamic>>(
                  future: ApiService.getCatalog(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    
                    final catalog = snapshot.data ?? [];
                    // Filter out items already in inventory
                    final available = catalog.where((c) => 
                      !_inventory.any((i) => i['name'] == c['name'])
                    ).toList();

                    if (available.isEmpty) {
                      return const Center(child: Text('No new products available in catalog.'));
                    }

                    return ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final item = available[index];
                        return ListTile(
                          title: Text(item['name']),
                          subtitle: Text('\$${item['price']} | Base threshold: ${item['threshold']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryAccent),
                            onPressed: () async {
                              try {
                                await ApiService.addToInventory(item['id']);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${item['name']} added to your inventory.')),
                                  );
                                  _fetchInventory();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _calculateStatus(int stock, int threshold, bool isRequested) {
    if (isRequested) return 'Requested';
    if (stock <= 0) return 'Out of Stock';
    if (stock <= threshold) return 'Critical';
    if (stock <= threshold * 1.5) return 'Low';
    return 'Healthy';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Warehouse Inventory',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimaryLight),
          onPressed: () => context.go('/warehouse_dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded, color: AppColors.primaryAccent),
            tooltip: 'Import from Catalog',
            onPressed: _showCatalogDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(theme),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null 
                ? _buildErrorState() 
                : _buildInventoryList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search products by name...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: AppColors.backgroundLight,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryList(ThemeData theme) {
    final filteredList = _inventory.where((item) => 
      item['name'].toString().toLowerCase().contains(_searchQuery)
    ).toList();

    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.borderLight),
            const SizedBox(height: 16),
            const Text('No items match your search', style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: filteredList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = filteredList[index];
        final stock = item['stock'] as int;
        final threshold = item['threshold'] as int;
        final isRequested = item['is_requested'] as bool? ?? false;
        final status = _calculateStatus(stock, threshold, isRequested);
        
        Color statusColor;
        switch (status) {
          case 'Healthy': statusColor = AppColors.success; break;
          case 'Requested': statusColor = AppColors.primaryAccent; break;
          case 'Critical':
          case 'Out of Stock': statusColor = AppColors.error; break;
          default: statusColor = AppColors.warning;
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? 'Unknown Item',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Available: $stock units • Threshold: $threshold',
                                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ),
                            if (status != 'Healthy' && status != 'Requested') ...[
                              const SizedBox(height: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _handleRequestStock(item),
                                child: const Text(
                                  'Request Stock',
                                  style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRequestStock(dynamic item) async {
    try {
      await ApiService.requestStock(item['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Replenishment request sent for ${item['name']}.')),
        );
        _fetchInventory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchInventory,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
