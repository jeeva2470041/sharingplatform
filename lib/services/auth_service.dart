import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get currently logged-in user
  User? get currentUser => _auth.currentUser;

  /// Listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Register new user
  Future<String?> register({
    required String email,
    required String password,
  }) async {
    // Client-side validation
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      return _getErrorMessage(e.code);
    } catch (e) {
      print('Register error type: ${e.runtimeType}');
      print('Register error: $e');
      
      // Check if it's a configuration error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('configuration') || errorStr.contains('not found')) {
        return 'Firebase Email/Password sign-in is not enabled. Please enable it in Firebase Console.';
      }
      
      return 'Registration failed: ${e.toString()}';
    }
  }

  /// Login existing user
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    // Client-side validation
    if (email.isEmpty || !email.contains('@')) {
      return 'Please enter a valid email address';
    }
    if (password.isEmpty) {
      return 'Please enter your password';
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      return _getErrorMessage(e.code);
    } catch (e) {
      print('Login error type: ${e.runtimeType}');
      print('Login error: $e');
      return 'Login failed: ${e.toString()}';
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Initialize auth (for compatibility)
  static Future<void> initializeAuth() async {
    // Firebase handles this automatically
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Please enable it in Firebase Console.';
      default:
        return 'Authentication error: $code';
    }
  }
}
