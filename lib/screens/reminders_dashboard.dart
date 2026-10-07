import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_medication_screen.dart';
import 'edit_medication_screen.dart';
import '../models/medication_model.dart';

class RemindersDashboard extends StatefulWidget {
  final String? patientId;

  const RemindersDashboard({super.key, this.patientId});

  @override
  State<RemindersDashboard> createState() => _RemindersDashboardState();
}

class _RemindersDashboardState extends State<RemindersDashboard> {
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
    // Correctly matches the stream lookups dynamically
    final String currentUserId = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medication Reminders"),
        backgroundColor: const Color(0xFF1550A6),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('medications')
            .where('userId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No medications scheduled yet."));
          }

          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              
              String timesStr = 'N/A';
              if (data['reminderTimes'] != null && (data['reminderTimes'] as List).isNotEmpty) {
                 timesStr = (data['reminderTimes'] as List).join(", ");
              }
              
              return ListTile(
                leading: const Icon(Icons.medication, color: Color(0xFF1550A6)),
                title: Text(data['name'] ?? 'Unknown Medicine'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Dosage: ${data['dosage'] ?? 'N/A'} — Times: $timesStr"),
                    if (data['stock'] != null)
                      Text(
                        "Stock: ${data['stock']}", 
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF1550A6)),
                      onPressed: () {
                        MedicationModel currentMed = MedicationModel(
                          id: docId,
                          userId: data['userId'] ?? '',
                          name: data['name'] ?? '',
                          dosage: data['dosage'] ?? '',
                          diseaseName: data['diseaseName'] ?? '',
                          frequency: data['frequency'] ?? 'Once a day',
                          startDate: data['startDate'] ?? '',
                          endDate: data['endDate'] ?? '',
                          reminderTimes: data['reminderTimes'] != null ? List<String>.from(data['reminderTimes']) : [],
                          selectedDates: data['selectedDates'] != null 
                              ? List<String>.from(data['selectedDates']) 
                              : [data['startDate'] ?? ''],
                          stock: data['stock'],
                        );
                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditMedicationScreen(medication: currentMed)));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => deleteMedication(context, docId),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1550A6),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AddMedicationScreen(patientId: currentUserId),
          );
        },
      ),
    );
  }
}