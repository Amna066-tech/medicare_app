import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_medication_screen.dart';
import 'edit_medication_screen.dart';
import '../models/medication_model.dart';

class MedicationListScreen extends StatelessWidget {
  final String? patientId;

  const MedicationListScreen({super.key, this.patientId});

  void updateDoseStatus(BuildContext context, String docId, int doseIndex, String status) async {
    try {
      await FirebaseFirestore.instance.collection('medications').doc(docId).set({
        'doseStatuses': {
          doseIndex.toString(): status
        },
        'lastUpdated': DateTime.now().toString(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dose ${doseIndex + 1} marked as $status")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void deleteMedication(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('medications').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medication deleted")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String targetUid = patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isCaregiverView = patientId != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Medications", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: isCaregiverView
          ? null
          : FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMedicationScreen())),
        backgroundColor: const Color(0xFF4CA1AF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Med", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24, top: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF4CA1AF),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Daily Routine", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 8),
                Text("Manage your prescriptions and track every dose.", style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medications')
                  .where('userId', isEqualTo: targetUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No medications found.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;

                    List<dynamic> times = data['reminderTimes'] ?? [];
                    Map<String, dynamic> doseStatuses = data['doseStatuses'] ?? {};

                    // NEW DATA EXTRACTION: Pull health condition string details cleanly
                    String diseaseName = data['diseaseName'] ?? 'General Care';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          shape: BoxShape.circle
                                      ),
                                      child: const Icon(Icons.medication, color: Colors.blue),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                                        // UPDATED UI: Includes health condition layout directly under subheadings
                                        Text("For: $diseaseName", style: const TextStyle(color: Color(0xFF4CA1AF), fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text("${data['dosage']} • ${data['frequency']}", style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                if (!isCaregiverView)
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        MedicationModel currentMed = MedicationModel(
                                          id: docId,
                                          userId: data['userId'] ?? '',
                                          name: data['name'] ?? '',
                                          dosage: data['dosage'] ?? '',
                                          diseaseName: diseaseName, // PASS TO EDIT
                                          frequency: data['frequency'] ?? 'Once a day',
                                          startDate: data['startDate'] ?? '',
                                          endDate: data['endDate'] ?? '',
                                          reminderTimes: times,
                                        );
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditMedicationScreen(medication: currentMed)));
                                      } else if (value == 'delete') {
                                        deleteMedication(context, docId);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                                      const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                                    ],
                                  )
                              ],
                            ),
                            const Divider(height: 24),

                            ...List.generate(times.length, (doseIndex) {
                              String currentStatus = doseStatuses[doseIndex.toString()] ?? "Pending";
                              bool isLocked = currentStatus != "Pending";

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        "Dose ${doseIndex + 1} (${times[doseIndex]})",
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))
                                    ),

                                    isLocked
                                        ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: currentStatus == "Taken" ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20)
                                      ),
                                      child: Text(
                                          currentStatus,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: currentStatus == "Taken" ? Colors.green : Colors.red
                                          )
                                      ),
                                    )
                                        : Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => updateDoseStatus(context, docId, doseIndex, "Missed"),
                                          icon: const Icon(Icons.close, color: Colors.redAccent),
                                          tooltip: "Mark Missed",
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        IconButton(
                                          onPressed: () => updateDoseStatus(context, docId, doseIndex, "Taken"),
                                          icon: const Icon(Icons.check, color: Colors.green),
                                          tooltip: "Mark Taken",
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            }),
                          ],
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
    );
  }
}