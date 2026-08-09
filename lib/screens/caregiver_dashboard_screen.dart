import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart'; // Navigating to MainNavigationScreen instead of raw HomeScreen

class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // Soft background style
      appBar: AppBar(
        title: const Text("Caregiver Dashboard"),
        backgroundColor: const Color(0xFF2C4356), // Matches dark app bar theme
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listens to all connection requests tied to this caregiver's email address
        stream: FirebaseFirestore.instance
            .collection('caregiver_requests')
            .where('caregiverEmail', isEqualTo: currentUser?.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No patient requests yet.",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          var allRequests = snapshot.data!.docs;

          // Split the documents into two distinct reactive UI categories
          var pendingRequests = allRequests.where((doc) => doc['status'] == 'pending').toList();
          var activeConnections = allRequests.where((doc) => doc['status'] == 'accepted').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- SECTION 1: INCOMING REQUESTS (PENDING APPROVAL) ---
              if (pendingRequests.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "Incoming Patient Requests",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C4356)),
                  ),
                ),
                ...pendingRequests.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildRequestCard(
                    context: context,
                    docId: doc.id,
                    patientName: data['patientName'] ?? 'Unknown Patient',
                    patientEmail: data['patientEmail'] ?? 'No Email Provided',
                    isPending: true,
                    patientId: data['patientId'],
                  );
                }),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
              ],

              // --- SECTION 2: MY CONNECTED PATIENTS (ACTIVE VIEWS) ---
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  "My Connected Patients",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
              ),

              if (activeConnections.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      "No accepted patient accounts linked yet.",
                      style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ...activeConnections.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildRequestCard(
                    context: context,
                    docId: doc.id,
                    patientName: data['patientName'] ?? 'Unknown Patient',
                    patientEmail: data['patientEmail'] ?? 'No Email Provided',
                    isPending: false,
                    patientId: data['patientId'],
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  // Helper widget builder to generate consistent, modern card styles matching your UI
  Widget _buildRequestCard({
    required BuildContext context,
    required String docId,
    required String patientName,
    required String patientEmail,
    required bool isPending,
    required String? patientId,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isPending ? Colors.orange.withOpacity(0.15) : const Color(0xFF4FA4B8).withOpacity(0.15),
                  child: Icon(
                    isPending ? Icons.person_add_alt_1 : Icons.person,
                    color: isPending ? Colors.orange : const Color(0xFF4FA4B8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2C4356)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patientEmail,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isPending
                  ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('caregiver_requests')
                      .doc(docId)
                      .update({'status': 'accepted'});
                },
                child: const Text(
                  "Accept Access Request",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
                  : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FA4B8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.dashboard_customize_outlined, color: Colors.white, size: 20),
                label: const Text(
                  "Open Patient Dashboard",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  // Navigating to MainNavigationScreen with viewingPatientId attached
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainNavigationScreen(viewingPatientId: patientId),
                    ),
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