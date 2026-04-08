import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  // Dummy order data
  final List<Map<String, dynamic>> _orders = [
    {
      'id': 'ORD-1052',
      'date': 'Today, 10:30 AM',
      'status': 'Dispatched',
      'currentStep': 2,
      'items': 'Amoxicillin, Inhalers',
      'total': 134.50,
    },
    {
      'id': 'ORD-1051',
      'date': 'Yesterday, 02:15 PM',
      'status': 'Delivered',
      'currentStep': 3,
      'items': 'Paracetamol, Bandages',
      'total': 45.00,
    },
    {
      'id': 'ORD-1050',
      'date': 'Oct 24, 09:00 AM',
      'status': 'Processing',
      'currentStep': 1,
      'items': 'Omeprazole',
      'total': 300.00,
    },
  ];

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
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderTrackingCard(order: order);
        },
      ),
    );
  }
}

class _OrderTrackingCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderTrackingCard({required this.order});

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
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
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
                  Text('Items: ${order['items']}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  _buildTrackingStepper(context, order['currentStep'] as int),
                  const SizedBox(height: 16),
                  if (order['status'] == 'Dispatched')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                        ),
                        onPressed: () {
                          // Simulate confirming delivery
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Delivery confirmed!')),
                          );
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
    final steps = [
      'Order Placed',
      'Stock Checked',
      'Dispatched',
      'Delivered',
    ];

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
