import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
  bool _isLoading = false;

  Future<void> _login() async {
    if (_isLoading) return;
    
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!email.endsWith('@xyz.edu.in')) {
      setState(() {
        _errorMessage = 'Only @xyz.edu.in email IDs are allowed.';
        _isLoading = false;
      });
      return;
    }

    final error = await AuthService().login(email: email, password: password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    }
    // Success: Firebase authStateChanges will redirect automatically
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    final error = await AuthService().signInWithGoogle();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      setState(() {
        _errorMessage = error;
      });
    }
    // Success: Firebase authStateChanges will redirect automatically
  }

  Future<void> _signInWithApple() async {
    if (_isLoading) return;
    
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    final error = await AuthService().signInWithApple();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

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
                              onPressed: _isLoading ? null : _login,
                              style: AppTheme.primaryButtonStyle,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          // Divider with "OR"
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppTheme.border,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.textSecondary,
                                    fontWeight: AppTheme.fontWeightMedium,
                                    fontSize: AppTheme.fontSizeLabel,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppTheme.border,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          // Google Sign-In Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Image.network(
                                'https://www.google.com/favicon.ico',
                                height: 20,
                                width: 20,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.g_mobiledata, size: 24),
                              ),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: AppTheme.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppTheme.spacing16,
                                  horizontal: AppTheme.spacing24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: AppTheme.fontWeightSemibold,
                                  fontSize: AppTheme.fontSizeBody,
                                ),
                              ),
                            ),
                          ),
                          // Apple Sign-In Button (iOS/macOS only)
                          if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) ...[
                            const SizedBox(height: AppTheme.spacing12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _signInWithApple,
                                icon: const Icon(Icons.apple, size: 24),
                                label: const Text('Continue with Apple'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textPrimary,
                                  backgroundColor: Colors.black,
                                  side: const BorderSide(color: Colors.black),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacing16,
                                    horizontal: AppTheme.spacing24,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: AppTheme.fontWeightSemibold,
                                    fontSize: AppTheme.fontSizeBody,
                                    color: Colors.white,
                                  ),
                                ).copyWith(
                                  foregroundColor: WidgetStateProperty.all(Colors.white),
                                ),
                              ),
                            ),
                          ],
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
