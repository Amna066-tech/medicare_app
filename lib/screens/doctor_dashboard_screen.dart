import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'doctor_patient_detail_screen.dart';

class DoctorDashboardScreen extends StatelessWidget {
  const DoctorDashboardScreen({super.key});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Doctor Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => logout(context))],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("My Patients", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 8),
                Text("Select a patient to monitor health and add recommendations.", style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Patient').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No patients found.", style: TextStyle(fontSize: 18, color: Colors.grey)));

                final patients = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    var patientData = patients[index].data() as Map<String, dynamic>? ?? {};

                    String name = patientData.containsKey('name') ? patientData['name'] : "Unknown Patient";
                    String email = patientData.containsKey('email') ? patientData['email'] : "No Email";
                    String patientId = patients[index].id;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(radius: 25, backgroundColor: const Color(0xFF4CA1AF).withOpacity(0.2), child: const Icon(Icons.person, color: Color(0xFF4CA1AF), size: 28)),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                        subtitle: Text(email),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => DoctorPatientDetailScreen(patientId: patientId, patientName: name)));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}