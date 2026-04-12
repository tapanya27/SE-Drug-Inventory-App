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
        return 1;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Deliveries'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/pharmacy_dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
            ));
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No actual orders found. Place an order to see it here!'));
          }
          return RefreshIndicator(
            onRefresh: () async => _refreshOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final trackingData = {
                  'id': order['id'].toString(),
                  'date': order['order_date']?.toString().split('T')[0] ?? 'N/A',
                  'status': order['status'] ?? 'Processing',
                  'currentStep': _getStepFromStatus(order['status'] ?? 'Processing'),
                  'items': order['items_summary'] ?? 'N/A',
                  'total': (order['total_amount'] as num?)?.toDouble() ?? 0.0,
                  'supplier': order['warehouse_name'] ?? 'Unknown',
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
}

class _OrderTrackingCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onStatusUpdate;

  const _OrderTrackingCard({required this.order, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final statusColor = order['status'] == 'Delivered'
        ? Colors.grey
        : (order['status'] == 'Dispatched' ? AppColors.primaryAccent : Colors.orange);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: statusColor,
          iconColor: statusColor,
          title: Text(
            'Order #${order['id']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${order['date']} • \$${(order['total'] as double).toStringAsFixed(2)}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(
              order['status'],
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          children: [
            const Divider(color: Colors.white24),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Supplier: ${order['supplier']}', 
                      style: const TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Items: ${order['items']}', style: Theme.of(context).textTheme.bodyMedium),

                  const SizedBox(height: 16),
                  _buildTrackingStepper(context, order['currentStep'] as int),
                  const SizedBox(height: 24),
                  if (order['status'] == 'Processing')
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () async {
                          try {
                            await ApiService.cancelOrder(int.parse(order['id']));
                            onStatusUpdate();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Order'),
                      ),
                    ),
                  if (order['status'] == 'Dispatched')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                        onPressed: () async {
                          try {
                            await ApiService.updateOrderStatus(
                                int.parse(order['id']), 'Delivered');
                            onStatusUpdate();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirm Delivery'),
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

  Widget _buildTrackingStepper(BuildContext context, int currentStep) {
    final steps = ['Order Placed', 'Processing', 'Dispatched', 'Delivered'];

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
                      color: index == 0 ? Colors.transparent : (isActive ? AppColors.primaryAccent : Colors.white24),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryAccent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? AppColors.primaryAccent : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: isActive
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isLast ? Colors.transparent : (index < currentStep ? AppColors.primaryAccent : Colors.white24),
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
                  color: isActive ? Colors.white : Colors.grey,
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
