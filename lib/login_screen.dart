import 'dart:ui';
import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'services/auth_service.dart';
import 'app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    setState(() {
      _errorMessage = '';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!email.endsWith('@xyz.edu.in')) {
      setState(() {
        _errorMessage = 'Only @xyz.edu.in email IDs are allowed.';
      });
      return;
    }

    final error = await AuthService().login(email: email, password: password);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    }
    // Success: Firebase authStateChanges will redirect automatically
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.primaryPressed],
                ),
              ),
            ),
          ),
          // Dark Overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
          // Login Card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 600 ? size.width * 0.25 : AppTheme.spacing24,
                vertical: AppTheme.spacing24,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      border: Border.all(color: AppTheme.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school, size: 72, color: AppTheme.primary),
                          const SizedBox(height: AppTheme.spacing24),
                          const Text(
                            'Campus Share',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 32,
                              fontWeight: AppTheme.fontWeightBold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          const Text(
                            'Secure campus-only access',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.fontSizeBody,
                              color: AppTheme.textSecondary,
                              fontWeight: AppTheme.fontWeightMedium,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing32),
                          TextField(
                            controller: _emailController,
                            decoration: AppTheme.inputDecoration(
                              label: 'College Email',
                              prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: AppTheme.inputDecoration(
                              label: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: AppTheme.primaryButtonStyle,
                              child: const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Register",
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: AppTheme.fontWeightSemibold,
                                fontSize: AppTheme.fontSizeLabel,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          if (_errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: AppTheme.spacing16),
                              child: Container(
                                padding: const EdgeInsets.all(AppTheme.spacing12),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                                  border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.danger,
                                    fontWeight: AppTheme.fontWeightSemibold,
                                    fontSize: AppTheme.fontSizeLabel,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
