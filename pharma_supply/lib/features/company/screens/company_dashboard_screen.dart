import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class CompanyDashboardScreen extends StatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  Future<List<dynamic>>? _inventoryFuture;
  Future<List<dynamic>>? _demandFuture;
  Future<List<dynamic>>? _lowStockFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _inventoryFuture = ApiService.getInventory();
      _demandFuture = ApiService.getDemandPrediction();
      _lowStockFuture = ApiService.getLowStockAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supply Chain Analytics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Demand Alerts Row
              FutureBuilder<List<dynamic>>(
                future: _demandFuture,
                builder: (context, snapshot) {
                  final highDemandMedicines = snapshot.data ?? [];
                  if (highDemandMedicines.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.trending_up, color: AppColors.primaryAccent),
                            SizedBox(width: 8),
                            Text(
                              'Market Demand Spike Detected',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The following items are trending high. Consider proactive replenishment.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: highDemandMedicines.map((m) => Chip(
                            label: Text(m['name']),
                            backgroundColor: AppColors.cardColor,
                          )).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Critical Stock Alerts section
              Text(
                'Critical Warehouse Stock Alerts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: _lowStockFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                  }
                  
                  final criticalItems = snapshot.data ?? [];
                  if (criticalItems.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('All warehouse stock levels are currently healthy.', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return Column(
                    children: criticalItems.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Warehouse: ${item['owner_name']}'),
                        trailing: Text(
                          'Stock: ${item['stock']}/${item['threshold']}',
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              Text(
                'Pending Replenishment Requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<dynamic>>(
                future: _inventoryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final requestedItems = (snapshot.data ?? []).where((m) => m['is_requested'] == true).toList();
                  
                  if (requestedItems.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('No pending requests found from warehouse.')),
                      ),
                    );
                  }

                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requestedItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = requestedItems[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Warehouse: ${item['owner_name'] ?? 'Global Catalog'}', 
                                style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold)),
                              Text('Current Stock: ${item['stock']} | Threshold: ${item['threshold']}'),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve & Dispatch'),
                            onPressed: () async {
                              try {
                                await ApiService.replenishStock(item['id']);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${item['name']} replenished with 500 units.')),
                                  );
                                  _refreshData();
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
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
