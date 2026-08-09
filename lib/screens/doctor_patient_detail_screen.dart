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
  final TextEditingController _notesController = TextEditingController();
  bool _needCaregiver = false;
  bool _isSaving = false;

  void _showAddRecommendationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Recommend for ${widget.patientName}", style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: "Doctor's Notes / Prescriptions",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text("Recommend adding a Caregiver?")),
                        Switch(
                          value: _needCaregiver,
                          activeColor: const Color(0xFF4CA1AF),
                          onChanged: (val) {
                            setDialogState(() {
                              _needCaregiver = val;
                            });
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CA1AF),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving ? null : () async {
                    String text = _notesController.text.trim();
                    if (text.isEmpty) return;

                    setDialogState(() => _isSaving = true);

                    try {
                      await FirebaseFirestore.instance.collection('recommendations').add({
                        'patientId': widget.patientId,
                        'doctorNotes': text,
                        'needCaregiver': _needCaregiver,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if (mounted) {
                        _notesController.clear();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Recommendation sent successfully!")),
                        );
                      }
                    } catch (e) {
                      debugPrint("Firestore save error: $e");
                    } finally {
                      setDialogState(() => _isSaving = false);
                    }
                  },
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Send to Patient"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        backgroundColor: const Color(0xFF4CA1AF),
      ),
      body: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50), foregroundColor: Colors.white),
          icon: const Icon(Icons.add_comment),
          label: const Text("Write Recommendation Note"),
          onPressed: _showAddRecommendationDialog,
        ),
      ),
    );
  }
}