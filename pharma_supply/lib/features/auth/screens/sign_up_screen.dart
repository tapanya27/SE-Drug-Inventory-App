import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Pharmacy Store';
  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  void _validateName(String value) {
    setState(() {
      if (value.isEmpty) {
        _nameError = 'Name is required';
      } else if (value.length < 2) {
        _nameError = 'Name is too short';
      } else {
        _nameError = null;
      }
    });
  }

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

  Future<void> _signUp() async {
    _validateName(_nameController.text);
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_nameError != null || _emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    
    try {
      await ApiService.signup(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _selectedRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/login');
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => context.go('/login'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Create an account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join the Pharma Supply logistics network',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    AppCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFieldLabel('Full Name / Store Name'),
                          TextField(
                            controller: _nameController,
                            onChanged: _validateName,
                            decoration: InputDecoration(
                              hintText: 'e.g. Central Pharmacy',
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                              errorText: _nameError,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          _buildFieldLabel('Email Address'),
                          TextField(
                            controller: _emailController,
                            onChanged: _validateEmail,
                            decoration: InputDecoration(
                              hintText: 'alex@example.com',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                              errorText: _emailError,
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildFieldLabel('Password'),
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
                          const SizedBox(height: 24),

                          _buildFieldLabel('Select Role'),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            items: ['Pharmacy Store', 'Warehouse'].map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                                _validateEmail(_emailController.text);
                              });
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          AppButton(
                            text: 'Create Account',
                            isLoading: _isLoading,
                            onPressed: _signUp,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: theme.textTheme.bodyMedium),
                        AppTextButton(
                          text: 'Sign in',
                          onPressed: () => context.go('/login'),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          inherit: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
