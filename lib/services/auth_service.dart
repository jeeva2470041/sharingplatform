import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Sign in with Google
  Future<String?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return 'Sign-in cancelled';
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      await _auth.signInWithCredential(credential);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return _getErrorMessage(e.code);
    } catch (e) {
      print('Google Sign-In error: $e');
      return 'Google Sign-In failed: ${e.toString()}';
    }
  }

  /// Generate a random nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA256 hash of input string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple
  Future<String?> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request credential for Apple Sign-In
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create an OAuth credential from the Apple credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Update display name if provided (Apple only sends name on first sign-in)
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((name) => name != null).join(' ');
        
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }

      return null; // Success
    } on SignInWithAppleAuthorizationException catch (e) {
      print('Apple Sign-In Authorization Exception: ${e.code} - ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) {
        return 'Sign-in cancelled';
      }
      return 'Apple Sign-In failed: ${e.message}';
    } on FirebaseAuthException catch (e) {
      print('Apple Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      return _getErrorMessage(e.code);
    } catch (e) {
      print('Apple Sign-In error: $e');
      return 'Apple Sign-In failed: ${e.toString()}';
    }
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
