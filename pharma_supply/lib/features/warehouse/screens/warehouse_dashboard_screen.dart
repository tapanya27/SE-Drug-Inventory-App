import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class WarehouseDashboardScreen extends StatelessWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: AppColors.error),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.go('/login');
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
              onTap: () {},
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
              onTap: () {},
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
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.5,
                    children: const [
                      _StatCard(title: 'Pending Dispatch', value: '25', icon: Icons.pending_actions, color: Colors.orange),
                      _StatCard(title: 'Critical Low Stock', value: '8', icon: Icons.warning_amber_rounded, color: AppColors.error),
                      _StatCard(title: 'Total Deliveries Today', value: '42', icon: Icons.check_circle_outline, color: AppColors.primaryAccent),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Orders Awaiting Dispatch',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white24),
                  itemBuilder: (context, index) {
                    final dummyOrders = [
                      {'id': 'ORD-1089', 'pharmacy': 'City Health Pharmacy', 'items': 'Paracetamol (200), Inhalers (15)', 'urgence': 'High'},
                      {'id': 'ORD-1088', 'pharmacy': 'Westside Drugs', 'items': 'Amoxicillin (100)', 'urgence': 'Medium'},
                      {'id': 'ORD-1087', 'pharmacy': 'Downtown Clinic', 'items': 'Bandages (50), Syringes (500)', 'urgence': 'Low'},
                      {'id': 'ORD-1086', 'pharmacy': 'North Medical Center', 'items': 'Omeprazole (200), Cetirizine (100)', 'urgence': 'Medium'},
                    ];
                    final order = dummyOrders[index];

                    final urgenceColor = order['urgence'] == 'High' 
                        ? AppColors.error 
                        : (order['urgence'] == 'Medium' ? Colors.orange : AppColors.primaryAccent);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text('${order['id']} - ${order['pharmacy']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Items: ${order['items']}'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.flash_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Priority: ${order['urgence']}',
                                  style: TextStyle(color: urgenceColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.primaryAccent,
                          side: const BorderSide(color: AppColors.primaryAccent),
                        ),
                        onPressed: () {
                          // Action to dispatch
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Order ${order['id']} marked as dispatched!')),
                          );
                        },
                        child: const Text('Dispatch'),
                      ),
                    );
                  },
                ),
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
