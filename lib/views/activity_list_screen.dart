import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_activity_screen.dart';
import 'edit_activity_screen.dart';
import '../models/activity_model.dart';

class ActivityListScreen extends StatelessWidget {
  final String? patientId; // Added optional constructor variable

  const ActivityListScreen({super.key, this.patientId});

  void deleteActivity(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('activities').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Activity deleted")));
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
        title: const Text("Activity Reminders", style: TextStyle(color: Colors.white, fontSize: 20)),
        backgroundColor: const Color(0xFF1550A6),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
            context: context,
            builder: (context) => AddActivityScreen(patientId: patientId)
        ),
        backgroundColor: const Color(0xFF1550A6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: targetUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1550A6)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No activities logged yet.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String docId = doc.id;
              
              String type = data['type'] ?? 'Activity';
              String duration = data['value'] ?? 'N/A';
              String note = data['unit'] ?? 'No notes';

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
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBF3FC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_run, color: Color(0xFF1550A6), size: 28),
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
                              const Icon(Icons.timer_outlined, color: Color(0xFF1550A6), size: 18),
                              const SizedBox(width: 8),
                              Text("Duration: $duration", style: const TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes, color: Colors.grey, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text("Note: $note", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Right Edit/Delete Icon
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF1550A6)),
                          onPressed: () {
                            ActivityModel currentActivity = ActivityModel(
                              id: docId,
                              userId: data['userId'] ?? '',
                              type: type,
                              value: duration,
                              unit: note,
                              date: data['date'] ?? '',
                            );
                            showDialog(
                              context: context,
                              builder: (context) => EditActivityScreen(
                                activity: currentActivity,
                                patientId: patientId,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => deleteActivity(context, docId),
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