import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';

class MedicalHistoryScreen extends StatelessWidget {
  final String userId;
  const MedicalHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Medical History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
            child: const Text(
              "Past Medications & Conditions",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medications')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No medical history found."));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final med = MedicationModel.fromMap(
                      docs[index].data() as Map<String, dynamic>,
                      docs[index].id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.medication, color: Color(0xFF4CA1AF)),
                                const SizedBox(width: 10),
                                Text(med.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 24),
                            Text("Condition: ${med.diseaseName}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text("Dosage: ${med.dosage}"),
                            const SizedBox(height: 8),
                            Text("Reminder Times: ${med.reminderTimes.join(', ')}"),
                            const SizedBox(height: 8),
                            Text("Frequency: ${med.frequency}"),
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
