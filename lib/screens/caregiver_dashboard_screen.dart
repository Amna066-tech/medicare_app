import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'feedback_screen.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() => _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1976D2); // Standard Material Blue

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Caregiver Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            tooltip: 'Send Feedback',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline), text: "Incoming"),
            Tab(icon: Icon(Icons.people_outline), text: "Accepted"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncomingTab(),
          _buildAcceptedTab(),
        ],
      ),
    );
  }

  Widget _buildIncomingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('caregiver_requests')
          .where('caregiverEmail', isEqualTo: currentUser?.email)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No new incoming requests",
              style: TextStyle(color: Colors.black45, fontSize: 16),
            ),
          );
        }

        var requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var doc = requests[index];
            var data = doc.data() as Map<String, dynamic>;
            
            return _buildRequestCard(
              docId: doc.id,
              patientName: data['patientName'] ?? 'Unknown Patient',
              patientEmail: data['patientEmail'] ?? 'No Email Provided',
              isPending: true,
              patientId: data['patientId'],
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('caregiver_requests')
          .where('caregiverEmail', isEqualTo: currentUser?.email)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "No accepted patient accounts linked yet.",
              style: TextStyle(color: Colors.black45, fontSize: 16),
            ),
          );
        }

        var requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            var doc = requests[index];
            var data = doc.data() as Map<String, dynamic>;
            
            return _buildRequestCard(
              docId: doc.id,
              patientName: data['patientName'] ?? 'Unknown Patient',
              patientEmail: data['patientEmail'] ?? 'No Email Provided',
              isPending: false,
              patientId: data['patientId'],
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard({
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
                  backgroundColor: isPending ? Colors.orange.withOpacity(0.15) : const Color(0xFF1976D2).withOpacity(0.15),
                  child: Icon(
                    isPending ? Icons.person_add_alt_1 : Icons.person,
                    color: isPending ? Colors.orange : const Color(0xFF1976D2),
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
                        backgroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.dashboard_customize_outlined, color: Colors.white, size: 20),
                      label: const Text(
                        "Open Patient Dashboard",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        if (patientId == null) return;
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