import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorPatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorPatientDetailScreen({super.key, required this.patientId, required this.patientName});

  @override
  State<DoctorPatientDetailScreen> createState() => _DoctorPatientDetailScreenState();
}

class _DoctorPatientDetailScreenState extends State<DoctorPatientDetailScreen> {
  final TextEditingController _recommendationController = TextEditingController();
  bool _caregiverRequired = false;
  bool _isSubmitting = false;

  void _submitRecommendation() async {
    if (_recommendationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write a recommendation first.")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Save the recommendation directly to Firebase
      await FirebaseFirestore.instance.collection('recommendations').add({
        'patientId': widget.patientId,
        'doctorNotes': _recommendationController.text.trim(),
        'caregiverRequired': _caregiverRequired,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recommendation sent successfully!")));
        _recommendationController.clear();
        setState(() => _caregiverRequired = false);
        Navigator.pop(context); // Close the bottom sheet
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isSubmitting = false);
  }

  void _openRecommendationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24, right: 24, top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Add Recommendation", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                    const SizedBox(height: 16),

                    // The Text Input for Doctor's Notes
                    TextField(
                      controller: _recommendationController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Enter dosage adjustments, diet plans, or health advice...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4CA1AF), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // The Caregiver Toggle Switch
                    Container(
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        title: const Text("Recommend Caregiver?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        subtitle: const Text("Flags this patient for caregiver assistance."),
                        activeColor: Colors.orange,
                        value: _caregiverRequired,
                        onChanged: (bool value) {
                          setModalState(() {
                            _caregiverRequired = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _isSubmitting ? null : _submitRecommendation,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("SEND TO PATIENT", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("${widget.patientName}'s Profile", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Text("Click the button below to send a recommendation.", style: TextStyle(color: Colors.grey, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecommendationSheet,
        backgroundColor: const Color(0xFF4CA1AF),
        icon: const Icon(Icons.medical_services, color: Colors.white),
        label: const Text("Recommend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}