import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication_model.dart';
import '../models/intake_model.dart';
import '../services/database_service.dart';

class DailyIntakeScreen extends StatelessWidget {
  const DailyIntakeScreen({super.key});

  void _markMedication(BuildContext context, MedicationModel med, String status) async {
    // Get today's date formatted as YYYY-MM-DD
    String today = DateTime.now().toString().substring(0, 10);

    IntakeModel intake = IntakeModel(
      id: '',
      userId: FirebaseAuth.instance.currentUser!.uid,
      medicationId: med.id,
      medicationName: med.name,
      date: today,
      status: status,
    );

    String res = await DatabaseService().logIntake(intake);

    if (context.mounted) {
      if (res == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${med.name} marked as $status!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Today's Medication"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<MedicationModel>>(
        stream: DatabaseService().getMedications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No medications to track today."));
          }

          List<MedicationModel> meds = snapshot.data!;

          return ListView.builder(
            itemCount: meds.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              MedicationModel med = meds[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("${med.dosage} at ${med.reminderTimes}", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _markMedication(context, med, "Taken"),
                            icon: const Icon(Icons.check),
                            label: const Text("Taken"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _markMedication(context, med, "Missed"),
                            icon: const Icon(Icons.close),
                            label: const Text("Missed"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          ),
                        ],
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