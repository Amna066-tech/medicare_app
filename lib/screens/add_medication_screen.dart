import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  final String? patientId;

  const AddMedicationScreen({super.key, this.patientId});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  // NEW: Controller to capture disease name details
  final TextEditingController _diseaseController = TextEditingController();

  String _selectedFrequency = "Once a day";
  int _doseCount = 1;
  List<TimeOfDay?> _selectedTimes = [null];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermission();
  }

  void _updateFrequency(String? newFrequency) {
    if (newFrequency == null) return;
    setState(() {
      _selectedFrequency = newFrequency;
      if (newFrequency == "Once a day") _doseCount = 1;
      else if (newFrequency == "Twice a day") _doseCount = 2;
      else if (newFrequency == "3 times a day") _doseCount = 3;

      List<TimeOfDay?> newTimes = List.generate(_doseCount, (index) => null);
      for (int i = 0; i < _doseCount && i < _selectedTimes.length; i++) {
        newTimes[i] = _selectedTimes[i];
      }
      _selectedTimes = newTimes;
    });
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CA1AF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTimes[index] = picked;
      });
    }
  }

  void saveMedication() async {
    // UPDATED VALIDATION: Ensures disease name value isn't sent empty
    if (_nameController.text.isEmpty || _diseaseController.text.isEmpty || _selectedTimes.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, Condition/Disease and ALL Reminder Times are required!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    List<String> formattedTimes = _selectedTimes.map((time) => time!.format(context)).toList();
    final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    // Create model instance containing the disease variable
    MedicationModel newMed = MedicationModel(
      id: '',
      userId: targetUid,
      name: _nameController.text,
      dosage: _dosageController.text,
      diseaseName: _diseaseController.text, // NEW FIELD DEFINED
      frequency: _selectedFrequency,
      startDate: DateTime.now().toString().substring(0, 10),
      endDate: "Ongoing",
      reminderTimes: formattedTimes,
    );

    // If DatabaseService accepts a MedicationModel, update its addMedication(newMed) implementation to save toMap()
    String res = await DatabaseService().addMedication(newMed);

    if (res == "success") {
      try {
        for (int i = 0; i < _selectedTimes.length; i++) {
          final time = _selectedTimes[i]!;
          final now = DateTime.now();
          DateTime scheduledDate = DateTime(now.year, now.month, now.day, time.hour, time.minute);

          if (scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000) + i;

          await NotificationService().scheduleNotification(
            id: notificationId,
            title: "Time for Dose ${i + 1} of ${_nameController.text}!",
            body: "Please take ${_dosageController.text}.",
            scheduledTime: scheduledDate,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medication & Multiple Alarms saved!")));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to DB, but Alarm failed: $e")));
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res)));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _diseaseController.dispose(); // NEW DISPOSE DISMISSAL
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Add Medication", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                  Text("New Prescription", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text("Set up medication and exact alarms.", style: TextStyle(fontSize: 14, color: Colors.white70)),
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
                      _buildInputField(
                        controller: _nameController,
                        label: "Medicine Name",
                        hint: "e.g., Panadol",
                        icon: Icons.medical_services_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _dosageController,
                        label: "Dosage",
                        hint: "e.g., 1 Pill, 50mg",
                        icon: Icons.vaccines_outlined,
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Frequency",
                          prefixIcon: const Icon(Icons.update, color: Color(0xFF4CA1AF)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF4CA1AF), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        value: _selectedFrequency,
                        items: ['Once a day', 'Twice a day', '3 times a day']
                            .map((freq) => DropdownMenuItem(value: freq, child: Text(freq)))
                            .toList(),
                        onChanged: _updateFrequency,
                      ),
                      const SizedBox(height: 16),

                      // NEW DESIGN COMPONENT: Custom disease field layout positioned directly underneath frequency
                      _buildInputField(
                        controller: _diseaseController,
                        label: "Health Condition / Disease",
                        hint: "e.g., Blood Pressure, Headache",
                        icon: Icons.health_and_safety_outlined,
                      ),

                      const SizedBox(height: 28),
                      const Text("Reminder Times", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 12),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _doseCount,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: InkWell(
                              onTap: () => _selectTime(context, index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF4CA1AF).withOpacity(0.05),
                                    border: Border.all(color: const Color(0xFF4CA1AF).withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(12)
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.alarm, color: Color(0xFF4CA1AF)),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                          _selectedTimes[index] == null ? "Tap to select Time for Dose ${index + 1}" : "Dose ${index + 1}: ${_selectedTimes[index]!.format(context)}",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: _selectedTimes[index] == null ? FontWeight.normal : FontWeight.bold,
                                              color: _selectedTimes[index] == null ? Colors.grey[600] : const Color(0xFF2C3E50)
                                          )
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: saveMedication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CA1AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('SAVE MEDICATION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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