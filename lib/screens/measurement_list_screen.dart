import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_measurement_screen.dart';

class MeasurementListScreen extends StatelessWidget {
  final String? patientId;

  const MeasurementListScreen({super.key, this.patientId});

  void deleteMeasurement(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('measurements').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Measurement deleted")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Falls back to current user if no patientId passed by caregiver
    final String currentUserId = patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Measurements Data Log"),
        backgroundColor: const Color(0xFF1550A6),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('measurements')
            .where('userId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No measurements tracked yet."));
          }

          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              return ListTile(
                title: Text("Value: ${data['value'] ?? 'N/A'}"),
                subtitle: Text("Type: ${data['type'] ?? 'General'}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => deleteMeasurement(context, docId),
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
            builder: (_) => AddMeasurementScreen(patientId: currentUserId),
          );
        },
      ),
    );
  }
}