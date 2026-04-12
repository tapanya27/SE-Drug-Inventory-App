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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'Warehouse Hub',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimaryLight),
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimaryLight),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
          ],
        ),
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
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'pending_dispatch': 0,
          'low_stock': 0,
          'delivered_today': 0,
        };
        
        return LayoutBuilder(
          builder: (context, constraints) {
            int count = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
            return GridView.count(
              crossAxisCount: count,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: count == 1 ? 4 : 2.8,
              children: [
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
                  value: stats['delivered_today'].toString(), 
                  icon: Icons.task_alt_rounded, 
                  color: AppColors.success
                ),
              ],
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

        return Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderRow(context, order);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderRow(BuildContext context, dynamic order) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryAccent),
      ),
      title: Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(order['items_summary'] ?? 'N/A', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(100, 40),
        ),
        onPressed: () async {
          try {
            final warnings = await ApiService.updateOrderStatus(order['id'], 'Dispatched');
            if (context.mounted) {
              if (warnings.isNotEmpty) _showLowStockWarning(context, warnings);
              _refreshOrders();
            }
          } catch (e) {
            if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
        child: const Text('Dispatch', style: TextStyle(fontSize: 13)),
      ),
    );
  }

  void _showLowStockWarning(BuildContext context, List<dynamic> warnings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 12),
            Text('Stock Depletion'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings.map((w) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('• $w', style: const TextStyle(fontSize: 14)),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Acknowledged'),
          ),
        ],
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primaryAccent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Text('Logistics Hub', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard_outlined, 'Dashboard', true, () => Navigator.pop(context)),
          _buildDrawerItem(Icons.inventory_2_outlined, 'Manage Inventory', false, () {
             Navigator.pop(context);
             context.go('/warehouse_inventory');
          }),
          const Spacer(),
          _buildDrawerItem(Icons.logout_rounded, 'Sign Out', false, () async {
            await ApiService.logout();
            context.go('/login');
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool selected, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primaryAccent : AppColors.textSecondaryLight, size: 22),
      title: Text(title, style: TextStyle(color: selected ? AppColors.primaryAccent : AppColors.textPrimaryLight, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      onTap: onTap,
      dense: true,
      selected: selected,
      selectedTileColor: AppColors.primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500), maxLines: 1),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
}
