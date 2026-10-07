import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class AppointmentListScreen extends StatefulWidget {
  final String? patientId;

  const AppointmentListScreen({super.key, this.patientId});

  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  // Form controllers for manual entry
  final _doctorNameController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  @override
  void dispose() {
    _doctorNameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // Safe worker to delete appointments
  void deleteAppointment(BuildContext context, String docId, int? notificationId) async {
    try {
      if (notificationId != null) {
        await NotificationService().cancelNotification(notificationId);
      }
      await FirebaseFirestore.instance.collection('appointments').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment deleted and reminder cancelled.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting request: $e")),
        );
      }
    }
  }

  // Allows doctor roles to accept or decline entries
  void _updateStatus(String docId, String newStatus) {
    FirebaseFirestore.instance.collection('appointments').doc(docId).update({
      'status': newStatus,
    });
  }

  // Triggers the standard system date selector
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Triggers the standard system clock selection panel
  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // Validates user input and uploads the custom appointment tracking data to Firestore
  Future<void> _saveManualAppointment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameText = _doctorNameController.text.trim();
    final reasonText = _reasonController.text.trim();

    if (nameText.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in the Doctor's Name, Date, and Time.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Merge date and time objects safely into a single DateTime instance
    DateTime combinedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      final String targetUid = widget.patientId ?? user.uid;
      final String formattedTime = _selectedTime!.format(context);

      // Save appointment
      int notificationId = combinedDateTime.millisecondsSinceEpoch.remainder(100000);

      await FirebaseFirestore.instance.collection('appointments').add({
        'patientId': targetUid,
        'patientName': user.displayName ?? 'Patient User',
        'doctorName': nameText,
        'doctorEmail': 'manual_reminder@medicare.com', // Placeholder tracker token
        'reason': reasonText.isEmpty ? 'General Checkup' : reasonText,
        'appointmentDate': Timestamp.fromDate(combinedDateTime),
        'status': 'accepted', // Auto-accepted since it's a private tracker/reminder
        'createdAt': FieldValue.serverTimestamp(),
        'notificationId': notificationId,
      });

      if (combinedDateTime.isBefore(DateTime.now())) {
        if (DateTime.now().difference(combinedDateTime).inMinutes < 5) {
          combinedDateTime = DateTime.now().add(const Duration(seconds: 5));
        }
      }

      if (combinedDateTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleReminderNotification(
          id: notificationId,
          itemTitle: nameText,
          category: 'Appointment',
          subtitle: 'Appointment at $formattedTime',
          scheduledTime: combinedDateTime,
        );
      }

      // ADDED: Dual-write to medical_history so it displays on your Medical History dashboard
      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': targetUid,
        'title': 'Appointment with Dr. $nameText (${reasonText.isEmpty ? "General Checkup" : reasonText})',
        'category': 'Appointment',
        'status': 'Scheduled',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear input fields safely
      _doctorNameController.clear();
      _reasonController.clear();
      _selectedDate = null;
      _selectedTime = null;

      if (mounted) {
        Navigator.pop(context); // Dismiss form dialog sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Reminder & History saved successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save entry: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Renders the sliding input window panel
  void _openAddAppointmentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Appointment Reminder",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _doctorNameController,
                      decoration: InputDecoration(
                        labelText: "Doctor's Name",
                        prefixIcon: const Icon(Icons.person_add_alt_1, color: Color(0xFF4CA1AF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: "Reason / Illness Note",
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: Color(0xFF4CA1AF)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _pickDate(context);
                              setModalState(() {}); // Force bottom sheet frame re-render
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _selectedDate == null
                                  ? "Pick Date"
                                  : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _pickTime(context);
                              setModalState(() {}); // Force bottom sheet frame re-render
                            },
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(
                              _selectedTime == null ? "Pick Time" : _selectedTime!.format(context),
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () async {
                          await _saveManualAppointment();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CA1AF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Save Appointment", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please login to view appointments."));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Appointment Reminders", style: TextStyle(color: Colors.white, fontSize: 20)),
        backgroundColor: const Color(0xFF1550A6),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .orderBy('appointmentDate', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1550A6)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No appointments scheduled.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          final targetUid = widget.patientId ?? user.uid;
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['patientId'] == targetUid || data['patientId'] == user.uid || data['doctorEmail'] == user.email;
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text("No appointments scheduled.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final docId = docs[index].id;
              final data = docs[index].data() as Map<String, dynamic>;

              final Timestamp? timestamp = data['appointmentDate'] as Timestamp?;
              final DateTime date = timestamp != null ? timestamp.toDate() : DateTime.now();
              final bool isDoctor = data['doctorEmail'] == user.email;

              String name = isDoctor ? (data['patientName'] ?? 'Patient') : (data['doctorName'] ?? 'Doctor');
              String reason = data['reason'] ?? 'No description.';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Icon
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBF3FC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month, color: Color(0xFF1550A6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    
                    // Main Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              const Icon(Icons.medical_information_outlined, color: Color(0xFF1550A6), size: 18),
                              const SizedBox(width: 8),
                              Text("Reason: $reason", style: const TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.grey, size: 18),
                              const SizedBox(width: 8),
                              Text("${date.day}/${date.month}/${date.year}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Text(TimeOfDay.fromDateTime(date).format(context), style: const TextStyle(color: Color(0xFF1550A6), fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          const SizedBox(height: 12),
                          
                          if (isDoctor && data['status'] == 'pending') ...[
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _updateStatus(docId, 'rejected'),
                                  child: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _updateStatus(docId, 'accepted'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF3FC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (data['status'] ?? 'pending').toUpperCase(),
                                style: const TextStyle(color: Color(0xFF1550A6), fontSize: 12, fontWeight: FontWeight.w500)
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Right Delete Icon
                    if (!isDoctor || data['status'] != 'pending')
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFF1550A6)),
                        onPressed: () => deleteAppointment(context, docId, data['notificationId'] as int?),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),

      // Floating Action plus button to save manual appointments/reminders
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4CA1AF),
        onPressed: _openAddAppointmentSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}