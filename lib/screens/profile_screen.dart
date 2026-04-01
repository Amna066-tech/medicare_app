import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // This helper function reaches into the database and counts the user's active items!
  Future<Map<String, int>> fetchHealthStats(String uid) async {
    final medQuery = await FirebaseFirestore.instance.collection('medications').where('userId', isEqualTo: uid).get();
    final apptQuery = await FirebaseFirestore.instance.collection('appointments').where('userId', isEqualTo: uid).get();
    final actQuery = await FirebaseFirestore.instance.collection('activities').where('userId', isEqualTo: uid).get();

    return {
      'medications': medQuery.docs.length,
      'appointments': apptQuery.docs.length,
      'activities': actQuery.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text("Not logged in"))
          : FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text("Profile data not found."));
          }

          var userData = userSnapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),

              const Text("Personal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge, color: Colors.blue),
                      title: const Text("Full Name", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(userData['name'] ?? 'N/A', style: const TextStyle(fontSize: 16, color: Colors.black)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email, color: Colors.blue),
                      title: const Text("Email Address", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(userData['email'] ?? 'N/A', style: const TextStyle(fontSize: 16, color: Colors.black)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cake, color: Colors.blue),
                      title: const Text("Date of Birth", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(userData['dob'] ?? 'N/A', style: const TextStyle(fontSize: 16, color: Colors.black)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.male, color: Colors.blue),
                      title: const Text("Gender", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      subtitle: Text(userData['gender'] ?? 'N/A', style: const TextStyle(fontSize: 16, color: Colors.black)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text("Health Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 12),

              // --- THE NEW HEALTH SUMMARY WIDGET ---
              FutureBuilder<Map<String, int>>(
                  future: fetchHealthStats(user.uid),
                  builder: (context, statsSnapshot) {
                    if (statsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    int meds = statsSnapshot.data?['medications'] ?? 0;
                    int appts = statsSnapshot.data?['appointments'] ?? 0;
                    int acts = statsSnapshot.data?['activities'] ?? 0;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard("Meds", meds.toString(), Icons.medical_services, Colors.blue),
                        _buildStatCard("Appts", appts.toString(), Icons.calendar_month, Colors.amber),
                        _buildStatCard("Habits", acts.toString(), Icons.directions_run, Colors.orange),
                      ],
                    );
                  }
              )
            ],
          );
        },
      ),
    );
  }

  // A small helper to draw the individual statistic boxes nicely
  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}