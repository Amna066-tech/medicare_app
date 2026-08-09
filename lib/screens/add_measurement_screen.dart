import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/measurement_model.dart';
import '../services/database_service.dart';

class AddMeasurementScreen extends StatefulWidget {
  final String? patientId; // Added parameter

  const AddMeasurementScreen({super.key, this.patientId});

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  bool _isLoading = false;

  void saveMeasurement() async {
    if (_typeController.text.isEmpty || _valueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in the Type and Value.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      MeasurementModel newMeasurement = MeasurementModel(
        id: '',
        userId: targetUid,
        type: _typeController.text,
        value: _valueController.text,
        unit: _unitController.text,
        date: DateTime.now().toString().substring(0, 10),
        time: TimeOfDay.now().format(context),
      );

      String res = await DatabaseService().addMeasurement(newMeasurement);

      if (res == "success") {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Measurement saved successfully!")));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _typeController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Log Vitals", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24, top: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF4CA1AF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Track Your Health", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text("Log daily vitals to keep a history of progress.", style: TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("New Measurement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 16),

                      _buildInputField(
                        controller: _typeController,
                        label: "Measurement Type",
                        hint: "e.g., Blood Pressure, Weight, Sugar",
                        icon: Icons.monitor_heart_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildInputField(
                        controller: _valueController,
                        label: "Value",
                        hint: "e.g., 120/80, 70.5, 95",
                        icon: Icons.calculate_outlined,
                      ),
                      const SizedBox(height: 16),

                      _buildInputField(
                        controller: _unitController,
                        label: "Unit (Optional)",
                        hint: "e.g., mmHg, kg, mg/dL",
                        icon: Icons.straighten,
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: saveMeasurement,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CA1AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('SAVE MEASUREMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required String hint, required IconData icon}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4CA1AF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4CA1AF), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}