import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  List<dynamic> _catalog = [];
  List<dynamic> _warehouses = [];
  int? _selectedWarehouseId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final warehouseData = await ApiService.getWarehouses();
      setState(() {
        _warehouses = warehouseData;
        
        // Auto-select first warehouse if available and none selected
        if (_warehouses.isNotEmpty && _selectedWarehouseId == null) {
          _selectedWarehouseId = _warehouses.first['id'];
        }
      });
      
      // Fetch inventory for the selected warehouse
      if (_selectedWarehouseId != null) {
        await _fetchWarehouseInventory(_selectedWarehouseId!);
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchWarehouseInventory(int warehouseId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _catalog = []; // Clear current items while loading new ones
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fetching inventory for Warehouse $warehouseId...'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blueGrey,
      ),
    );

    try {
      final inventory = await ApiService.getInventory(warehouseId: warehouseId);
      setState(() {
        _catalog = inventory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Map to store selected quantities: productId -> quantity
  final Map<int, int> _cart = {};

  List<dynamic> get _filteredCatalog {
    return _catalog; // Backend already filtered it for us
  }

  double get _totalPrice {
    double total = 0;
    final filtered = _filteredCatalog;
    for (var item in filtered) {
      final id = item['id'] as int;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = _cart[id] ?? 0;
      total += price * quantity;
    }
    return total;
  }

  void _submitOrder() {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a warehouse first.')),
      );
      return;
    }

    if (_totalPrice == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to your order.')),
      );
      return;
    }

    // Prepare items for API
    final filtered = _filteredCatalog;
    final orderItems = _cart.entries
        .where((e) => e.value > 0)
        .where((e) => filtered.any((c) => c['id'] == e.key)) // Ensure item belongs to selected warehouse
        .map((e) {
          final matches = filtered.where((c) => c['id'] == e.key);
          final String name = matches.isNotEmpty ? (matches.first['name'] ?? 'Unknown') : 'Unknown';
          final double price = matches.isNotEmpty ? ((matches.first['price'] as num?)?.toDouble() ?? 0.0) : 0.0;
          return {
            'medicine_id': e.key,
            'quantity': e.value,
            'drug_name': name,
            'price': price,
          };
        })
        .toList();

    if (orderItems.isEmpty) return;

    // Navigate to the Payment Checkout simulation
    context.go('/payment_simulation', extra: {
      'amount': _totalPrice,
      'items': orderItems,
      'warehouse_id': _selectedWarehouseId,
    });
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
          'Replenish Inventory',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimaryLight),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
      ),
      body: Column(
        children: [
          _buildWarehouseSelector(theme),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null 
                ? _buildErrorState() 
                : _buildProductCatalog(theme),
          ),
          if (_totalPrice > 0) _buildCheckoutSummary(theme),
        ],
      ),
    );
  }

  Widget _buildWarehouseSelector(ThemeData theme) {
    if (_warehouses.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Fulfillment Warehouse',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
              color: AppColors.backgroundLight,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedWarehouseId,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryAccent),
                items: _warehouses.map((w) {
                  return DropdownMenuItem<int>(
                    value: w['id'],
                    child: Text(w['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedWarehouseId = val;
                      _cart.clear();
                    });
                    _fetchWarehouseInventory(val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog(ThemeData theme) {
    if (_catalog.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.borderLight),
            const SizedBox(height: 16),
            const Text('No products available from this supplier', style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _catalog.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = _catalog[index];
        final id = item['id'] as int;
        final qty = _cart[id] ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? 'Unknown Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('\$${price.toStringAsFixed(2)} per unit', style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        onPressed: qty > 0 ? () => setState(() => _cart[id] = qty - 1) : null,
                        color: qty > 0 ? AppColors.textPrimaryLight : AppColors.borderLight,
                      ),
                      Text(
                        '$qty',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        onPressed: () => setState(() => _cart[id] = qty + 1),
                        color: AppColors.primaryAccent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Order Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  '\$${_totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryAccent),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submitOrder,
                child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Sync Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchInitialData,
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
