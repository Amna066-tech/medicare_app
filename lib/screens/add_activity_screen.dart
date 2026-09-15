import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddActivityScreen extends StatefulWidget {
  final String? patientId;

  const AddActivityScreen({super.key, this.patientId});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final TextEditingController _durationController = TextEditingController();

  String _selectedType = 'Walking';
  final List<String> _activityTypes = [
    'Walking',
    'Running',
    'Cycling',
    'Swimming',
    'Yoga',
    'Exercise',
    'Other'
  ];

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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    if (picked != null && picked != _selectedDate) {
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void saveActivity() async {
    if (_durationController.text.isEmpty || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duration and Time are required.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String formattedDate = _selectedDate.toString().substring(0, 10);
      final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

      ActivityModel newActivity = ActivityModel(
        id: '',
        userId: targetUid,
        type: _selectedType,
        value: _durationController.text,
        unit: '', // Removed notes field
        date: formattedDate,
      );

      String res = await DatabaseService().addActivity(newActivity);

      if (res == "success") {
        await FirebaseFirestore.instance.collection('medical_history').add({
          'userId': targetUid,
          'title': 'Activity: $_selectedType (${_durationController.text})',
          'category': 'Activity',
          'status': 'Scheduled',
          'timestamp': FieldValue.serverTimestamp(),
        });

        DateTime scheduledDate = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day,
            _selectedTime!.hour, _selectedTime!.minute
        );

        if (scheduledDate.isAfter(DateTime.now())) {
          int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);
          await NotificationService().scheduleReminderNotification(
            id: notificationId,
            itemTitle: _selectedType,
            category: "Activity",
            subtitle: "Duration: ${_durationController.text}",
            scheduledTime: scheduledDate,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Activity & Reminder saved successfully!"))
          );
          Navigator.pop(context); // Close dialog
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Activity",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 24),

              // Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: "Type",
                  prefixIcon: const Icon(Icons.fitness_center, color: Color(0xFF1550A6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1550A6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _activityTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Duration Input
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  hintText: "Duration (e.g. 30 mins)",
                  prefixIcon: const Icon(Icons.timer, color: Color(0xFF1550A6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1550A6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker
              TextFormField(
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: InputDecoration(
                  hintText: _selectedDate.toString().substring(0, 10),
                  hintStyle: const TextStyle(color: Color(0xFF111111)),
                  prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF1550A6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1550A6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Time Picker
              TextFormField(
                readOnly: true,
                onTap: () => _selectTime(context),
                decoration: InputDecoration(
                  hintText: _selectedTime == null ? "Time" : _selectedTime!.format(context),
                  hintStyle: TextStyle(
                    color: _selectedTime == null ? Colors.grey[600] : const Color(0xFF111111),
                  ),
                  prefixIcon: const Icon(Icons.access_time, color: Color(0xFF1550A6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1550A6), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1550A6),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : saveActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1550A6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            "Save",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}