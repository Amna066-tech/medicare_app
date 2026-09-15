import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final TextEditingController _stockController = TextEditingController();

  String _selectedFrequency = "Once a day";
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermission();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1550A6),
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1550A6),
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
        _selectedTime = picked;
      });
    }
  }

  void saveMedication() async {
    if (_nameController.text.isEmpty || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and Reminder Time are required!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    String formattedTime = _selectedTime!.format(context);
    final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    MedicationModel newMed = MedicationModel(
      id: '',
      userId: targetUid,
      name: _nameController.text,
      dosage: _dosageController.text.isEmpty ? "1 pill" : _dosageController.text,
      diseaseName: "N/A",
      frequency: _selectedFrequency,
      startDate: _selectedDate.toString().substring(0, 10),
      endDate: "Ongoing",
      reminderTimes: [formattedTime],
    );

    String res = await DatabaseService().addMedication(newMed);

    if (res == "success") {
      try {
        await FirebaseFirestore.instance.collection('medical_history').add({
          'userId': targetUid,
          'title': 'New Medication: ${_nameController.text} (${_dosageController.text})',
          'category': 'Medication',
          'status': 'Scheduled',
          'timestamp': FieldValue.serverTimestamp(),
        });

        final now = DateTime.now();
        DateTime scheduledDate = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute);

        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);

        await NotificationService().scheduleReminderNotification(
          id: notificationId,
          itemTitle: _nameController.text,
          category: "Medication",
          subtitle: "Please take ${_dosageController.text}.",
          scheduledTime: scheduledDate,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medication saved successfully!")));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved to DB, but Alarm/History failed: $e")));
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
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFF2F4F7),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Medication",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),
              _buildInputField(
                controller: _nameController,
                hint: "Medicine Name",
                icon: Icons.medical_services,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _dosageController,
                hint: "Dosage (e.g. 1 pill)",
                icon: Icons.science,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(),
              const SizedBox(height: 16),
              _buildDatePickerField(context),
              const SizedBox(height: 16),
              _buildTimePickerField(context),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _stockController,
                hint: "Stock (Optional)",
                icon: Icons.inventory_2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : saveMedication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1550A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: const Color(0xFF1550A6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedFrequency,
              icon: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
              items: ['Once a day', 'Twice a day', '3 times a day']
                  .map((freq) => DropdownMenuItem(
                value: freq,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.repeat, color: Color(0xFF1550A6)),
                    const SizedBox(width: 12),
                    Text(freq, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFrequency = val);
              },
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            color: const Color(0xFFF2F4F7),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Frequency",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF1550A6)),
            const SizedBox(width: 12),
            Text(
              _selectedDate.toString().substring(0, 10),
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField(BuildContext context) {
    return InkWell(
      onTap: () => _selectTime(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF1550A6)),
            const SizedBox(width: 12),
            Text(
              _selectedTime == null ? "Reminder Time" : _selectedTime!.format(context),
              style: TextStyle(
                fontSize: 16,
                color: _selectedTime == null ? Colors.grey[600] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}