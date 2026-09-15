import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- 1. Added the dotenv import
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart'; // The new dashboard wrapper
import 'screens/splash_screen.dart'; // Splash screen
import 'screens/reminder_confirmation_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (notificationResponse.actionId == 'action_done') {
    await _handleDoneAction(notificationResponse.payload);
  }
}

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'action_done') {
    await _handleDoneAction(notificationResponse.payload);
  } else if (notificationResponse.actionId != 'action_dismiss') {
    if (notificationResponse.payload != null) {
      final payload = jsonDecode(notificationResponse.payload!);
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ReminderConfirmationScreen(
            itemTitle: payload['itemTitle'] ?? '',
            category: payload['category'] ?? '',
            subtitle: payload['subtitle'],
          ),
        ),
      );
    }
  }
}

Future<void> _handleDoneAction(String? payloadString) async {
  if (payloadString == null) return;
  try {
    final payload = jsonDecode(payloadString);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': user.uid,
        'title': payload['itemTitle'] ?? '',
        'category': payload['category'] ?? 'EVENT',
        'status': 'Taken',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    debugPrint("Error handling done action: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Database
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Initialize the Notification/Alarm Service
  await NotificationService().init();

  // 3. Unlock the secure vault for the Gemini AI!
  await dotenv.load(fileName: ".env");

  // 4. Run the App
  runApp(const MedicareApp());
}

class MedicareApp extends StatelessWidget {
  const MedicareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Medicarex',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainNavigationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}