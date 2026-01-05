import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'data/mock_data.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'services/auth_service.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Optional: keep mock items for now
  await MockData.loadItems();
  await MockData.loadWallet();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Sharing',
      theme: AppTheme.lightTheme,

      // 🔥 AUTO LOGIN LOGIC using Firebase Auth
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          // Since authStateChanges now yields immediately, we can check hasData
          if (snapshot.hasData) {
            return const DashboardScreen();
          }

          // No user logged in or still loading - show login
          // connectionState.waiting will be very brief now
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
