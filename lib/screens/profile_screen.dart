import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: user == null
          ? const Center(child: Text("Please log in to view your profile."))
          : FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
          }

          // If no data exists yet, we provide safe default values so it doesn't crash!
          String name = "New User";
          String email = user.email ?? "No Email";

          if (snapshot.hasData && snapshot.data!.exists) {
            var userData = snapshot.data!.data() as Map<String, dynamic>;
            name = userData['name'] ?? "New User";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. Profile Header area
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 30, top: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CA1AF),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const CircleAvatar(
                          radius: 50,
                          backgroundColor: Color(0xFF2C3E50),
                          child: Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(email, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Account Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 16),

                      // 2. The 3 Sections You Requested!
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            // Medical History
                            ListTile(
                              leading: _buildIcon(Icons.history_edu, Colors.blue),
                              title: const Text("Medical History", style: TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History coming soon!")));
                              },
                            ),
                            const Divider(height: 1, indent: 60),

                            // Emergency Contacts
                            ListTile(
                              leading: _buildIcon(Icons.emergency, Colors.red),
                              title: const Text("Emergency Contacts", style: TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emergency Contacts coming soon!")));
                              },
                            ),
                            const Divider(height: 1, indent: 60),

                            // Feedback
                            ListTile(
                              leading: _buildIcon(Icons.feedback_outlined, Colors.orange),
                              title: const Text("Send Feedback", style: TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback form coming soon!")));
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 3. Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text("LOG OUT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          onPressed: () => logout(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Quick helper widget for beautiful icons
  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color),
    );
  }
}