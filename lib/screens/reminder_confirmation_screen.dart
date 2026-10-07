import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class ReminderConfirmationScreen extends StatefulWidget {
  final String itemTitle;
  final String category;
  final String? subtitle;
  final String? medicationId;

  const ReminderConfirmationScreen({
    super.key,
    required this.itemTitle,
    required this.category,
    this.subtitle,
    this.medicationId,
  });

  @override
  State<ReminderConfirmationScreen> createState() => _ReminderConfirmationScreenState();
}

class _ReminderConfirmationScreenState extends State<ReminderConfirmationScreen> {
  bool _isLoading = false;
  bool _showRoleSelection = false;
  bool _isDoneAction = false;

  void _onDonePressed() {
    setState(() {
      _isDoneAction = true;
      _showRoleSelection = true;
    });
  }

  void _onDismissPressed() {
    setState(() {
      _isDoneAction = false;
      _showRoleSelection = true;
    });
  }

  void _handleBack() {
    setState(() {
      _showRoleSelection = false;
    });
  }

  Future<void> _handleFinalAction(String role) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String status = _isDoneAction ? 'Taken (by $role)' : 'Missed (by $role)';
        
        await FirebaseFirestore.instance.collection('medical_history').add({
          'userId': user.uid,
          'title': widget.itemTitle,
          'category': widget.category,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Trigger the atomic stock decrement if it's a medication and action is Done
        if (_isDoneAction && widget.category == 'Medication' && widget.medicationId != null) {
          await DatabaseService().processMedicationIntake(widget.medicationId!);
        }

        // If it was DISMISSED by Patient, fire an alert to their Caregiver
        if (!_isDoneAction && role == 'Patient') {
          // 1. Get Patient Name
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final patientName = userDoc.data()?['name'] ?? 'The patient';

          // 2. Find their Caregiver
          final caregiverReqs = await FirebaseFirestore.instance
              .collection('caregiver_requests')
              .where('patientId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'accepted')
              .get();

          if (caregiverReqs.docs.isNotEmpty) {
            bool alertedAny = false;
            for (var doc in caregiverReqs.docs) {
              final caregiverId = doc.data()['caregiverId'];
              if (caregiverId == null || caregiverId.toString().isEmpty) continue;
              
              alertedAny = true;
              // 3. Write to dismiss_alerts
              await FirebaseFirestore.instance.collection('dismiss_alerts').add({
                'caregiverId': caregiverId,
                'patientId': user.uid,
                'patientName': patientName,
                'itemTitle': widget.itemTitle,
                'category': widget.category.toUpperCase(),
                'readBy': [],
                'timestamp': FieldValue.serverTimestamp(),
              });
              debugPrint("Alert written to dismiss_alerts for caregiver: $caregiverId");
            }
            if (!alertedAny) {
              debugPrint("No valid caregiverId found in accepted requests for patient: ${user.uid}");
            }
          } else {
            debugPrint("No accepted caregiver found for patient: ${user.uid}");
          }
        }
      }
    } catch (e) {
      debugPrint("Error writing to history or alerts: $e");
    }

    if (mounted) {
      Navigator.pop(context); // close screen completely
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.alarm,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              Text(
                "Time for ${widget.category}!",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.itemTitle,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 64),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : (!_showRoleSelection)
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _onDonePressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "DONE",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _onDismissPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "DISMISS",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            const Text(
                              "Who is marking this?",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () => _handleFinalAction("Patient"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50), // Green
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Patient",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () => _handleFinalAction("Caregiver"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800), // Orange
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Caregiver",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: _handleBack,
                              child: const Text(
                                "Back",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
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
