import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_widgets.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> {
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = ApiService.getOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = ApiService.getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pharmacy Hub',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            onPressed: _refreshOrders,
            tooltip: 'Refresh',
          ),
          AppIconButton(
            icon: Icons.logout_rounded,
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
            color: AppColors.error,
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
             return _buildErrorState(snapshot.error.toString());
          }

          final orders = snapshot.data ?? [];
          final pendingCount = orders.where((o) => o['status'] == 'Processing').length;
          final dispatchedCount = orders.where((o) => o['status'] == 'Dispatched').length;

          return RefreshIndicator(
            onRefresh: () async => _refreshOrders(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'General Overview',
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 24, letterSpacing: -0.5),
                          ),
                          Text(
                            'Real-time status of your shipments',
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    AppButton(
                      onPressed: () => context.go('/place_order'),
                      icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                      text: 'New Order',
                      height: 44,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    final statsCards = [
                      _StatCard(
                        title: 'Active Requests', 
                        value: pendingCount.toString(), 
                        icon: Icons.hourglass_empty_rounded, 
                        color: AppColors.warning
                      ),
                      _StatCard(
                        title: 'In Transit', 
                        value: dispatchedCount.toString(), 
                        icon: Icons.local_shipping_outlined, 
                        color: AppColors.info
                      ),
                    ];

                    if (constraints.maxWidth < 600) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: statsCards.map((card) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: card,
                        )).toList(),
                      );
                    }

                    int count = constraints.maxWidth > 700 ? 2 : 1;
                    return GridView.count(
                      crossAxisCount: count,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 3.5,
                      children: statsCards,
                    );
                  },
                ),
                
                const SizedBox(height: 48),

                // Recent Orders Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Orders',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppTextButton(
                      onPressed: () => context.go('/track_deliveries'),
                      text: 'View All',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (orders.isEmpty)
                  _buildEmptyState()
                else
                  AppCard(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orders.length > 5 ? 5 : orders.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _buildOrderTile(context, order);
                      },
                    ),
                  ),
                const SizedBox(height: 48), // Added extra bottom padding
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, dynamic order) {
    final status = order['status'] as String;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'Processing':
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case 'Dispatched':
        statusColor = AppColors.info;
        statusIcon = Icons.local_shipping_outlined;
        break;
      case 'Delivered':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      default:
        statusColor = AppColors.textSecondaryLight;
        statusIcon = Icons.help_outline_rounded;
    }

            return AppListTile(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                title: Text(
                  'Order #${order['id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Total: \$${order['total_amount']} • ${order['items_summary'] ?? 'Unknown items'}\n'
                    'Ordered: ${order['order_date']?.toString().split('T')[0] ?? 'N/A'}'
                    '${order['status'] == 'Delivered' && order['delivery_date'] != null ? '\nDelivered: ${order['delivery_date'].toString().split('T')[0]}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () {
                  // Navigate to details if implemented
                },
              );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.borderLight),
            const SizedBox(height: 16),
            const Text(
              'No orders yet',
              style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final isAuthError = error.contains('401') || error.contains('unauthorized');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              isAuthError ? 'Your session has expired' : 'Something went wrong',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isAuthError ? 'Please sign in again to continue.' : error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: isAuthError 
                ? () async {
                    await ApiService.logout();
                    if (context.mounted) context.go('/login');
                  }
                : _refreshOrders,
              text: isAuthError ? 'Sign In Again' : 'Retry',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primaryLight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.medication_rounded, size: 48, color: AppColors.primaryAccent),
                  const SizedBox(height: 12),
                  Text(
                    'Pharma Supply',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: AppColors.primaryAccent),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
            selected: true,
            selectedTileColor: AppColors.primaryLight.withOpacity(0.5),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_rounded),
            title: const Text('Place Order'),
            onTap: () {
              Navigator.pop(context);
              context.go('/place_order');
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_rounded),
            title: const Text('Track Orders'),
            onTap: () {
              Navigator.pop(context);
              context.go('/track_deliveries');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_rounded),
            title: const Text('Inventory'),
            onTap: () {
              Navigator.pop(context);
              context.go('/pharmacy_inventory');
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 16),
        ],
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
    return AppCard(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500, inherit: true), maxLines: 1),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, inherit: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
