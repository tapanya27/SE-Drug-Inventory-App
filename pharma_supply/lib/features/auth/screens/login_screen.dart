import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Email is required';
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        _emailError = 'Enter a valid email address';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
      } else if (value.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });
  }

  Future<void> _login() async {
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        final role = ApiService.userRole;
        final isVerified = ApiService.isVerified;

        if (role == 'Warehouse') {
          context.go('/warehouse_dashboard');
        } else if (role == 'Company') {
          context.go('/company_dashboard');
        } else if (role == 'Admin') {
          context.go('/admin_dashboard');
        } else {
          // Pharmacy
          if (isVerified) {
            context.go('/pharmacy_dashboard');
          } else {
            context.go('/document_upload');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    
                    // Logo/Brand Section
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.medication_liquid_rounded,
                          size: 40,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log in to your Pharma Supply account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Login Form Card (Custom Container)
                    AppCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              inherit: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            onChanged: _validateEmail,
                            decoration: InputDecoration(
                              hintText: 'alex@company.com',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                              errorText: _emailError,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Password',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              inherit: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            onChanged: _validatePassword,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              errorText: _passwordError,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Custom Auth Button (No ElevatedButton)
                          AppButton(
                            text: 'Sign In',
                            isLoading: _isLoading,
                            onPressed: _login,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Footer Link (Custom Text Button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        AppTextButton(
                          text: 'Sign up',
                          onPressed: () => context.go('/signup'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
