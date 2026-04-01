import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _enableAlarm = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    NotificationService().requestPermission();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
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
              primary: Color(0xFF4CA1AF),
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
    if (_nameController.text.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Activity Name, Date, and Time are required.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String formattedDate = _selectedDate!.toString().substring(0, 10);
      // FIXED: Removed the unused formattedTime variable!

      ActivityModel newActivity = ActivityModel(
        id: '',
        userId: FirebaseAuth.instance.currentUser!.uid,
        type: _nameController.text,
        value: _durationController.text,
        unit: _notesController.text,
        date: formattedDate,
      );

      String res = await DatabaseService().addActivity(newActivity);

      if (res == "success") {
        if (_enableAlarm) {
          DateTime scheduledDate = DateTime(
              _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
              _selectedTime!.hour, _selectedTime!.minute
          );

          if (scheduledDate.isAfter(DateTime.now())) {
            int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);
            await NotificationService().scheduleNotification(
              id: notificationId,
              title: "Activity Reminder!",
              body: "It's time for your ${_nameController.text} (${_durationController.text}).",
              scheduledTime: scheduledDate,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_enableAlarm ? "Activity & Alarm saved!" : "Activity logged successfully!")
          ));
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
    _nameController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Log Activity", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                  Text("Healthy Habits", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text("Plan your exercises and set reminders.", style: TextStyle(fontSize: 14, color: Colors.white70)),
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
                      const Text("Activity Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 16),

                      _buildInputField(controller: _nameController, label: "Activity Name", hint: "e.g., Morning Walk, Yoga", icon: Icons.directions_run),
                      const SizedBox(height: 16),
                      _buildInputField(controller: _durationController, label: "Duration / Amount", hint: "e.g., 30 mins, 2 Liters", icon: Icons.timer_outlined),
                      const SizedBox(height: 16),
                      _buildInputField(controller: _notesController, label: "Notes", hint: "e.g., Don't forget water!", icon: Icons.notes),

                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),

                      const Text("When is this happening?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 16),

                      _buildPickerButton(
                        context: context,
                        label: _selectedDate == null ? "Tap to select Date" : _selectedDate!.toString().substring(0, 10),
                        icon: Icons.calendar_today,
                        isPlaceholder: _selectedDate == null,
                        onTap: () => _selectDate(context),
                      ),
                      const SizedBox(height: 12),
                      _buildPickerButton(
                        context: context,
                        label: _selectedTime == null ? "Tap to select Time" : _selectedTime!.format(context),
                        icon: Icons.access_time,
                        isPlaceholder: _selectedTime == null,
                        onTap: () => _selectTime(context),
                      ),

                      const SizedBox(height: 16),

                      SwitchListTile(
                        title: const Text("Set Reminder Alarm", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                        subtitle: const Text("Get a push notification at this time.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        value: _enableAlarm,
                        activeColor: const Color(0xFF4CA1AF),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          // FIXED: Replaced withOpacity to clear the blue warnings!
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                        ),
                        onChanged: (bool value) {
                          setState(() {
                            _enableAlarm = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: saveActivity,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CA1AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('SAVE ACTIVITY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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

  Widget _buildPickerButton({required BuildContext context, required String label, required IconData icon, required bool isPlaceholder, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        // FIXED: Replaced withOpacity
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
              child: Icon(icon, color: const Color(0xFF4CA1AF)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.bold,
                      color: isPlaceholder ? Colors.grey[600] : const Color(0xFF2C3E50)
                  )
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}