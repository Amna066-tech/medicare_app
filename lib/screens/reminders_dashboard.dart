import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Your existing list screens
import 'medication_list_screen.dart';
import 'measurement_list_screen.dart';
import 'activity_list_screen.dart';
import 'appointment_list_screen.dart';

class RemindersDashboard extends StatelessWidget {
  const RemindersDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. Beautiful Curved Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.health_and_safety, color: Colors.white, size: 40),
                const SizedBox(height: 20),
                const Text(
                  "Hello,",
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                Text(
                  user?.email?.split('@')[0] ?? "User",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Let's manage your daily health routine.",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // 2. The 4 Grid Buttons You Requested
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(24),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildDashboardCard(
                  context,
                  "Medications",
                  "Pills, Syrups & Drops",
                  Icons.medication,
                  Colors.blue,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MedicationListScreen())),
                ),
                _buildDashboardCard(
                  context,
                  "Measurements",
                  "Weight, BP & Sugar",
                  Icons.monitor_weight_outlined,
                  Colors.teal,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MeasurementListScreen())),
                ),
                _buildDashboardCard(
                  context,
                  "Activities",
                  "Walking, Water & Meals",
                  Icons.directions_run,
                  Colors.orange,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityListScreen())),
                ),
                _buildDashboardCard(
                  context,
                  "Appointments",
                  "Doctors & Checkups",
                  Icons.calendar_month,
                  Colors.purple,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppointmentListScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The helper widget that makes the 4 beautiful cards
  Widget _buildDashboardCard(BuildContext context, String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}