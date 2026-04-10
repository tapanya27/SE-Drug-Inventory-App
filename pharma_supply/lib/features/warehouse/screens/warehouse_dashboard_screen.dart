import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class WarehouseDashboardScreen extends StatefulWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  State<WarehouseDashboardScreen> createState() => _WarehouseDashboardScreenState();
}

class _WarehouseDashboardScreenState extends State<WarehouseDashboardScreen> {
  Future<List<dynamic>>? _ordersFuture;
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = ApiService.getOrders();
      _statsFuture = ApiService.getWarehouseStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active, color: AppColors.error),
            onPressed: () {},
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
      drawer: Drawer(
        backgroundColor: AppColors.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.cardColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warehouse_rounded,
                      color: AppColors.primaryAccent, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Central Warehouse',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                _refreshOrders();
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Manage Inventory'),
              onTap: () {
                Navigator.pop(context);
                context.go('/warehouse_inventory');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Dispatch Orders'),
              onTap: () {
                Navigator.pop(context);
                _refreshOrders();
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<dynamic>>(
                future: ApiService.getDemandPrediction(),
                builder: (context, snapshot) {
                  final highDemand = snapshot.data ?? [];
                  if (highDemand.isEmpty) return const SizedBox.shrink();
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.trending_up, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'High Demand Predicted',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The following medicines are trending. Ensure stock is sufficient.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: highDemand.map((m) => Chip(
                            label: Text(m['name']),
                            backgroundColor: AppColors.cardColor,
                          )).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {
                    'pending_dispatch': 0,
                    'low_stock': 0,
                    'delivered_today': 0,
                  };
                  
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 2.5,
                        children: [
                          _StatCard(
                            title: 'Pending Dispatch', 
                            value: stats['pending_dispatch'].toString(), 
                            icon: Icons.pending_actions, 
                            color: Colors.orange
                          ),
                          _StatCard(
                            title: 'Critical Low Stock', 
                            value: stats['low_stock'].toString(), 
                            icon: Icons.warning_amber_rounded, 
                            color: AppColors.error
                          ),
                          _StatCard(
                            title: 'Total Deliveries Today', 
                            value: stats['delivered_today'].toString(), 
                            icon: Icons.check_circle_outline, 
                            color: AppColors.primaryAccent
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Orders Awaiting Dispatch',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<dynamic>>(
                future: _ordersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    final isAuthError = snapshot.error.toString().contains('401');
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              isAuthError ? Icons.lock_outline : Icons.error_outline,
                              color: AppColors.error,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isAuthError 
                                ? 'Session Expired (401)' 
                                : 'Error: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isAuthError 
                                ? () async {
                                    await ApiService.logout();
                                    if (context.mounted) context.go('/login');
                                  }
                                : _refreshOrders,
                              child: Text(isAuthError ? 'Go to Login' : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  final orders = (snapshot.data ?? []).where((o) => o['status'] == 'Processing').toList();
                  if (orders.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No orders awaiting dispatch.')));
                  }

                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orders.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white24),
                      itemBuilder: (context, index) {
                        final order = orders[index];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text('Order #${order['id']}'),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Items: ${order['items_summary'] ?? 'N/A'}'),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppColors.primaryAccent,
                              side: const BorderSide(color: AppColors.primaryAccent),
                            ),
                            onPressed: () async {
                              try {
                                final warnings = await ApiService.updateOrderStatus(order['id'], 'Dispatched');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Order #${order['id']} dispatched!')),
                                  );
                                  
                                  if (warnings.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          children: const [
                                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                            SizedBox(width: 8),
                                            Text('Low Stock Alert'),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: warnings.map((w) => Text('• $w')).toList(),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  
                                  _refreshOrders();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: ${e.toString()}')),
                                  );
                                }
                              }
                            },
                            child: const Text('Dispatch'),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
