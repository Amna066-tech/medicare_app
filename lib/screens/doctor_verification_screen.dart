import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

class DoctorVerificationScreen extends StatefulWidget {
  final UserModel user;

  const DoctorVerificationScreen({super.key, required this.user});

  @override
  State<DoctorVerificationScreen> createState() => _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState extends State<DoctorVerificationScreen> {
  XFile? _imageFile;
  bool _isUploading = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.user.verificationStatus;
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _submitForApproval() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a medical license certificate image.")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String uid = widget.user.uid;
      String downloadUrl;
      try {
        const cloudName = 'bliywgyk';
        const uploadPreset = 'medicare_preset';
        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        var request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset;
          
        if (kIsWeb) {
          var bytes = await _imageFile!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'certificate.jpg'));
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', _imageFile!.path));
        }

        var response = await request.send().timeout(const Duration(seconds: 15));
        final responseData = await response.stream.bytesToString();
        if (response.statusCode != 200) {
          throw Exception("Cloudinary Error: $responseData");
        }
        final jsonData = json.decode(responseData);
        downloadUrl = jsonData['secure_url'];
      } catch (e) {
        debugPrint("Cloudinary failed, trying Firebase: $e");
        final ref = FirebaseStorage.instance.ref('certificates/$uid.jpg');
        if (kIsWeb) {
          await ref.putData(await _imageFile!.readAsBytes()).timeout(const Duration(seconds: 15));
        } else {
          await ref.putFile(File(_imageFile!.path)).timeout(const Duration(seconds: 15));
        }
        downloadUrl = await ref.getDownloadURL();
      }

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'verificationStatus': 'PENDING',
        'certificateImageUrl': downloadUrl,
      });

      setState(() {
        _currentStatus = 'PENDING';
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Submitted successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPending = _currentStatus == 'PENDING';
    bool isRejected = _currentStatus == 'REJECTED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Verification'),
        backgroundColor: const Color(0xFF4CA1AF),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRejected ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isRejected ? Colors.red : Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(
                    isRejected ? Icons.cancel : Icons.security,
                    color: isRejected ? Colors.red : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Verification Status: $_currentStatus",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isRejected ? Colors.red : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRejected
                              ? "Your verification was rejected. Please upload correct documents and resubmit."
                              : "Admin will review your credentials and medical license certificate copy.",
                          style: TextStyle(
                            color: isRejected ? Colors.red.shade700 : Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Read-only fields
            const Text("Your Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildReadOnlyField("Speciality", widget.user.speciality ?? "N/A"),
            const SizedBox(height: 12),
            _buildReadOnlyField("License Number", widget.user.licenseNumber ?? "N/A"),
            const SizedBox(height: 24),

            const Text("Medical License Certificate Copy", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: (isPending && widget.user.certificateImageUrl != null && widget.user.certificateImageUrl!.isNotEmpty) ? null : _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb 
                            ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                            : Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                      )
                    : (widget.user.certificateImageUrl != null && widget.user.certificateImageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(widget.user.certificateImageUrl!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey.shade500),
                              const SizedBox(height: 8),
                              Text("Tap to upload certificate", style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 32),
            if (!isPending || widget.user.certificateImageUrl == null || widget.user.certificateImageUrl!.isEmpty)
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isUploading ? null : _submitForApproval,
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit for Approval", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
