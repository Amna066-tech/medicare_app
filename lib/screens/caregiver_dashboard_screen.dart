import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final caregiverEmail = user?.email?.toLowerCase() ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Caregiver Dashboard"),
        backgroundColor: const Color(0xFF4CA1AF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Assigned Patients", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('caregiver_requests')
                    .where('caregiverEmail', isEqualTo: caregiverEmail)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No incoming connection requests found."));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String status = data['status'] ?? 'pending';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: status == 'accepted' 
                                ? Colors.green.withValues(alpha: 0.1) 
                                : Colors.orange.withValues(alpha: 0.1),
                            child: Icon(Icons.assignment_ind, color: status == 'accepted' ? Colors.green : Colors.orange),
                          ),
                          title: Text(data['patientName'] ?? 'Unknown Patient', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Status: ${status.toUpperCase()}", style: TextStyle(color: status == 'accepted' ? Colors.green : Colors.orange, fontWeight: FontWeight.w500)),
                          trailing: status == 'pending'
                              ? ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('caregiver_requests').doc(doc.id).update({
                                'status': 'accepted'
                              });
                            },
                            child: const Text("Accept", style: TextStyle(color: Colors.white)),
                          )
                              : ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => HomeScreen(viewingPatientId: data['patientId']),
                              ));
                            },
                            child: const Text("View Patient", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
