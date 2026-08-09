import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/doctor_request_model.dart';

class AddHealthcareProfessionalScreen extends StatefulWidget {
  final String? prefilledDoctorName;
  final String? prefilledSpecialty;
  final String? prefilledEmail;
  final String? prefilledPhone;

  const AddHealthcareProfessionalScreen({
    super.key,
    this.prefilledDoctorName,
    this.prefilledSpecialty,
    this.prefilledEmail,
    this.prefilledPhone,
  });

  @override
  State<AddHealthcareProfessionalScreen> createState() => _AddHealthcareProfessionalScreenState();
}

class _AddHealthcareProfessionalScreenState extends State<AddHealthcareProfessionalScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController _patientNameController = TextEditingController();
  late TextEditingController _docNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final TextEditingController _websiteController = TextEditingController();
  late TextEditingController _specialtyController;
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _docNameController = TextEditingController(text: widget.prefilledDoctorName ?? "");
    _emailController = TextEditingController(text: widget.prefilledEmail ?? "");
    _phoneController = TextEditingController(text: widget.prefilledPhone ?? "");
    _specialtyController = TextEditingController(text: widget.prefilledSpecialty ?? "");
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _docNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _specialtyController.dispose();
    _streetController.dispose();
    _postcodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _sendDoctorRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    DoctorRequestModel request = DoctorRequestModel(
      id: '',
      patientId: currentUid,
      patientName: _patientNameController.text.trim(), // Captured first
      doctorName: _docNameController.text.trim(),
      doctorEmail: _emailController.text.trim(),
      doctorPhone: _phoneController.text.trim(),
      website: _websiteController.text.trim(),
      specialty: _specialtyController.text.trim(),
      street: _streetController.text.trim(),
      postcode: _postcodeController.text.trim(),
      city: _cityController.text.trim(),
      status: 'Pending',
      timestamp: DateTime.now().toString(),
    );

    try {
      // Sent directly to global doctor incoming collection
      await FirebaseFirestore.instance.collection('doctor_requests').add(request.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request sent successfully! Doctor can now view your form.")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F6), // Exact beige background match from image_e2ad39.png
      appBar: AppBar(
        title: const Text("Add healthcare professional", style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w500)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Doctor profile graphic illustration from image_e2ad39.png
              Center(
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.face_retouching_natural, size: 70, color: Colors.purple[300]),
                ),
              ),
              const SizedBox(height: 24),

              // Form field structure matching image_e2ad39.png
              _buildCleanField(_patientNameController, "Your Full Name", Icons.person_outline),
              const SizedBox(height: 12),
              _buildCleanField(_docNameController, "Name", Icons.badge_outlined),
              const SizedBox(height: 12),
              _buildCleanField(_emailController, "Email", Icons.email_outlined, type: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildCleanField(_phoneController, "Phone number", Icons.phone_outlined, type: TextInputType.phone),
              const SizedBox(height: 12),
              _buildCleanField(_websiteController, "Website", Icons.language),
              const SizedBox(height: 12),
              _buildCleanField(_specialtyController, "Medical specialty", Icons.health_and_safety_outlined),
              const SizedBox(height: 12),
              _buildCleanField(_streetController, "Street", Icons.location_on_outlined),
              const SizedBox(height: 12),

              // Postcode + City split horizontal row matching layout exactly
              Row(
                children: [
                  Expanded(child: _buildCleanField(_postcodeController, "Postcode", Icons.local_post_office_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCleanField(_cityController, "City", Icons.location_city)),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CA1AF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _sendDoctorRequest,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SEND REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanField(TextEditingController controller, String hint, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: (val) => val == null || val.isEmpty ? "Please enter $hint" : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF4CA1AF), width: 1.5),
        ),
      ),
    );
  }
}