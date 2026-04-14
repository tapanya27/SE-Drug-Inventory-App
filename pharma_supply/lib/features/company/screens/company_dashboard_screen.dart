import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_widgets.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Supply Chain Center',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            onPressed: _refreshData,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompanyHeader(theme),
            const SizedBox(height: 32),
            
            _buildMarketDemandBanner(theme),
            const SizedBox(height: 24),

            _buildCriticalAlertsSection(theme),
            const SizedBox(height: 48),

            Text(
              'Replenishment Requests',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            
            _buildRequestsList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supply Chain Intelligence',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 28, letterSpacing: -0.5),
        ),
        Text(
          'Real-time analytics and inventory replenishment management',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildMarketDemandBanner(ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: _demandFuture,
      builder: (context, snapshot) {
        final highDemand = snapshot.data ?? [];
        if (highDemand.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryAccent.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_graph_rounded, color: AppColors.primaryAccent, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Market Prediction',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryAccent, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Predictive models suggest an upcoming demand spike for these medications:',
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: highDemand.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    m['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primaryAccent),
                  ),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCriticalAlertsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(
              'Critical Warehouse Deficits',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, color: AppColors.error),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<dynamic>>(
          future: _lowStockFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            }
            
            final criticalItems = snapshot.data ?? [];
            if (criticalItems.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight)),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                    SizedBox(width: 12),
                    Text('Global warehouse stock is within healthy limits', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                  ],
                ),
              );
            }

            return Column(
              children: criticalItems.map((item) => AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                borderRadius: 16,
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, inherit: true)),
                          const SizedBox(height: 4),
                          Text('Location: ${item['owner_name']}', style: const TextStyle(fontSize: 12, inherit: true)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'STK: ${item['stock']}/${item['threshold']}',
                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 11, inherit: true),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestsList(ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: _inventoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(48.0), child: CircularProgressIndicator()));
        }
        
        final requestedItems = (snapshot.data ?? []).where((m) => m['is_requested'] == true).toList();
        
        if (requestedItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                children: [
                  Icon(Icons.task_alt_rounded, size: 48, color: AppColors.borderLight),
                  const SizedBox(height: 16),
                  const Text('No pending replenishment tasks', style: TextStyle(color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          );
        }

        return AppCard(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requestedItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final item = requestedItems[index];
              return AppListTile(
                padding: const EdgeInsets.all(20),
                title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, inherit: true)),
                subtitle: Text('WH: ${item['owner_name'] ?? 'Primary'} • Stock: ${item['stock']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, inherit: true)),
                trailing: AppButton(
                  height: 40,
                  text: 'Audit & Dispatch',
                  onPressed: () => _handleReplenish(item),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleReplenish(dynamic item) async {
    try {
      await ApiService.replenishStock(item['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item['name']} replenished with 500 units.')),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
