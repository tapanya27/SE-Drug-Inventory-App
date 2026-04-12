import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/stripe_service.dart';

class PaymentSimulationScreen extends StatefulWidget {
  final double amount;
  final List<Map<String, dynamic>> items;
  final int? warehouseId;
  const PaymentSimulationScreen({
    super.key, 
    required this.amount, 
    required this.items,
    this.warehouseId,
  });


  @override
  State<PaymentSimulationScreen> createState() => _PaymentSimulationScreenState();
}

class _PaymentSimulationScreenState extends State<PaymentSimulationScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  String? _errorMessage;
  bool _paymentSuccess = false;

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 0. Validate card fields
      final cardNum = _cardNumberController.text.replaceAll(' ', '');
      final expiry = _expiryController.text.trim();
      final cvc = _cvcController.text.trim();
      final name = _nameController.text.trim();

      if (name.isEmpty) {
        throw Exception('Please enter the cardholder name.');
      }
      if (cardNum.length < 13 || cardNum.length > 19 || !RegExp(r'^\d+$').hasMatch(cardNum)) {
        throw Exception('Please enter a valid card number.');
      }
      if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
        throw Exception('Please enter a valid expiry date (MM/YY).');
      }
      if (cvc.length < 3 || cvc.length > 4 || !RegExp(r'^\d+$').hasMatch(cvc)) {
        throw Exception('Please enter a valid CVC (3-4 digits).');
      }

      // 1. Create a real PaymentIntent on the backend via Stripe API
      final clientSecret = await PaymentService.instance.createPaymentIntent(widget.amount);

      // 2. Confirm the payment
      final confirmed = await PaymentService.instance.confirmPayment(clientSecret);

      if (!confirmed) {
        throw Exception('Payment could not be confirmed');
      }

      // 3. Finalize the order in the database
      await ApiService.placeOrder(widget.items, warehouseId: widget.warehouseId);


      if (mounted) {
        setState(() => _paymentSuccess = true);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Order Placed!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment of \$${widget.amount.toStringAsFixed(2)} was successful and your order has been registered.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/pharmacy_dashboard');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
                child: const Text('Return to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Checkout'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Order Summary Card ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E293B), // Deep Slate
                      const Color(0xFF0F172A), // Deeper Slate
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppColors.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text('Order Summary',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...widget.items.map((item) {
                      final name = item['drug_name'] ?? 'Item';
                      final qty = (item['quantity'] as num?) ?? 0;
                      final price = (item['price'] as num?) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$name x$qty',
                                style: const TextStyle(color: Colors.white70)),
                            Text('\$${(qty * price).toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('\$${widget.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryAccent)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Card Details ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card, color: Color(0xFF1E293B), size: 20),
                        const SizedBox(width: 8),
                        const Text('Card Details',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, color: Colors.green.shade400, size: 12),
                              const SizedBox(width: 4),
                              Text('Secured by Stripe',
                                  style: TextStyle(color: Colors.green.shade400, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Cardholder Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _cardNumberController,
                      label: 'Card Number',
                      icon: Icons.credit_card,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _expiryController,
                            label: 'MM/YY',
                            icon: Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _cvcController,
                            label: 'CVC',
                            icon: Icons.security,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- Test Mode Banner ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade600, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Test mode — Using Stripe test card. No real charges.',
                        style: TextStyle(color: Colors.amber.shade600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- Error Message ---
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // --- Pay Button ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Pay \$${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15),
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        filled: true,
        fillColor: Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF635BFF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
