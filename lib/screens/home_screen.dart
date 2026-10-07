import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reminders_dashboard.dart';
import 'measurement_list_screen.dart';
import 'activity_list_screen.dart';
import 'medical_professional_screen.dart';
import 'feedback_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? viewingPatientId;
  const HomeScreen({super.key, this.viewingPatientId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = "Loading...";
  bool _isRequestingCaregiver = false;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final String targetId = widget.viewingPatientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (targetId.isEmpty) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(targetId).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc['name'] ?? 'Patient';
        });
      }
    } catch (e) {
      debugPrint("Error fetching username: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isExternalViewing = widget.viewingPatientId != null;
    final String streamTargetUserId = widget.viewingPatientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1550A6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.shield, color: Colors.white, size: 40),
                      if (isExternalViewing)
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.feedback_outlined, color: Colors.white, size: 28),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Hello,", style: TextStyle(color: Colors.white70, fontSize: 18)),
                  Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Let's manage your daily health routine.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            // Dynamic Doctor's Note Section
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recommendations')
                  .where('patientId', isEqualTo: streamTargetUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text("Error loading notes: ${snapshot.error}"),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final List<QueryDocumentSnapshot> docs = List.from(snapshot.data!.docs);
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final Timestamp? aTime = aData['timestamp'] as Timestamp?;
                  final Timestamp? bTime = bData['timestamp'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                final latestRec = docs.first.data() as Map<String, dynamic>;
                final String doctorNote = latestRec['doctorNotes'] ?? '';
                final bool caregiverRecommended = latestRec['caregiverRequired'] ?? false;

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(13),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CA1AF).withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.note_alt_outlined, color: Color(0xFF4CA1AF)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Latest Doctor's Note",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doctorNote.isNotEmpty ? doctorNote : "No notes yet.",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Caregiver Recommendation Banner
                    if (caregiverRecommended)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withAlpha(76)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Doctor recommends adding a caregiver to your profile.",
                                style: TextStyle(
                                  color: Color(0xFF855D10),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF855D10).withAlpha(30),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isRequestingCaregiver ? null : () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;

                                setState(() => _isRequestingCaregiver = true);

                                try {
                                  await FirebaseFirestore.instance.collection('caregiver_requests').add({
                                    'patientId': user.uid,
                                    'patientName': _userName,
                                    'status': 'pending',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Caregiver request submitted successfully!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Failed to request caregiver: $e")),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isRequestingCaregiver = false);
                                  }
                                }
                              },
                              child: _isRequestingCaregiver
                                  ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF855D10)),
                                ),
                              )
                                  : const Text(
                                "Request",
                                style: TextStyle(
                                  color: Color(0xFF855D10),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),

            // Grid Buttons Dashboard Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: streamTargetUserId)
                    .snapshots(),
                builder: (context, chatSnapshot) {
                  bool hasUnreadMedicalChats = false;

                  if (chatSnapshot.hasData) {
                    for (var doc in chatSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final bool isRead = data['isRead'] ?? true;
                      final String lastSenderId = data['lastSenderId'] ?? '';
                      // If the message is unread and it wasn't sent by the current patient
                      if (!isRead && lastSenderId != streamTargetUserId) {
                        hasUnreadMedicalChats = true;
                        break;
                      }
                    }
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                    children: [
                      _buildCard(
                        icon: Icons.medication,
                        iconColor: const Color(0xFF1550A6),
                        iconBgColor: const Color(0xFF1550A6).withOpacity(0.1),
                        title: "Medications",
                        subtitle: "Pills & Drops",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RemindersDashboard(patientId: streamTargetUserId)),
                        ),
                      ),
                      _buildCard(
                        icon: Icons.straighten,
                        iconColor: Colors.cyan,
                        iconBgColor: Colors.cyan.withOpacity(0.1),
                        title: "Measurements",
                        subtitle: "Weight & BP",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MeasurementListScreen(patientId: streamTargetUserId)),
                        ),
                      ),
                      _buildCard(
                        icon: Icons.directions_run,
                        iconColor: Colors.teal,
                        iconBgColor: Colors.teal.withOpacity(0.1),
                        title: "Activities",
                        subtitle: "Walking & Water",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ActivityListScreen(patientId: streamTargetUserId)),
                        ),
                      ),
                      _buildCard(
                        icon: Icons.badge,
                        iconColor: Colors.orange,
                        iconBgColor: Colors.orange.withOpacity(0.1),
                        title: "Medical Professional",
                        subtitle: "",
                        hasNotification: hasUnreadMedicalChats,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MedicalProfessionalScreen(viewingPatientId: streamTargetUserId)),
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool hasNotification = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
                if (hasNotification)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 15,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}