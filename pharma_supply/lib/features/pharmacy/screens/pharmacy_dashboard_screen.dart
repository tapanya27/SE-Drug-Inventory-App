import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  Future<List<dynamic>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = ApiService.getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
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
              decoration: BoxDecoration(color: AppColors.cardColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_hospital_rounded, color: AppColors.primaryAccent, size: 48),
                  SizedBox(height: 16),
                  Text('Central Pharmacy', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text('Place Order'),
              onTap: () {
                Navigator.pop(context);
                context.go('/place_order');
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
            const Divider(color: Colors.white12),
            ListTile(
              leading: Icon(Icons.verified_user,
                  color: ApiService.isVerified ? Colors.green : Colors.orange),
              title: const Text('Document Verification'),
              subtitle: Text(
                ApiService.isVerified ? 'Verified' : 'Action Required',
                style: TextStyle(
                  color: ApiService.isVerified ? Colors.green : Colors.orange,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.go('/document_upload');
              },
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.hasError) {
            final isAuthError = snapshot.error.toString().contains('401');
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isAuthError ? Icons.lock_outline : Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(isAuthError ? 'Session Expired (401)' : 'Error: ${snapshot.error}', textAlign: TextAlign.center),
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
              ),
            );
          }

          final orders = snapshot.data ?? [];
          final pendingCount = orders.where((o) => o['status'] == 'Processing').length;
          final dispatchedCount = orders.where((o) => o['status'] == 'Dispatched').length;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int count = constraints.maxWidth > 600 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: count,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 3,
                        children: [
                          _StatCard(title: 'Pending Orders', value: pendingCount.toString(), icon: Icons.pending_actions, color: Colors.orange),
                          _StatCard(title: 'Dispatched', value: dispatchedCount.toString(), icon: Icons.local_shipping, color: AppColors.primaryAccent),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text('Recent Orders', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (orders.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No orders found.')))
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orders.length > 5 ? 5 : orders.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white24),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final status = order['status'] ?? 'Processing';
                          final statusColor = status == 'Processing' ? Colors.orange : (status == 'Dispatched' ? AppColors.primaryAccent : Colors.grey);

                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: AppColors.primaryAccent, child: Icon(Icons.medication_liquid, color: Colors.white)),
                            title: Text('Order #${order['id']}'),
                            subtitle: Text(order['items_summary'] ?? 'No items'),
                            trailing: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/place_order'),
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

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
