import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorPatientDetailScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const DoctorPatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("$patientName's Dashboard", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Profile Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF4CA1AF).withValues(alpha: 0.1),
                      child: const Icon(Icons.person, size: 36, color: Color(0xFF4CA1AF)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Patient ID: $patientId",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Active Medications
            const Text("Active Medications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medications')
                  .where('userId', isEqualTo: patientId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyContainer("No medications recorded for this patient.");
                }

                final meds = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: meds.length,
                  itemBuilder: (context, index) {
                    final data = meds[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.medication, color: Color(0xFF4CA1AF)),
                        title: Text(data['name'] ?? 'Medication', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Dosage: ${data['dosage'] ?? 'N/A'} | Frequency: ${data['frequency'] ?? 'N/A'}"),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Section 2: Recent Vitals & Measurements
            const Text("Vitals & Measurements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('measurements')
                  .where('userId', isEqualTo: patientId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyContainer("No vitals recorded for this patient.");
                }

                final vitals = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: vitals.length,
                  itemBuilder: (context, index) {
                    final data = vitals[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.monitor_heart, color: Colors.redAccent),
                        title: Text("${data['type'] ?? 'Vital'}: ${data['value'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Date: ${data['date'] ?? 'Recent'}"),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Section 3: Medical History
            const Text("Medical History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('medical_history')
                  .where('userId', isEqualTo: patientId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyContainer("No medical history available.");
                }

                final history = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final data = history[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.history_edu, color: Colors.amber),
                        title: Text(data['condition'] ?? 'Condition', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Notes: ${data['notes'] ?? 'None'}"),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyContainer(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
    );
  }
}