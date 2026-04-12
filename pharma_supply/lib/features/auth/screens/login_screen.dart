import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import 'package:jose/jose.dart';

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
        _emailError = null;
      } else if (!value.contains('@') || !value.contains('.')) {
        _emailError = 'Invalid email format (missing @ or .)';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = null;
      } else if (value.length < 8) {
        _passwordError = 'Password must be at least 8 characters';
      } else {
        _passwordError = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  void _checkExistingToken() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ApiService.token != null) {
        final role = ApiService.userRole;
        final isVerified = ApiService.isVerified;

        if (role == 'Warehouse') {
          context.go('/warehouse_dashboard');
        } else if (role == 'Company') {
          context.go('/company_dashboard');
        } else if (role == 'Admin') {
          context.go('/admin_dashboard');
        } else if (role == 'PHARMACY' || role == 'Pharmacy Store') {
          if (isVerified) {
            context.go('/pharmacy_dashboard');
          } else {
            context.go('/document_upload');
          }
        } else {
          context.go('/pharmacy_dashboard');
        }
      }
    });
  }


  void _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    _validateEmail(email);
    _validatePassword(password);

    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    try {
      final userData = await ApiService.login(email, password);
      
      if (!mounted) return;

      // Navigate based on role and verification status
      final role = userData['role'];
      final bool isVerified = userData['is_verified'] ?? false;

      if (role == 'Warehouse') {
        context.go('/warehouse_dashboard');
      } else if (role == 'Company') {
        context.go('/company_dashboard');
      } else if (role == 'Admin') {
        context.go('/admin_dashboard');
      } else if (role == 'PHARMACY' || role == 'Pharmacy Store') {
        if (isVerified) {
          context.go('/pharmacy_dashboard');
        } else {
          context.go('/document_upload');
        }
      } else {
        // Fallback for any other roles
        context.go('/pharmacy_dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                      color: AppColors.textPrimaryLight,
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

                  // Login Form Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimaryLight,
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
                              color: AppColors.textPrimaryLight,
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
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading 
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, 
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ) 
                              : const Text('Sign In'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Footer Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
