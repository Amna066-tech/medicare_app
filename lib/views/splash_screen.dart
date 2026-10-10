import 'package:flutter/material.dart';
import '../main.dart'; // To access AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    // Show splash screen for 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security, // Shield icon
              size: 120,
              color: brandBlue,
            ),
            const SizedBox(height: 24),
            const Text(
              "Medicare",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: brandBlue,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Smart Healthcare Reminder",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 64),
            const CircularProgressIndicator(
              color: brandBlue,
              strokeWidth: 4,
            ),
          ],
        ),
      ),
    );
  }
}
