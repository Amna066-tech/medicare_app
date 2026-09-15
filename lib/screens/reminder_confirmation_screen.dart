import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderConfirmationScreen extends StatefulWidget {
  final String itemTitle;
  final String category;
  final String? subtitle;

  const ReminderConfirmationScreen({
    super.key,
    required this.itemTitle,
    required this.category,
    this.subtitle,
  });

  @override
  State<ReminderConfirmationScreen> createState() => _ReminderConfirmationScreenState();
}

class _ReminderConfirmationScreenState extends State<ReminderConfirmationScreen> {
  bool _isLoading = false;

  Future<void> _handleDone() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('medical_history').add({
          'userId': user.uid,
          'title': widget.itemTitle,
          'category': widget.category,
          'status': 'Taken',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error writing to history: $e");
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _handleDismiss() {
    Navigator.pop(context);
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
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _handleDone,
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
                            onPressed: _handleDismiss,
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
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
