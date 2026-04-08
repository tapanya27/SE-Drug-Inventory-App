import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class PharmacyInventoryScreen extends StatefulWidget {
  const PharmacyInventoryScreen({super.key});

  @override
  State<PharmacyInventoryScreen> createState() => _PharmacyInventoryScreenState();
}

class _PharmacyInventoryScreenState extends State<PharmacyInventoryScreen> {
  // Dummy local inventory for the Pharmacy Store itself
  final List<Map<String, dynamic>> _inventory = [
    {'id': 'p1', 'name': 'Paracetamol 500mg', 'stock': 250, 'threshold': 100},
    {'id': 'p2', 'name': 'Amoxicillin 250mg', 'stock': 30, 'threshold': 50}, // Low
    {'id': 'p3', 'name': 'Bandages', 'stock': 15, 'threshold': 20}, // Low
    {'id': 'p4', 'name': 'Cough Syrup', 'stock': 0, 'threshold': 10}, // Out of Stock
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Inventory'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Store Stock',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _inventory.length,
                itemBuilder: (context, index) {
                  final item = _inventory[index];
                  final stock = item['stock'] as int;
                  final threshold = item['threshold'] as int;
                  
                  bool isLow = stock <= threshold;
                  bool isOut = stock == 0;

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text('${item['name']}'),
                      subtitle: Text('Threshold: $threshold'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$stock in stock',
                            style: TextStyle(
                              color: isOut ? AppColors.error : (isLow ? Colors.orange : Colors.green),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isLow || isOut)
                            Text(
                              isOut ? 'Depleted!' : 'Warning',
                              style: TextStyle(color: isOut ? AppColors.error : Colors.orange, fontSize: 12),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/place_order'),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Replenish Stock'),
        backgroundColor: AppColors.primaryAccent,
      ),
    );
  }
}
