import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Ensure this matches your login screen path

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {

  // Deletes a patient request from Firestore manually
  void _deleteRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('connection_requests').doc(requestId).delete();
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

  // Interactive panel for the doctor to evaluate requests and submit/update their assessment
  void _openAssessmentSheet(
      String requestId,
      String patientName,
      String reason,
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
                      "Patient Symptoms/Reason:\n$reason",
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
                      activeTrackColor: const Color(0xFF4CA1AF),
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
                          if (recController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please fill in recommendations before confirming approval.")),
                            );
                            return;
                          }

                          setModalState(() => isSaving = true);

                          try {
                            // Approves the entry and saves recommendations and caregiver toggle state
                            await FirebaseFirestore.instance
                                .collection('connection_requests')
                                .doc(requestId)
                                .update({
                              'status': 'approved',
                              'recommendations': recController.text.trim(),
                              'suggestCaregiver': suggestCaregiver,
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Patient response updated and saved!")),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error updating response: $e")),
                              );
                            }
                          }
                        },
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "Save & Send Response",
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
    final doctorEmail = currentDoctor?.email?.toLowerCase() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Doctor Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Logout to Login Screen',
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
      ),
      body: currentDoctor == null
          ? const Center(child: Text("Please log in to view active medical pipelines."))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('connection_requests')
            .where('doctorEmail', isEqualTo: doctorEmail)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text("No connection requests found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const Text("Patient requests sent to your email will appear here.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestDoc = requests[index];
              final requestData = requestDoc.data() as Map<String, dynamic>;
              final isApproved = requestData['status'] == 'approved';
              final bool suggestCaregiver = requestData['suggestCaregiver'] == true;

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
                            backgroundColor: const Color(0xFF4CA1AF).withValues(alpha: 0.1),
                            child: const Icon(Icons.person, color: Color(0xFF4CA1AF)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  requestData['patientName'] ?? 'Patient User',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50)),
                                ),
                                Text(
                                  "Requested Field: ${requestData['specialty'] ?? 'General'}",
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isApproved ? "Approved" : "Pending",
                              style: TextStyle(
                                color: isApproved ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            tooltip: 'Delete request',
                            onPressed: () => _deleteRequest(requestDoc.id),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        "Patient Reason Details:",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        requestData['reason'] ?? '',
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      if (isApproved && (requestData['recommendations'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Your Prescribed Advice: ${requestData['recommendations']}",
                            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(isApproved ? Icons.edit_note : Icons.rate_review_outlined, size: 18, color: Colors.white),
                          label: Text(
                            isApproved ? "Edit Response" : "Review & Respond",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isApproved ? Colors.blueGrey : const Color(0xFF4CA1AF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            _openAssessmentSheet(
                              requestDoc.id,
                              requestData['patientName'] ?? 'Patient',
                              requestData['reason'] ?? '',
                              requestData['recommendations'] ?? '',
                              suggestCaregiver,
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}