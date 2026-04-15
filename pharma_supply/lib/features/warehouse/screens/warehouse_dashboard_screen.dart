import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_widgets.dart';

class WarehouseDashboardScreen extends StatefulWidget {
  const WarehouseDashboardScreen({super.key});

  @override
  State<WarehouseDashboardScreen> createState() => _WarehouseDashboardScreenState();
}

class _WarehouseDashboardScreenState extends State<WarehouseDashboardScreen> {
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
          'Warehouse Hub',
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
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 32),
          
          _buildDemandBanner(theme),
          const SizedBox(height: 16),

          _buildStatsGrid(theme),
          const SizedBox(height: 48),

          Text(
            'Awaiting Dispatch',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 16),
          
          _buildOrdersList(theme),
          const SizedBox(height: 48),
          
          Text(
            'Delivered Orders',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 16),
          _buildDeliveredOrdersList(theme),
          
          const SizedBox(height: 48), // Added extra bottom padding
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logistics Overview',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 28, letterSpacing: -0.5),
        ),
        Text(
          'Monitor stock levels and manage outbound shipments',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildDemandBanner(ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getDemandPrediction(),
      builder: (context, snapshot) {
        final highDemand = snapshot.data ?? [];
        if (highDemand.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up_rounded, color: AppColors.warning, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Market Demand Surge',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'AI predicts high demand for the following items. Prioritize replenishment.',
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: highDemand.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Text(
                    m['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.warning),
                  ),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService.getWarehouseStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()));
        }
        
        final stats = snapshot.data ?? {
          'pending_dispatch': 0,
          'low_stock': 0,
          'delivered_today': 0,
          'items_received_today': 0,
          'total_delivered': 0
        };
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final statsCards = [
              _StatCard(
                title: 'Pending Dispatch', 
                value: stats['pending_dispatch'].toString(), 
                icon: Icons.hourglass_top_rounded, 
                color: AppColors.warning
              ),
              _StatCard(
                title: 'Low Stock Alerts', 
                value: stats['low_stock'].toString(), 
                icon: Icons.warning_amber_rounded, 
                color: AppColors.error
              ),
              _StatCard(
                title: 'Delivered Today', 
                value: '${stats['delivered_today']} (${stats['items_received_today']} items)', 
                icon: Icons.task_alt_rounded, 
                color: AppColors.success
              ),
              _StatCard(
                title: 'Total Delivered', 
                value: '${stats['total_delivered']}', 
                icon: Icons.inventory_rounded, 
                color: AppColors.primaryAccent
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

            int count = constraints.maxWidth > 800 ? 4 : 2;
            if (constraints.maxWidth > 600 && constraints.maxWidth <= 800) count = 2;
            
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.8,
              children: statsCards,
            );
          },
        );
      },
    );
  }

  Widget _buildOrdersList(ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()));
        }
        
        final orders = (snapshot.data ?? []).where((o) => o['status'] == 'Processing').toList();
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome_motion_rounded, size: 48, color: AppColors.borderLight),
                  const SizedBox(height: 16),
                  const Text('All orders dispatched', style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          );
        }

        return AppCard(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final order = orders[index];
              return AppListTile(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                title: Text(
                  'Order #${order['id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${order['items_summary'] ?? 'Unknown items'} • Finalizing package'),
                trailing: AppTextButton(
                  text: 'Dispatch',
                  onPressed: () => _updateStatus(order['id'], 'Dispatched'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDeliveredOrdersList(ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()));
        }
        
        final orders = (snapshot.data ?? []).where((o) => o['status'] == 'Delivered').toList();
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.borderLight),
                  const SizedBox(height: 16),
                  const Text('No delivered orders yet', style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          );
        }

        return AppCard(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final order = orders[index];
              return AppListTile(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                title: Text(
                  'Order #${order['id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${order['items_summary'] ?? 'Unknown items'}\nFinalized on: ${order['order_date']?.toString().split('T')[0] ?? 'Unknown'}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Delivered',
                    style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(int orderId, String status) async {
    try {
      await ApiService.updateOrderStatus(orderId, status);
      _refreshOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
                  const Icon(Icons.warehouse_rounded, size: 48, color: AppColors.primaryAccent),
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
            leading: const Icon(Icons.inventory_2_rounded),
            title: const Text('Inventory'),
            onTap: () {
              Navigator.pop(context);
              context.go('/warehouse_inventory');
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
