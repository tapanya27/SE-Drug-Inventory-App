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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Warehouse Selector ---
            if (_warehouses.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedWarehouseId,
                    dropdownColor: AppColors.cardColor,
                    isExpanded: true,
                    icon: const Icon(Icons.warehouse_rounded, color: AppColors.primaryAccent),
                    hint: const Text('Select Supplier Warehouse'),
                    items: _warehouses.map((w) {
                      return DropdownMenuItem<int>(
                        value: w['id'],
                        child: Text(w['name'], style: const TextStyle(color: Colors.white)),
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
            if (_selectedWarehouseId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'DEBUG: Selected Warehouse ID: $_selectedWarehouseId',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _error != null 
                  ? Center(child: Text('Error: $_error'))
                  : _filteredCatalog.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          Text('No inventory found at this warehouse.', style: TextStyle(color: Colors.white38)),
                        ],
                      ))
                    : ListView.builder(
                        itemCount: _filteredCatalog.length,
                        itemBuilder: (context, index) {
                          final item = _filteredCatalog[index];
                          final id = item['id'] as int;
                          final inStock = (item['stock'] as int) > 0;
                          final quantity = _cart[id] ?? 0;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Price: \$${((item['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              inStock ? Icons.check_circle : Icons.cancel,
                                              size: 16,
                                              color: inStock ? AppColors.primaryAccent : AppColors.error,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              inStock ? 'In Stock (${item['stock']})' : 'Out of Stock',
                                              style: TextStyle(
                                                color: inStock ? AppColors.primaryAccent : AppColors.error,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '[Owner: ${item['owner_id']}]',
                                              style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 20),
                                          onPressed: (!inStock || quantity <= 0) ? null : () {
                                            setState(() {
                                              _cart[id] = quantity - 1;
                                            });
                                          },
                                        ),
                                        Text(
                                          '$quantity',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 20),
                                          onPressed: (!inStock || (item['stock'] as int) <= quantity) ? null : () {
                                            setState(() {
                                              _cart[id] = quantity + 1;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
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

      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryAccent,
                        ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _totalPrice > 0 ? _submitOrder : null,
                icon: const Icon(Icons.send),
                label: const Text('Submit Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
