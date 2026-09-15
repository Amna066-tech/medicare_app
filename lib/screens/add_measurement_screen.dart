import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/measurement_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddMeasurementScreen extends StatefulWidget {
  final String? patientId; // Added parameter

  const AddMeasurementScreen({super.key, this.patientId});

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  String _selectedCategory = "Blood Pressure";
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

  void saveMeasurement() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reminder Time is required!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      String formattedDate = _selectedDate.toString().substring(0, 10);
      String formattedTime = _selectedTime!.format(context);

      MeasurementModel newMeasurement = MeasurementModel(
        id: '',
        userId: targetUid,
        type: _selectedCategory,
        value: 'N/A', // Omitted from UI, setting default
        unit: 'N/A', // Omitted from UI, setting default
        date: formattedDate,
        time: formattedTime,
      );

      String res = await DatabaseService().addMeasurement(newMeasurement);

      if (res == "success") {
        await FirebaseFirestore.instance.collection('medical_history').add({
          'userId': targetUid,
          'title': 'Measurement Reminder: $_selectedCategory',
          'category': 'Measurement',
          'status': 'Scheduled',
          'timestamp': FieldValue.serverTimestamp(),
        });

        DateTime scheduledDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        if (scheduledDate.isAfter(DateTime.now())) {
          int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);
          await NotificationService().scheduleReminderNotification(
            id: notificationId,
            itemTitle: _selectedCategory,
            category: "Measurement",
            subtitle: "Time to check your vitals.",
            scheduledTime: scheduledDate,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Measurement Reminder saved successfully!")),
          );
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
                "Add Measurement Reminder",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),
              _buildDropdownField(
                label: "Category",
                value: _selectedCategory,
                icon: Icons.monitor_heart,
                items: ['Blood Pressure', 'Heart Rate', 'Weight', 'Blood Sugar'],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                label: "Frequency",
                value: _selectedFrequency,
                icon: Icons.repeat,
                items: ['Once a day', 'Twice a day', 'Weekly'],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFrequency = val);
                },
              ),
              const SizedBox(height: 16),
              _buildDatePickerField(context),
              const SizedBox(height: 16),
              _buildTimePickerField(context),
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
                    onPressed: _isLoading ? null : saveMeasurement,
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
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
              value: value,
              icon: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
              items: items
                  .map((item) => DropdownMenuItem(
                value: item,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(icon, color: const Color(0xFF1550A6)),
                    const SizedBox(width: 12),
                    Text(item, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: onChanged,
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
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          child: InkWell(
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
          ),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            color: const Color(0xFFF2F4F7),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Start Date",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          child: InkWell(
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
                    _selectedTime == null ? "Select time" : _selectedTime!.format(context),
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedTime == null ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                ],
              ),
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
              "Reminder Time",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }
}