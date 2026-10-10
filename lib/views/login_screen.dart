import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main_navigation_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'signup_screen.dart';
import 'pharmacy_dashboard_screen.dart';
import '../models/user_model.dart';
import '../services/chat_notification_service.dart';
import '../services/alert_notification_service.dart';
import 'doctor_verification_screen.dart';
import 'nurse_verification_screen.dart';
import 'pharmacist_verification_screen.dart';
import 'admin_login_screen.dart';
import 'rejected_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'User profile data not found in database.',
        );
      }

      UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>, userDoc.id);
      String role = user.role;
      String status = user.verificationStatus;
      String? caregiverType = user.caregiverType;

      // Check unread messages and alerts on login
      ChatNotificationService().checkUnreadOnLogin();

      if (mounted) {
        if (role == 'Patient') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
        } else if (role == 'Caregiver' && caregiverType == 'Friend/Relative') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CaregiverDashboardScreen()));
        } else {
          // Roles requiring verification
          if (status == 'APPROVED') {
            if (role == 'Doctor') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DoctorDashboardScreen()));
            } else if (role == 'Caregiver' && caregiverType == 'Nurse') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CaregiverDashboardScreen()));
            } else if (role == 'Pharmacist') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PharmacyDashboardScreen()));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
            }
          } else if (status == 'REJECTED') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RejectedScreen()));
          } else {
            // NOT_SUBMITTED, PENDING
            if (role == 'Doctor') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DoctorVerificationScreen(user: user)));
            } else if (role == 'Caregiver' && caregiverType == 'Nurse') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NurseVerificationScreen(user: user)));
            } else if (role == 'Pharmacist') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PharmacistVerificationScreen(user: user)));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Password", style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your registered email address below. We will send you a secure link to reset your password.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "Email Address",
                prefixIcon: const Icon(Icons.email, color: Color(0xFF1976D2)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter an email address"), backgroundColor: Colors.orange),
                );
                return;
              }

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password reset email sent! Check your inbox."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? "Failed to send reset email"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Send Link", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1976D2);
    const Color inputFillColor = Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Column(
          children: [
            // Header area with icon and title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminLoginScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.add_moderator, size: 70, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Medicare",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                padding: const EdgeInsets.all(24.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        "Welcome Back",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 32),
                      
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "Email Address",
                          hintStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.email, color: primaryBlue),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.lock_outline, color: primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: primaryBlue),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text("Forgot Password?", style: TextStyle(color: primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen()));
                            },
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}