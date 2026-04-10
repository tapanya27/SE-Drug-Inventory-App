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
  bool _isLoadingCatalog = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    try {
      final data = await ApiService.getInventory();
      setState(() {
        _catalog = data;
        _isLoadingCatalog = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingCatalog = false;
      });
    }
  }

  // Map to store selected quantities: productId -> quantity
  final Map<int, int> _cart = {};

  double get _totalPrice {
    double total = 0;
    for (var item in _catalog) {
      final id = item['id'] as int;
      final price = item['price'] as double;
      final quantity = _cart[id] ?? 0;
      total += price * quantity;
    }
    return total;
  }

  void _submitOrder() {
    if (_totalPrice == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to your order.')),
      );
      return;
    }

    // Prepare items for API
    final orderItems = _cart.entries
        .where((e) => e.value > 0)
        .map((e) {
          final matches = _catalog.where((c) => c['id'] == e.key);
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

    // Navigate to the Payment Checkout simulation
    context.go('/payment_simulation', extra: {
      'amount': _totalPrice,
      'items': orderItems,
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
            Expanded(
              child: _isLoadingCatalog 
                ? const Center(child: CircularProgressIndicator())
                : _error != null 
                  ? Center(child: Text('Error: $_error'))
                  : ListView.builder(
                      itemCount: _catalog.length,
                      itemBuilder: (context, index) {
                        final item = _catalog[index];
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
                                        'Price: \$${(item['price'] as double).toStringAsFixed(2)}',
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
