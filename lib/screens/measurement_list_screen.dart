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
    final bool isCaregiverView = patientId != null && patientId != FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Measurement Reminders", style: TextStyle(color: Colors.white, fontSize: 20)),
        backgroundColor: const Color(0xFF1550A6),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (context) => AddMeasurementScreen(patientId: currentUserId)),
        backgroundColor: const Color(0xFF1550A6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('measurements')
            .where('userId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1550A6)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No measurements tracked yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;

              String type = data['type'] ?? 'General';
              String frequency = data['frequency'] ?? 'Once a day';
              String startDate = data['startDate'] ?? data['date'] ?? 'N/A';
              List<dynamic> times = data['reminderTimes'] != null ? List<dynamic>.from(data['reminderTimes']) : (data['time'] != null ? [data['time']] : []);
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
                      child: const Icon(Icons.monitor_heart, color: Color(0xFF1550A6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    
                    // Main Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(height: 12),
                          
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
                        ],
                      ),
                    ),
                    
                    // Right Edit Icon
                    Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF1550A6)),
                            onPressed: () {
                              showDialog(
                                context: context, 
                                builder: (context) => AddMeasurementScreen(patientId: currentUserId, measurementId: docId, existingData: data)
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => deleteMeasurement(context, docId),
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