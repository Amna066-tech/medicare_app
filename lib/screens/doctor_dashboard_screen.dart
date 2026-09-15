import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_navigation_screen.dart'; // Renders full patient dashboard with bottom navigation tabs
import 'login_screen.dart';
import 'chat_screen.dart'; // Ensure this file is imported for chat navigation
import 'review_patient_screen.dart';
import 'feedback_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;
  static const Color brandBlue = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _deleteRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('access_requests').doc(requestId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request removed successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error removing request: $e")),
        );
      }
    }
  }

  // Helper method to show receipt full-screen dialog when receipt image is tapped
  void _showReceiptDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text("Payment Receipt", style: TextStyle(color: Colors.white, fontSize: 16)),
              backgroundColor: brandBlue,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 150,
                    child: Center(child: Text("Failed to load receipt image")),
                  ),
                )
                    : const SizedBox(
                  height: 150,
                  child: Center(child: Text("No receipt image provided")),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to update payment status in Firestore
  Future<void> _updatePaymentStatus(String paymentId, String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('payments').doc(paymentId).update({
        'status': newStatus,
      });

      if (requestId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('access_requests').doc(requestId).update({
          'paymentStatus': newStatus,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment status updated to $newStatus")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating status: $e")),
        );
      }
    }
  }

  void _openAssessmentSheet(
      String requestId,
      String patientName,
      String symptoms,
      String currentRec,
      bool initialSuggestCaregiver,
      ) {
    final recController = TextEditingController(text: currentRec);
    bool suggestCaregiver = initialSuggestCaregiver;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reviewing: $patientName",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Symptoms / Reason:\n$symptoms",
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: recController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Medical Recommendations / Prescriptions",
                        hintText: "Add treatment rules, instructions, or next steps...",
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Suggest Caregiver Assignment?", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text("Enable if this patient requires continuous at-home monitoring"),
                      value: suggestCaregiver,
                      activeTrackColor: brandBlue,
                      onChanged: (val) {
                        setModalState(() => suggestCaregiver = val);
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving ? null : () async {
                          setModalState(() => isSaving = true);

                          try {
                            await FirebaseFirestore.instance
                                .collection('access_requests')
                                .doc(requestId)
                                .update({
                              'status': 'accepted',
                              'recommendations': recController.text.trim(),
                              'suggestCaregiver': suggestCaregiver,
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Request accepted and details saved!")),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error saving details: $e")),
                              );
                            }
                          }
                        },
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "Accept & Save Response",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDoctor = FirebaseAuth.instance.currentUser;
    final String docEmail = currentDoctor?.email?.toLowerCase().trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Doctor Portal", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: brandBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Logout',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined, color: Colors.white),
            tooltip: 'Send Feedback',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.mail_outline), text: "Incoming"),
            Tab(icon: Icon(Icons.group_outlined), text: "Accepted"),
            Tab(icon: Icon(Icons.payments_outlined), text: "Payments"),
          ],
        ),
      ),
      body: currentDoctor == null
          ? const Center(child: Text("Please log in to view patient requests."))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('access_requests')
            .where('doctorEmail', isEqualTo: docEmail)
            .snapshots(),
        builder: (context, requestSnapshot) {
          if (requestSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: brandBlue));
          }

          final allDocs = requestSnapshot.hasData ? requestSnapshot.data!.docs : [];

          // Split docs into Incoming and Accepted categories
          final incomingDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] != 'accepted';
          }).toList();

          final acceptedDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == 'accepted';
          }).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('doctorEmail', isEqualTo: docEmail)
                .snapshots(),
            builder: (context, paymentSnapshot) {
              final paymentDocs = paymentSnapshot.hasData ? paymentSnapshot.data!.docs : [];

              return TabBarView(
                controller: _tabController,
                children: [
                  // TAB 0: Incoming
                  incomingDocs.isEmpty
                      ? const Center(child: Text("No incoming requests", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: incomingDocs.length,
                    itemBuilder: (context, index) {
                      final requestDoc = incomingDocs[index];
                      final requestData = requestDoc.data() as Map<String, dynamic>;
                      final bool suggestCaregiver = requestData['suggestCaregiver'] == true;
                      final String patientId = requestData['patientId'] ?? '';
                      final String patientName = requestData['patientName'] ?? 'Patient User';
                      final String symptoms = requestData['symptoms'] ?? requestData['reason'] ?? '';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0x1A1565C0),
                                    child: Icon(Icons.person, color: brandBlue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patientName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Symptoms: $symptoms",
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () {
                                            if (patientId.isEmpty) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MainNavigationScreen(
                                                  viewingPatientId: patientId,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            "View Patient Dashboard",
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReviewPatientScreen(
                                            requestId: requestDoc.id,
                                            patientName: patientName,
                                            symptoms: symptoms,
                                            requestData: requestData,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                    tooltip: 'Delete request',
                                    onPressed: () => _deleteRequest(requestDoc.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // TAB 1: Accepted
                  acceptedDocs.isEmpty
                      ? const Center(child: Text("No accepted requests", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: acceptedDocs.length,
                    itemBuilder: (context, index) {
                      final requestDoc = acceptedDocs[index];
                      final requestData = requestDoc.data() as Map<String, dynamic>;
                      final bool suggestCaregiver = requestData['suggestCaregiver'] == true;
                      final String patientId = requestData['patientId'] ?? '';
                      final String patientName = requestData['patientName'] ?? 'Patient User';
                      final String symptoms = requestData['symptoms'] ?? requestData['reason'] ?? '';
                      final String chatId = requestData['requestId'] ?? requestDoc.id;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person, color: Colors.green),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patientName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Symptoms: $symptoms",
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () {
                                            if (patientId.isEmpty) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MainNavigationScreen(
                                                  viewingPatientId: patientId,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            "View Patient Dashboard",
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline, color: brandBlue, size: 22),
                                    tooltip: 'Chat with Patient',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            chatId: chatId,
                                            peerName: patientName,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReviewPatientScreen(
                                            requestId: requestDoc.id,
                                            patientName: patientName,
                                            symptoms: symptoms,
                                            requestData: requestData,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text("Edit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                    tooltip: 'Delete request',
                                    onPressed: () => _deleteRequest(requestDoc.id),
                                  ),
                                ],
                              ),
                              if ((requestData['recommendations'] ?? '').isNotEmpty) ...[
                                const Divider(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Prescribed Advice: ${requestData['recommendations']}",
                                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // TAB 2: Payments (Fully wired with live Firestore payments data & approval actions)
                  paymentDocs.isEmpty
                      ? const Center(child: Text("No payments received yet", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: paymentDocs.length,
                    itemBuilder: (context, index) {
                      final doc = paymentDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final paymentId = doc.id;
                      final requestId = data['requestId'] ?? '';
                      final patientName = data['patientName'] ?? data['patientEmail'] ?? 'Patient User';
                      final transactionId = data['transactionId'] ?? 'N/A';
                      final status = data['status'] ?? 'Pending';
                      final receiptUrl = data['receiptUrl'] ?? '';
                      final paymentMethod = data['paymentMethod'] ?? 'EasyPaisa';
                      final bool isApproved = status == 'Approved';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Receipt Thumbnail preview
                            GestureDetector(
                              onTap: () => _showReceiptDialog(context, receiptUrl),
                              child: Container(
                                width: 70,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: receiptUrl.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(receiptUrl, fit: BoxFit.cover),
                                )
                                    : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, color: Colors.blueGrey, size: 28),
                                    SizedBox(height: 4),
                                    Text("View", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Details Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patientName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "ID: $transactionId",
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Method: $paymentMethod",
                                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Status: $status",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isApproved ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Action Button / Badge
                            Column(
                              children: [
                                if (isApproved)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: const Text(
                                      "Approved",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _updatePaymentStatus(paymentId, requestId, 'Approved'),
                                    child: const Text("Approve", style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}