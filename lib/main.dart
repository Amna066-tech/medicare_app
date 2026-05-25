import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- 1. Added the dotenv import
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart'; // The new dashboard wrapper
import 'services/notification_service.dart';

Future<void> main() async { // <-- Updated to Future<void>
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Database
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Initialize the Notification/Alarm Service
  await NotificationService().init();

  // 3. Unlock the secure vault for the Gemini AI! <-- 2. Added the vault unlock
  await dotenv.load(fileName: ".env");

  // 4. Run the App
  runApp(const MedicareApp());
}

class MedicareApp extends StatelessWidget {
  const MedicareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medicarex',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // StreamBuilder listens to Firebase Auth
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // THE FIX: If logged in, go to the new Bottom Navigation Bar!
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }

          // If not logged in, go to Login
          return const LoginScreen();
        },
      ),
    );
  }
}