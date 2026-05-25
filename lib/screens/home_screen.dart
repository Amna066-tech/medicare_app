import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

// --- WE NOW IMPORT YOUR LIST SCREENS INSTEAD OF ADD SCREENS ---
import 'medication_list_screen.dart';
import 'measurement_list_screen.dart';
import 'activity_list_screen.dart';
import 'appointment_list_screen.dart';

class HomeScreen extends StatelessWidget {
  final String? viewingPatientId;

  const HomeScreen({super.key, this.viewingPatientId});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String targetUserId = viewingPatientId ?? currentUser?.uid ?? 'empty';
    final bool isCaregiverViewing = viewingPatientId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: isCaregiverViewing
          ? AppBar(
              title: const Text("Patient Dashboard View"),
              backgroundColor: const Color(0xFF2C3E50),
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          // 1. Beautiful Curved Header
          Container(
            padding: EdgeInsets.only(top: isCaregiverViewing ? 20 : 60, left: 24, right: 24, bottom: 30),
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
            child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(targetUserId).snapshots(),
                builder: (context, snapshot) {
                  String name = "User";
                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    name = data['name'] ?? "User";
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.health_and_safety, color: Colors.white, size: 40),
                          if (!isCaregiverViewing)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person, color: Colors.white, size: 28),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 28),
                                  onPressed: () => logout(context),
                                ),
                              ],
                            )
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Hello,",
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Let's manage the daily health routine.",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  );
                }),
          ),

          // 2. The Dashboard Grid
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
