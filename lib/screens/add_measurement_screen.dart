import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/measurement_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddMeasurementScreen extends StatefulWidget {
  final String? patientId;
  final String? measurementId;
  final Map<String, dynamic>? existingData;

  const AddMeasurementScreen({super.key, this.patientId, this.measurementId, this.existingData});

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  String _selectedCategory = "Blood Pressure";
  String _selectedFrequency = "Once a day";
  int _timesPerDay = 1;
  DateTime _startDate = DateTime.now();
  List<TimeOfDay?> _selectedTimes = [null];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermission();
    if (widget.existingData != null) {
      _selectedCategory = widget.existingData!['type'] ?? "Blood Pressure";
      _selectedFrequency = widget.existingData!['frequency'] ?? "Once a day";
      
      if (widget.existingData!['startDate'] != null) {
        try {
          _startDate = DateTime.parse(widget.existingData!['startDate']);
        } catch (e) {
          _startDate = DateTime.now();
        }
      }

      List<dynamic> times = widget.existingData!['reminderTimes'] ?? [];
      if (times.isNotEmpty) {
        _selectedTimes = times.map((t) {
          try {
            final parts = t.toString().split(RegExp(r'[: ]'));
            int hour = int.parse(parts[0]);
            int minute = int.parse(parts[1]);
            if (t.toString().toLowerCase().contains('pm') && hour < 12) hour += 12;
            if (t.toString().toLowerCase().contains('am') && hour == 12) hour = 0;
            return TimeOfDay(hour: hour, minute: minute);
          } catch (e) {
            return null;
          }
        }).toList();
        _timesPerDay = _selectedTimes.length;
      }
    }
  }

  void _onFrequencyChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedFrequency = val;
      if (val == "Once a day") {
        _selectedTimes = [null];
        _timesPerDay = 1;
      } else if (val == "Twice a day") {
        _selectedTimes = [null, null];
        _timesPerDay = 2;
      } else if (val == "3 times a day") {
        _selectedTimes = [null, null, null];
        _timesPerDay = 3;
      } else if (val == "Everyday") {
        _selectedTimes = List.generate(_timesPerDay, (index) => null);
      }
    });
  }

  void _onTimesPerDayChanged(int? val) {
    if (val == null) return;
    setState(() {
      _timesPerDay = val;
      _selectedTimes = List.generate(_timesPerDay, (index) => null);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
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
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
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
        _selectedTimes[index] = picked;
      });
    }
  }

  void saveMeasurement() async {
    if (_selectedTimes.any((t) => t == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All reminder times must be set!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String targetUid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      String formattedDate = _startDate.toString().substring(0, 10);
      List<String> formattedTimes = _selectedTimes.map((t) => t!.format(context)).toList();

      MeasurementModel newMeasurement = MeasurementModel(
        id: widget.measurementId ?? '',
        userId: targetUid,
        type: _selectedCategory,
        value: 'N/A', // Omitted from UI, setting default
        unit: 'N/A', // Omitted from UI, setting default
        frequency: _selectedFrequency,
        startDate: formattedDate,
        reminderTimes: formattedTimes,
      );

      String res = "";
      if (widget.measurementId == null) {
        res = await DatabaseService().addMeasurement(newMeasurement);
      } else {
        await FirebaseFirestore.instance.collection('measurements').doc(widget.measurementId).update(newMeasurement.toMap());
        res = "success";
      }

      if (res != "Some error occurred" && res.isNotEmpty) {
        if (widget.measurementId == null) {
          await FirebaseFirestore.instance.collection('medical_history').add({
            'userId': targetUid,
            'title': 'Measurement Reminder: $_selectedCategory',
            'category': 'Measurement',
            'status': 'Scheduled',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        bool repeatDaily = _selectedFrequency == "Everyday" || _selectedFrequency.contains("day");

        for (var time in _selectedTimes) {
          DateTime scheduledDate = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            time!.hour,
            time.minute,
          );

          if (scheduledDate.isAfter(DateTime.now()) || repeatDaily) {
            if (scheduledDate.isBefore(DateTime.now()) && repeatDaily) {
               scheduledDate = scheduledDate.add(const Duration(days: 1));
            }
            int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);
            await NotificationService().scheduleReminderNotification(
              id: notificationId,
              itemTitle: _selectedCategory,
              category: "Measurement",
              subtitle: "Time to check your vitals.",
              scheduledTime: scheduledDate,
              repeatDaily: repeatDaily,
            );
          }
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
              Text(
                widget.existingData != null ? "Edit Measurement" : "Add Measurement",
                style: const TextStyle(
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
              _buildFrequencyDropdown(),
              if (_selectedFrequency == 'Everyday') ...[
                const SizedBox(height: 16),
                _buildTimesPerDayDropdown(),
              ],
              const SizedBox(height: 16),
              _buildDatePickerField(context),
              const SizedBox(height: 16),
              ...List.generate(_selectedTimes.length, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildTimePickerField(context, index),
              )),
              const SizedBox(height: 8),
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

  Widget _buildFrequencyDropdown() {
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
              items: ['Once a day', 'Twice a day', '3 times a day', 'Everyday']
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
              onChanged: _onFrequencyChanged,
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
              "Frequency Type",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimesPerDayDropdown() {
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
            child: DropdownButton<int>(
              isExpanded: true,
              value: _timesPerDay,
              icon: const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey),
              ),
              items: [1, 2, 3]
                  .map((val) => DropdownMenuItem(
                value: val,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, color: Color(0xFF1550A6)),
                    const SizedBox(width: 12),
                    Text("$val time${val > 1 ? 's' : ''} a day", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ))
                  .toList(),
              onChanged: _onTimesPerDayChanged,
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
              "Times per day",
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
                    _startDate.toString().substring(0, 10),
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

  Widget _buildTimePickerField(BuildContext context, int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          child: InkWell(
            onTap: () => _selectTime(context, index),
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
                    _selectedTimes.length > index && _selectedTimes[index] != null 
                        ? _selectedTimes[index]!.format(context) 
                        : "Select time",
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedTimes.length > index && _selectedTimes[index] != null ? Colors.black87 : Colors.grey[600],
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
              "Time ${index + 1}",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }
}