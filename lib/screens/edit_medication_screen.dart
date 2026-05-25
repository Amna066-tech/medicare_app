import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication_model.dart';
import '../services/notification_service.dart';

class EditMedicationScreen extends StatefulWidget {
  final MedicationModel medication; // We receive the exact medicine they clicked!

  const EditMedicationScreen({super.key, required this.medication});

  @override
  State<EditMedicationScreen> createState() => _EditMedicationScreenState();
}

class _EditMedicationScreenState extends State<EditMedicationScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dosageController;

  late String _selectedFrequency;
  late int _doseCount;

  List<TimeOfDay?> _selectedTimes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 1. Load their existing data into the text boxes
    _nameController = TextEditingController(text: widget.medication.name);
    _dosageController = TextEditingController(text: widget.medication.dosage);
    _selectedFrequency = widget.medication.frequency;

    // 2. Set the number of clocks based on their saved frequency
    _updateDoseCount(_selectedFrequency);

    // 3. Convert their saved text times (e.g., "8:30 AM") back into real Flutter clocks!
    _selectedTimes = List.generate(_doseCount, (index) {
      if (index < widget.medication.reminderTimes.length) {
        return _stringToTimeOfDay(widget.medication.reminderTimes[index].toString());
      }
      return null;
    });
  }

  void _updateDoseCount(String frequency) {
    if (frequency == "Once a day") {
      _doseCount = 1;
    } else if (frequency == "Twice a day") {
      _doseCount = 2;
    } else if (frequency == "3 times a day") {
      _doseCount = 3;
    } else {
      _doseCount = 1;
    }
  }

  // A clever helper to translate "8:30 AM" back into a working TimeOfDay object
  TimeOfDay _stringToTimeOfDay(String timeString) {
    try {
      final format = RegExp(r'(?<hour>\d+):(?<minute>\d+)\s?(?<amPm>[aApP][mM])?');
      final match = format.firstMatch(timeString);
      if (match != null) {
        int h = int.parse(match.namedGroup('hour')!);
        int m = int.parse(match.namedGroup('minute')!);
        String? amPm = match.namedGroup('amPm');
        if (amPm != null) {
          if (amPm.toLowerCase() == 'pm' && h != 12) {
            h += 12;
          }
          if (amPm.toLowerCase() == 'am' && h == 12) {
            h = 0;
          }
        }
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (e) {
      debugPrint("Error parsing time: $e");
    }
    return TimeOfDay.now(); // Fallback
  }

  // Updates how many clocks show up if they change the frequency
  void _updateFrequency(String? newFrequency) {
    if (newFrequency == null) return;
    setState(() {
      _selectedFrequency = newFrequency;
      _updateDoseCount(newFrequency);

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
      initialTime: _selectedTimes[index] ?? TimeOfDay.now(),
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

  void updateMedication() async {
    if (_nameController.text.isEmpty || _selectedTimes.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and ALL Reminder Times are required!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> formattedTimes = _selectedTimes.map((time) => time!.format(context)).toList();

      // We update the document directly in Firestore
      await FirebaseFirestore.instance.collection('medications').doc(widget.medication.id).update({
        'name': _nameController.text,
        'dosage': _dosageController.text,
        'frequency': _selectedFrequency,
        'reminderTimes': formattedTimes,
        'lastUpdated': DateTime.now().toString(),
      });

      // Reset the alarms for the new times
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medication updated successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating: $e")));
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Edit Medication", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Update Prescription", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text("Change your dosage, frequency, or alarm times.", style: TextStyle(fontSize: 14, color: Colors.white70)),
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
                      _buildInputField(controller: _nameController, label: "Medicine Name", hint: "e.g., Panadol", icon: Icons.medical_services_outlined),
                      const SizedBox(height: 16),
                      _buildInputField(controller: _dosageController, label: "Dosage", hint: "e.g., 1 Pill, 50mg", icon: Icons.vaccines_outlined),
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
                                    color: const Color(0xFF4CA1AF).withValues(alpha: 0.05),
                                    border: Border.all(color: const Color(0xFF4CA1AF).withValues(alpha: 0.3)),
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
                          onPressed: updateMedication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CA1AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('UPDATE CHANGES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
