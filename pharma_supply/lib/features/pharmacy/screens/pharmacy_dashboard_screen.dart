import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class PharmacyDashboardScreen extends StatelessWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
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
                  Icon(Icons.local_hospital_rounded,
                      color: AppColors.primaryAccent, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Central Pharmacy',
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
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text('Place Order'),
              onTap: () {
                Navigator.pop(context); // close drawer
                context.go('/place_order');
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Inventory'),
              onTap: () {
                Navigator.pop(context);
                context.go('/pharmacy_inventory');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Track Deliveries'),
              onTap: () {
                Navigator.pop(context);
                context.go('/track_deliveries');
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
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.5,
                    children: const [
                      _StatCard(title: 'Pending Orders', value: '12', icon: Icons.pending_actions, color: Colors.orange),
                      _StatCard(title: 'Low Stock Alerts', value: '4', icon: Icons.warning_amber_rounded, color: AppColors.error),
                      _StatCard(title: 'Dispatched', value: '3', icon: Icons.local_shipping, color: AppColors.primaryAccent),
                      _StatCard(title: 'Total Products', value: '850', icon: Icons.medication, color: Colors.blueAccent),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Recent Orders',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white24),
                  itemBuilder: (context, index) {
                    final dummyOrders = [
                      {'id': 'ORD-1052', 'items': 'Amoxicillin (50), Inhalers (10)', 'status': 'Dispatched'},
                      {'id': 'ORD-1051', 'items': 'Paracetamol (100), Bandages (20)', 'status': 'Delivered'},
                      {'id': 'ORD-1050', 'items': 'Omeprazole (30)', 'status': 'Processing'},
                    ];
                    final order = dummyOrders[index];

                    final statusColor = order['status'] == 'Processing' 
                        ? Colors.orange 
                        : (order['status'] == 'Dispatched' ? AppColors.primaryAccent : Colors.grey);

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryAccent,
                        child: Icon(Icons.medication_liquid, color: Colors.white),
                      ),
                      title: Text('Order #${order['id']}'),
                      subtitle: Text(order['items']!),
                      trailing: Text(
                        order['status']!,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.go('/place_order');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
        backgroundColor: AppColors.primaryAccent,
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
