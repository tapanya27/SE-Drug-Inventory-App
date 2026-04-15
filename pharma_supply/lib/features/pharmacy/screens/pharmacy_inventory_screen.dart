import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class PharmacyInventoryScreen extends StatefulWidget {
  const PharmacyInventoryScreen({super.key});

  @override
  State<PharmacyInventoryScreen> createState() => _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState extends State<PharmacyInventoryScreen> {
  List<dynamic> _inventory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final data = await ApiService.getInventory(mode: 'personal');
      setState(() {
        _inventory = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
          'Store Inventory',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimaryLight),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
        actions: [
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInventoryHeader(theme),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null 
                ? _buildErrorState() 
                : _buildInventoryList(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/place_order'),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text('Replenish Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryAccent,
      ),
    );
  }

  Widget _buildInventoryHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor and manage your pharmacy\'s current medicine stock levels',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(ThemeData theme) {
    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.borderLight),
            const SizedBox(height: 16),
            const Text('No inventory records found', style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 100),
      itemCount: _inventory.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _inventory[index];
        final stock = item['stock'] as int;
        final threshold = item['threshold'] as int;
        
        bool isLow = stock < threshold;
        bool isOut = stock == 0;
        
        Color statusColor = isOut ? AppColors.error : (isLow ? AppColors.warning : AppColors.success);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isOut ? Icons.block_flipped : (isLow ? Icons.warning_amber_rounded : Icons.medication_rounded),
                color: statusColor,
              ),
            ),
            title: Text(
              item['name'] ?? 'Unknown Medicine',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Min Threshold: $threshold',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                  if (stock > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => _handleConsumeStock(item),
                        child: const Text('Consume Units', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$stock',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'units',
                  style: TextStyle(color: statusColor.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleConsumeStock(dynamic item) async {
    final quantityController = TextEditingController(text: '1');
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Consume ${item['name']}'),
          content: TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity to consume'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                final qty = int.tryParse(quantityController.text) ?? 0;
                Navigator.pop(context, qty);
              },
              child: const Text('Consume'),
            ),
          ],
        );
      },
    );

    if (result != null && result > 0) {
      if (result > item['stock']) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot consume more than available stock.'), backgroundColor: AppColors.error));
        return;
      }
      try {
        await ApiService.consumeStock(item['id'], result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Consumed $result units of ${item['name']}.')),
          );
          _fetchInventory();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
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
