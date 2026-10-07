import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import 'medical_history_screen.dart';
import 'emergency_contacts_screen.dart';
import 'feedback_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewingPatientId;
  const ProfileScreen({super.key, this.viewingPatientId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;
  String? _photoUrl;
  String _name = "New User";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final targetUid = widget.viewingPatientId ?? user?.uid;
    if (targetUid == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _name = data['name'] ?? user!.displayName ?? "New User";
            _photoUrl = data['photoUrl'] ?? user!.photoURL;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _name = user!.displayName ?? "New User";
            _photoUrl = user!.photoURL;
          });
        }
      }
    } catch (e) {
      // Fallback if fetch fails
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (user == null) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      // Read image as bytes and convert to base64 to bypass Firebase Storage
      final bytes = await image.readAsBytes();
      String base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      String downloadUrl = base64Image;

      // Save URL to Firestore database
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'photoUrl': downloadUrl,
        'email': user!.email ?? '',
        'name': _name,
      }, SetOptions(merge: true));

      // Update Firebase Auth profile
      try {
        await user!.updatePhotoURL(downloadUrl);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: $e")),
        );
      }
    }
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // we don't have email for other users fetched yet, but for simplicity, use current user's email or generic if viewing other
    final email = widget.viewingPatientId != null ? "Patient Account" : (user?.email ?? "No Email");
    final String targetUid = widget.viewingPatientId ?? user?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1550A6),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: targetUid.isEmpty
          ? const Center(child: Text("Please log in to view your profile."))
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1550A6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Profile Picture with tap & camera badge
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF2C3E50),
                            backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                                ? (_photoUrl!.startsWith('data:image') 
                                    ? MemoryImage(base64Decode(_photoUrl!.split(',').last)) as ImageProvider
                                    : NetworkImage(_photoUrl!))
                                : null,
                            child: (_photoUrl == null || _photoUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2C3E50),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(email, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Account Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: _buildIcon(Icons.history_edu, Colors.blue),
                          title: const Text("Medical History", style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicalHistoryScreen(userId: targetUid),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 60),

                        ListTile(
                          leading: _buildIcon(Icons.emergency, Colors.red),
                          title: const Text("Emergency Contacts", style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EmergencyContactsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 60),

                        ListTile(
                          leading: _buildIcon(Icons.feedback_outlined, Colors.orange),
                          title: const Text("Send Feedback", style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FeedbackScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text("LOG OUT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      onPressed: () => logout(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withOpacity(0.8), shape: BoxShape.circle),
      child: Icon(icon, color: color),
    );
  }
}