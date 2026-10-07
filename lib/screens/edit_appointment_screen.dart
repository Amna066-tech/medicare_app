import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class EditAppointmentScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const EditAppointmentScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<EditAppointmentScreen> createState() => _EditAppointmentScreenState();
}

class _EditAppointmentScreenState extends State<EditAppointmentScreen> {
  late TextEditingController _reasonController;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(text: widget.appointmentData['reason'] ?? '');
    
    // Parse existing date
    if (widget.appointmentData['appointmentDate'] is Timestamp) {
      _selectedDate = (widget.appointmentData['appointmentDate'] as Timestamp).toDate();
    } else {
      _selectedDate = DateTime.now();
    }

    // Parse existing time
    String timeStr = widget.appointmentData['appointmentTime'] ?? widget.appointmentData['time'] ?? '';
    _selectedTime = _stringToTimeOfDay(timeStr);
  }

  TimeOfDay _stringToTimeOfDay(String timeString) {
    try {
      final format = RegExp(r'(?<hour>\d+):(?<minute>\d+)\s?(?<amPm>[aApP][mM])?');
      final match = format.firstMatch(timeString);
      if (match != null) {
        int h = int.parse(match.namedGroup('hour')!);
        int m = int.parse(match.namedGroup('minute')!);
        String? amPm = match.namedGroup('amPm');
        if (amPm != null) {
          if (amPm.toLowerCase() == 'pm' && h != 12) h += 12;
          if (amPm.toLowerCase() == 'am' && h == 12) h = 0;
        }
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (e) {
      debugPrint("Error parsing time: $e");
    }
    return TimeOfDay.now(); // Fallback
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reason for the appointment.")),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an appointment time.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DateTime scheduledDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);
      String doctorName = widget.appointmentData['doctorName'] ?? 'Doctor';

      await FirebaseFirestore.instance.collection('appointments').doc(widget.appointmentId).update({
        'appointmentDate': Timestamp.fromDate(_selectedDate),
        'appointmentTime': _selectedTime!.format(context),
        'reason': _reasonController.text.trim(),
        'notificationId': notificationId,
      });

      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': user.uid,
        'title': 'Appointment Updated: $doctorName',
        'category': 'Appointment',
        'status': 'Updated',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (scheduledDate.isBefore(DateTime.now())) {
        if (DateTime.now().difference(scheduledDate).inMinutes < 5) {
          scheduledDate = DateTime.now().add(const Duration(seconds: 5));
        }
      }

      if (scheduledDate.isAfter(DateTime.now())) {
        await NotificationService().scheduleReminderNotification(
          id: notificationId,
          itemTitle: doctorName,
          category: "Appointment",
          subtitle: "Reason: ${_reasonController.text.trim()}",
          scheduledTime: scheduledDate,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Appointment successfully updated with $doctorName!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating appointment: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String docName = widget.appointmentData['doctorName'] ?? 'Doctor';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CA1AF),
        title: Text("Edit Appointment", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Appointment Date & Time",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today, color: Color(0xFF4CA1AF)),
                    label: Text(
                      "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => _selectedTime = picked);
                    },
                    icon: const Icon(Icons.access_time, color: Color(0xFF4CA1AF)),
                    label: Text(
                      _selectedTime != null ? _selectedTime!.format(context) : "Time",
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Reason for Appointment",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "E.g. Follow up on previous checkup",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF4CA1AF), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CA1AF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitRequest,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
