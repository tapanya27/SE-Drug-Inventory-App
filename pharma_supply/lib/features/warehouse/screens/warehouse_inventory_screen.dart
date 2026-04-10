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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Warehouse Inventory'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/warehouse_dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box, color: AppColors.primaryAccent),
            tooltip: 'Add From Catalog',
            onPressed: _showCatalogDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search / Filter simulation
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search Inventory (e.g. Paracetamol)',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _error != null 
                  ? Center(child: Text('Error: $_error')) 
                  : ListView.builder(
                      itemCount: _inventory.where((item) => 
                        item['name'].toString().toLowerCase().contains(_searchQuery)
                      ).length,
                      itemBuilder: (context, index) {
                        final filteredList = _inventory.where((item) => 
                          item['name'].toString().toLowerCase().contains(_searchQuery)
                        ).toList();
                        final item = filteredList[index];
                        final stock = item['stock'] as int;
                        final threshold = item['threshold'] as int;
                        final isRequested = item['is_requested'] as bool? ?? false;
                        final status = _calculateStatus(stock, threshold, isRequested);
                        
                        Color statusColor;
                        if (status == 'Healthy') {
                          statusColor = Colors.green;
                        } else if (status == 'Requested') {
                          statusColor = AppColors.primaryAccent;
                        } else if (status == 'Critical' || status == 'Out of Stock') {
                          statusColor = AppColors.error;
                        } else {
                          statusColor = Colors.orange; // Low
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('Threshold: $threshold | Current Stock: $stock',
                                          style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    if (status != 'Healthy' && status != 'Requested')
                                      InkWell(
                                        onTap: () async {
                                          try {
                                            await ApiService.requestStock(item['id']);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Replenishment request sent for ${item['name']}.')),
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
                                        child: const Text('Request Stock', style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold)),
                                      )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
