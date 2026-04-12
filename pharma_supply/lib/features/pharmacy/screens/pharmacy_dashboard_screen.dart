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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimaryLight),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimaryLight),
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'General Overview',
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 24, letterSpacing: -0.5),
                          ),
                          Text(
                            'Real-time status of your shipments',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/place_order'),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('New Order'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int count = constraints.maxWidth > 700 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: count,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: count == 1 ? 4 : 3.5,
                        children: [
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
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 48),

                  // Recent Orders Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Orders',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (orders.isEmpty)
                    _buildEmptyState()
                  else
                    Card(
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
                ],
              ),
            ),
          );
        },
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
            decoration: const BoxDecoration(
              color: AppColors.backgroundLight,
              border: Border(bottom: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'PharmaLink',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard', true, () => Navigator.pop(context)),
          _buildDrawerItem(Icons.add_shopping_cart_rounded, 'Place Order', false, () {
            Navigator.pop(context);
            context.go('/place_order');
          }),
          _buildDrawerItem(Icons.inventory_2_outlined, 'My Inventory', false, () {
            Navigator.pop(context);
            context.go('/pharmacy_inventory');
          }),
          _buildDrawerItem(Icons.local_shipping_outlined, 'Track Deliveries', false, () {
            Navigator.pop(context);
            context.go('/track_deliveries');
          }),
          const Spacer(),
          const Divider(indent: 20, endIndent: 20),
          _buildDrawerItem(
            Icons.verified_user_outlined, 
            ApiService.isVerified ? 'Verified Account' : 'Action Required', 
            false, 
            () {
              Navigator.pop(context);
              context.go('/document_upload');
            },
            color: ApiService.isVerified ? AppColors.success : AppColors.warning,
          ),
          _buildDrawerItem(Icons.logout_rounded, 'Sign Out', false, () async {
            await ApiService.logout();
            if (context.mounted) context.go('/login');
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool selected, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? (selected ? AppColors.primaryAccent : AppColors.textSecondaryLight), size: 22),
      title: Text(
        title, 
        style: TextStyle(
          color: color ?? (selected ? AppColors.primaryAccent : AppColors.textPrimaryLight),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      dense: true,
      selected: selected,
      selectedTileColor: AppColors.primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildOrderTile(BuildContext context, dynamic order) {
    final status = order['status'] ?? 'Processing';
    Color statusColor;
    if (status == 'Processing') statusColor = AppColors.warning;
    else if (status == 'Dispatched') statusColor = AppColors.info;
    else statusColor = AppColors.success;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.medication_outlined, color: AppColors.primaryAccent),
      ),
      title: Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(order['items_summary'] ?? 'Items hidden'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status, 
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
     return const Center(
       child: Padding(
         padding: EdgeInsets.all(48.0),
         child: Column(
           children: [
             Icon(Icons.inbox_rounded, size: 48, color: AppColors.borderLight),
             SizedBox(height: 16),
             Text('No orders found'),
           ],
         ),
       ),
     );
  }

  Widget _buildErrorState(String error) {
    final isAuthError = error.contains('401');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isAuthError ? Icons.lock_outline_rounded : Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(isAuthError ? 'Session Expired' : 'Failed to load dashboard', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isAuthError 
                ? () async {
                    await ApiService.logout();
                    if (context.mounted) context.go('/login');
                  }
                : _refreshOrders,
              child: Text(isAuthError ? 'Sign In Again' : 'Retry'),
            ),
          ],
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

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -1),
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
