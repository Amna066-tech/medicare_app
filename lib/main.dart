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
import 'services/database_service.dart';
import 'models/medication_model.dart';
import 'screens/chat_screen.dart';
import 'models/user_model.dart';
import 'screens/caregiver_dashboard_screen.dart';
import 'screens/doctor_dashboard_screen.dart';
import 'screens/pharmacy_dashboard_screen.dart';
import 'screens/doctor_verification_screen.dart';
import 'screens/nurse_verification_screen.dart';
import 'screens/pharmacist_verification_screen.dart';
import 'screens/rejected_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (notificationResponse.actionId == 'action_done') {
    await _handleDoneAction(notificationResponse.payload);
  } else if (notificationResponse.actionId == 'action_dismiss') {
    await _handleDismissAction(notificationResponse.payload);
  }
}

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'action_done') {
    await _handleDoneAction(notificationResponse.payload);
  } else if (notificationResponse.actionId == 'action_dismiss') {
    await _handleDismissAction(notificationResponse.payload);
  } else {
    if (notificationResponse.payload != null) {
      final payload = jsonDecode(notificationResponse.payload!);
      
      if (payload['type'] == 'chat') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: payload['chatId'] ?? '',
              peerName: payload['peerName'] ?? 'Chat',
            ),
          ),
        );
      } else if (payload['type'] == 'alert') {
        final patientId = payload['patientId'];
        if (patientId != null && patientId.isNotEmpty) {
           navigatorKey.currentState?.push(
             MaterialPageRoute(
               builder: (context) => MainNavigationScreen(viewingPatientId: patientId),
             ),
           );
        }
      } else {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ReminderConfirmationScreen(
              itemTitle: payload['itemTitle'] ?? '',
              category: payload['category'] ?? '',
              subtitle: payload['subtitle'],
              medicationId: payload['medicationId'],
            ),
          ),
        );
      }
    }
  }
}

Future<void> _handleDoneAction(String? payloadString) async {
  if (payloadString == null) return;
  try {
    final payload = jsonDecode(payloadString);
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        user = await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 3));
      } catch (_) {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (user != null) {
      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': user.uid,
        'title': payload['itemTitle'] ?? '',
        'category': payload['category'] ?? 'EVENT',
        'status': 'Taken',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Handle atomic stock decrementing for Medications
      if (payload['category'] == 'Medication' && payload['medicationId'] != null) {
        String medId = payload['medicationId'];
        await DatabaseService().processMedicationIntake(medId);
      }
    }
  } catch (e) {
    debugPrint("Error handling done action: $e");
  }
}

Future<void> _handleDismissAction(String? payloadString) async {
  if (payloadString == null) return;
  try {
    final payload = jsonDecode(payloadString);
    
    // In a background isolate, currentUser might initially be null. Wait for it.
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Wait up to 3 seconds for auth state to restore
      try {
        user = await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 3));
      } catch (_) {
        user = FirebaseAuth.instance.currentUser;
      }
    }

    if (user != null) {
      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': user.uid,
        'title': payload['itemTitle'] ?? '',
        'category': payload['category'] ?? 'EVENT',
        'status': 'Missed (by Patient)',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 1. Get Patient Name
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final patientName = userDoc.data()?['name'] ?? 'The patient';

      // 2. Find their Caregiver(s)
      final caregiverReqs = await FirebaseFirestore.instance
          .collection('caregiver_requests')
          .where('patientId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (caregiverReqs.docs.isNotEmpty) {
        bool alertedAny = false;
        final category = payload['category'] ?? 'EVENT';
        final itemTitle = payload['itemTitle'] ?? '';

        for (var doc in caregiverReqs.docs) {
          final caregiverId = doc.data()['caregiverId'];
          if (caregiverId == null || caregiverId.toString().isEmpty) continue;
          
          alertedAny = true;
          // 3. Write to dismiss_alerts
          await FirebaseFirestore.instance.collection('dismiss_alerts').add({
            'caregiverId': caregiverId,
            'patientId': user.uid,
            'patientName': patientName,
            'itemTitle': itemTitle,
            'category': category.toUpperCase(),
            'readBy': [], // Track who has seen it
            'timestamp': FieldValue.serverTimestamp(),
          });
          debugPrint("Alert written to dismiss_alerts for caregiver: $caregiverId");
        }
        
        if (!alertedAny) {
          debugPrint("No valid caregiverId found in accepted requests for patient: ${user.uid}");
        }
      } else {
        debugPrint("No accepted caregiver found for patient: ${user.uid}");
      }
    } else {
      debugPrint("Dismiss Action Failed: Could not resolve currentUser in background isolate.");
    }
  } catch (e) {
    debugPrint("Error handling dismiss action: $e");
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

        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }

              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              UserModel userModel = UserModel.fromMap(userData, snapshot.data!.uid);
              String role = userModel.role;
              String status = userModel.verificationStatus;
              String? caregiverType = userModel.caregiverType;
              
              if (role == 'Patient') {
                return const MainNavigationScreen();
              } else if (role == 'Caregiver' && caregiverType == 'Friend/Relative') {
                return const CaregiverDashboardScreen();
              } else {
                if (status == 'APPROVED') {
                  if (role == 'Doctor') return const DoctorDashboardScreen();
                  if (role == 'Caregiver' && caregiverType == 'Nurse') return const CaregiverDashboardScreen();
                  if (role == 'Pharmacist') return const PharmacyDashboardScreen();
                  return const MainNavigationScreen();
                } else if (status == 'REJECTED') {
                  return const RejectedScreen();
                } else {
                  if (role == 'Doctor') return DoctorVerificationScreen(user: userModel);
                  if (role == 'Caregiver' && caregiverType == 'Nurse') return NurseVerificationScreen(user: userModel);
                  if (role == 'Pharmacist') return PharmacistVerificationScreen(user: userModel);
                  return const MainNavigationScreen();
                }
              }
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}