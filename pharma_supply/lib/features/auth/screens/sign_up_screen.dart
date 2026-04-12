import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';

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
    final passwordRegex = RegExp(r"^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$");
    setState(() {
      if (value.isEmpty) {
        _passwordError = null;
      } else if (value.length < 8) {
        _passwordError = 'Minimum 8 characters required';
      } else if (!passwordRegex.hasMatch(value)) {
        _passwordError = 'Require Uppercase, Number, and Special Char';
      } else {
        _passwordError = null;
      }
    });
  }

  void _signUp() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    _validateEmail(email);
    _validatePassword(password);

    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.signup(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _selectedRole,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please sign in.')),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create an account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 32,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimaryLight,
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
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildFieldLabel('Full Name / Store Name'),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Central Pharmacy',
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
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
                              });
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            child: _isLoading 
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Create Account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: theme.textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'Sign in',
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimaryLight,
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
