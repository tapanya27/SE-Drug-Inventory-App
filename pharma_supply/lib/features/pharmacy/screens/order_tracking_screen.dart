import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
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

  int _getStepFromStatus(String status) {
    switch (status) {
      case 'Processing':
        return 0;
      case 'Dispatched':
        return 2;
      case 'Delivered':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Track Deliveries',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimaryLight),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
        actions: [
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
          if (orders.isEmpty) {
            return _buildEmptyState();
          }
          
          return RefreshIndicator(
            onRefresh: () async => _refreshOrders(),
            child: ListView.separated(
              padding: const EdgeInsets.all(24.0),
              itemCount: orders.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final order = orders[index];
                final trackingData = {
                  'id': order['id'].toString(),
                  'date': order['order_date']?.toString().split('T')[0] ?? 'N/A',
                  'status': order['status'] ?? 'Processing',
                  'currentStep': _getStepFromStatus(order['status'] ?? 'Processing'),
                  'items': order['items_summary'] ?? 'N/A',
                  'total': (order['total_amount'] as num?)?.toDouble() ?? 0.0,
                  'supplier': order['warehouse_name'] ?? 'Unknown Warehouse',
                };

                return _OrderTrackingCard(
                  order: trackingData,
                  onStatusUpdate: _refreshOrders,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.borderLight),
            const SizedBox(height: 16),
            const Text(
              'No active shipments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
            ),
            const SizedBox(height: 8),
            const Text(
              'Place an order from the replenishment screen to track it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTrackingCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStatusUpdate;

  const _OrderTrackingCard({required this.order, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final status = order['status'];
    Color statusColor = status == 'Delivered' ? AppColors.success : (status == 'Dispatched' ? AppColors.primaryAccent : AppColors.warning);
    IconData statusIcon = status == 'Delivered' ? Icons.check_circle_rounded : (status == 'Dispatched' ? Icons.local_shipping_rounded : Icons.pending_actions_rounded);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          title: Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text('${order['date']} • $supplierName', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          children: [
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('\$${(order['total'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primaryAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(order['items'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
                  
                  const SizedBox(height: 24),
                  _buildTrackingStepper(context, order['currentStep'] as int),
                  const SizedBox(height: 32),
                  
                  if (status == 'Processing')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _handleCancel(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (status == 'Dispatched')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _handleConfirm(context),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
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

  String get supplierName => order['supplier'];

  Future<void> _handleCancel(BuildContext context) async {
    try {
      await ApiService.cancelOrder(int.parse(order['id']));
      onStatusUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleConfirm(BuildContext context) async {
    try {
      await ApiService.updateOrderStatus(int.parse(order['id']), 'Delivered');
      onStatusUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildTrackingStepper(BuildContext context, int currentStep) {
    final steps = ['Pending', 'Dispatched', 'In Transit', 'Delivered'];
    
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentStep;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index == 0 ? Colors.transparent : (isActive ? AppColors.primaryAccent : AppColors.borderLight),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryAccent : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? AppColors.primaryAccent : AppColors.borderLight,
                        width: 2,
                      ),
                    ),
                    child: isActive
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isLast ? Colors.transparent : (index < currentStep ? AppColors.primaryAccent : AppColors.borderLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
