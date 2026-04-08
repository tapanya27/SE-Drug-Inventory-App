import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class WarehouseInventoryScreen extends StatefulWidget {
  const WarehouseInventoryScreen({super.key});

  @override
  State<WarehouseInventoryScreen> createState() => _WarehouseInventoryScreenState();
}

class _WarehouseInventoryScreenState extends State<WarehouseInventoryScreen> {
  // Dummy inventory for Warehouse
  final List<Map<String, dynamic>> _inventory = [
    {'id': 'm1', 'name': 'Paracetamol 500mg', 'stock': 1500, 'status': 'Healthy', 'threshold': 500},
    {'id': 'm2', 'name': 'Amoxicillin 250mg', 'stock': 800, 'status': 'Healthy', 'threshold': 300},
    {'id': 'm3', 'name': 'Ibuprofen 400mg', 'stock': 150, 'status': 'Critical', 'threshold': 500},
    {'id': 'm4', 'name': 'Cetirizine 10mg', 'stock': 200, 'status': 'Low', 'threshold': 250},
    {'id': 'm5', 'name': 'Omeprazole 20mg', 'stock': 0, 'status': 'Out of Stock', 'threshold': 100},
  ];

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
            icon: const Icon(Icons.add_box),
            onPressed: () {
              // Add new medication to database simulation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add New Product dialog would appear here.')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search / Filter simulation
            TextField(
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
              child: ListView.builder(
                itemCount: _inventory.length,
                itemBuilder: (context, index) {
                  final item = _inventory[index];
                  final status = item['status'] as String;
                  
                  Color statusColor;
                  if (status == 'Healthy') {
                    statusColor = Colors.green;
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
                                Text('Threshold: ${item['threshold']} | Current Stock: ${item['stock']}',
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
                              if (status != 'Healthy')
                                InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Replenishment request sent to Pharma Company for ${item['name']}.')),
                                    );
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
