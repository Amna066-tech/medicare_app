import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_medication_screen.dart';
import 'edit_medication_screen.dart';
import '../models/medication_model.dart';
import '../services/database_service.dart';

class MedicationListScreen extends StatelessWidget {
  final String? patientId;

  const MedicationListScreen({super.key, this.patientId});

  void updateDoseStatus(BuildContext context, String docId, int doseIndex, String status, String medName) async {
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // 1. Update the medication dose status
      await FirebaseFirestore.instance.collection('medications').doc(docId).set({
        'doseStatuses': {
          doseIndex.toString(): status
        },
        'lastUpdated': DateTime.now().toString(),
      }, SetOptions(merge: true));

      // 2. Add to Medical History
      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': currentUserId,
        'title': "$medName - Dose ${doseIndex + 1} ($status)",
        'category': 'Medication',
        'status': status, // 'Taken' or 'Missed'
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Decrement stock if Taken
      if (status == "Taken") {
        await DatabaseService().processMedicationIntake(docId);
      }

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Medication Reminders", style: TextStyle(color: Colors.white, fontSize: 20)),
        backgroundColor: const Color(0xFF1550A6),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (context) => const AddMedicationScreen()),
        backgroundColor: const Color(0xFF1550A6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .where('userId', isEqualTo: targetUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1550A6)));
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
              String name = data['name'] ?? 'Unknown';
              String diseaseName = data['diseaseName'] ?? 'General Care';
              String dosage = data['dosage'] ?? '1';
              String frequency = data['frequency'] ?? 'Once a day';
              String startDate = data['startDate'] ?? 'N/A';
              int? stock = data['stock'] as int?;
              
              String formattedTimes = times.isNotEmpty ? times.join(", ") : "No time set";

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBF3FC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.medication, color: Color(0xFF1550A6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    
                    // Main Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              const Icon(Icons.science, color: Color(0xFF1550A6), size: 18),
                              const SizedBox(width: 8),
                              Text("Dosage: $dosage", style: const TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.grey, size: 18),
                              const SizedBox(width: 8),
                              Text(startDate, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(formattedTimes, style: const TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3FC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(frequency, style: const TextStyle(color: Color(0xFF1550A6), fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                          
                          if (stock != null) ...[
                             const SizedBox(height: 8),
                             Row(
                               children: [
                                 const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 18),
                                 const SizedBox(width: 8),
                                 Text("Stock: $stock", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                               ],
                             )
                          ]
                        ],
                      ),
                    ),
                    
                    // Right Edit/Delete Icon
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF1550A6)),
                          onPressed: () {
                            MedicationModel currentMed = MedicationModel(
                              id: docId,
                              userId: data['userId'] ?? '',
                              name: name,
                              dosage: data['dosage'] ?? '',
                              diseaseName: diseaseName,
                              frequency: data['frequency'] ?? 'Once a day',
                              startDate: data['startDate'] ?? '',
                              endDate: data['endDate'] ?? '',
                              reminderTimes: times,
                              selectedDates: data['selectedDates'] != null 
                                  ? List<String>.from(data['selectedDates']) 
                                  : [data['startDate'] ?? ''],
                              stock: stock,
                            );
                            Navigator.push(context, MaterialPageRoute(builder: (context) => EditMedicationScreen(medication: currentMed)));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => deleteMedication(context, docId),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}