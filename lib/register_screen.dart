import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Password rule states
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;
  bool _hasValidLength = false;

  void _updatePasswordValidation(String password) {
    setState(() {
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'\d'));
      _hasSpecialChar = password.contains(RegExp(r'[@$!%*?&]'));
      _hasValidLength = password.length >= 6;
    });
  }

  bool get _isPasswordValid =>
      _hasUppercase &&
      _hasLowercase &&
      _hasDigit &&
      _hasSpecialChar &&
      _hasValidLength;

  bool get _isFormValid =>
      _formKey.currentState?.validate() == true &&
      _isPasswordValid &&
      _passwordController.text == _confirmPasswordController.text;

  Future<void> _register() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    final error = await AuthService().register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error == null) {
      // Success - Firebase authStateChanges() will auto-redirect
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.danger),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cardBackground,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryPressed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24, vertical: AppTheme.spacing16),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 32,
                      fontWeight: AppTheme.fontWeightBold,
                      color: AppTheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  const Text(
                    'Join the community and start sharing!',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing32),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your email';
                      if (!v.endsWith('@xyz.edu.in')) {
                        return 'Only @xyz.edu.in email IDs are allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onVisibilityChanged: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    onChanged: _updatePasswordValidation,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password required';
                      if (!_isPasswordValid)
                        return 'Password does not meet requirements';
                      return null;
                    },
                  ),

                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPasswordRules(),
                  ],

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isVisible: _isConfirmPasswordVisible,
                    onVisibilityChanged: () => setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    ),
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isFormValid && !_isLoading ? _register : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: Colors.teal.shade100,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityChanged,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: onVisibilityChanged,
              )
            : null,
        filled: true,
        fillColor: Colors.teal.shade50.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildPasswordRules() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _rule('Uppercase letter', _hasUppercase),
          _rule('Lowercase letter', _hasLowercase),
          _rule('Number', _hasDigit),
          _rule('Special character (@\$!%*?&)', _hasSpecialChar),
          _rule('6+ characters', _hasValidLength),
        ],
      ),
    );
  }

  Widget _rule(String text, bool valid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle : Icons.circle_outlined,
            color: valid ? Colors.teal : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: valid ? Colors.black87 : Colors.grey,
              decoration: valid ? null : null,
            ),
          ),
        ],
      ),
    );
  }
}
