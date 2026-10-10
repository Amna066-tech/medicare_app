import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'main_navigation_screen.dart';
import 'caregiver_dashboard_screen.dart';
import 'doctor_verification_screen.dart';
import 'nurse_verification_screen.dart';
import 'pharmacist_verification_screen.dart';
import 'pharmacy_dashboard_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'Patient';
  String? _selectedGender;
  String? _caregiverType;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Controllers for Doctor
  final _specialityController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  // Controllers for Nurse
  final _nursingLicenseController = TextEditingController();

  // Controllers for Pharmacist
  final _pharmacyNameController = TextEditingController();
  final _pharmacyAddressController = TextEditingController();
  final _drugLicenseController = TextEditingController();

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || dob.isEmpty || password.isEmpty || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all shared fields")));
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 8 characters long"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Role-specific validation
    if (_selectedRole == 'Doctor') {
      if (_specialityController.text.isEmpty || _licenseNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in Doctor fields")));
        return;
      }
    } else if (_selectedRole == 'Caregiver') {
      if (_caregiverType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Caregiver Type")));
        return;
      }
      if (_caregiverType == 'Nurse' && _nursingLicenseController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in Nursing License Number")));
        return;
      }
    } else if (_selectedRole == 'Pharmacist') {
      if (_pharmacyNameController.text.isEmpty || _pharmacyAddressController.text.isEmpty || 
          _drugLicenseController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all Pharmacist fields")));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String verificationStatus = 'NOT_SUBMITTED';
      if (_selectedRole == 'Patient' || (_selectedRole == 'Caregiver' && _caregiverType == 'Friend/Relative')) {
        verificationStatus = 'APPROVED';
      }

      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'dateOfBirth': dob,
        'role': _selectedRole,
        'gender': _selectedGender,
        'verificationStatus': verificationStatus,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == 'Doctor') {
        userData['speciality'] = _specialityController.text.trim();
        userData['licenseNumber'] = _licenseNumberController.text.trim();
      } else if (_selectedRole == 'Caregiver') {
        userData['caregiverType'] = _caregiverType;
        if (_caregiverType == 'Nurse') {
          userData['nursingLicenseNumber'] = _nursingLicenseController.text.trim();
        }
      } else if (_selectedRole == 'Pharmacist') {
        userData['pharmacyName'] = _pharmacyNameController.text.trim();
        userData['pharmacyAddress'] = _pharmacyAddressController.text.trim();
        userData['drugLicenseNumber'] = _drugLicenseController.text.trim();
      }

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set(userData);

      UserModel newUser = UserModel.fromMap(userData, userCredential.user!.uid);

      if (mounted) {
        if (_selectedRole == 'Patient') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()), (route) => false);
        } else if (_selectedRole == 'Caregiver' && _caregiverType == 'Friend/Relative') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const CaregiverDashboardScreen()), (route) => false);
        } else if (_selectedRole == 'Doctor') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => DoctorVerificationScreen(user: newUser)), (route) => false);
        } else if (_selectedRole == 'Caregiver' && _caregiverType == 'Nurse') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => NurseVerificationScreen(user: newUser)), (route) => false);
        } else if (_selectedRole == 'Pharmacist') {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => PharmacistVerificationScreen(user: newUser)), (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Sign up failed"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _specialityController.dispose();
    _licenseNumberController.dispose();
    _nursingLicenseController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyAddressController.dispose();
    _drugLicenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1550A6);
    const Color inputFillColor = Color(0xFFF2F4F7);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Header
            const SizedBox(height: 32),
            const Text(
              "Create Account",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Please fill the details to continue",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),

            // Form Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(24.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Role Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: _inputDecoration("Account Type (Role)", Icons.assignment_ind, primaryBlue, inputFillColor),
                        items: ['Patient', 'Caregiver', 'Doctor', 'Pharmacist'].map((role) {
                          return DropdownMenuItem(value: role, child: Text(role, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedRole = val!;
                            if (_selectedRole != 'Caregiver') {
                              _caregiverType = null;
                            }
                          });
                        },
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Caregiver Type (Only if Caregiver)
                      if (_selectedRole == 'Caregiver') ...[
                        DropdownButtonFormField<String>(
                          value: _caregiverType,
                          decoration: _inputDecoration("Select Caregiver Type", Icons.people_outline, primaryBlue, inputFillColor),
                          items: ['Nurse', 'Friend/Relative'].map((type) {
                            return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))));
                          }).toList(),
                          onChanged: (val) => setState(() => _caregiverType = val),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Full Name
                      TextField(
                        controller: _nameController,
                        decoration: _inputDecoration("Full Name", Icons.person, primaryBlue, inputFillColor),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration("Email Address", Icons.email, primaryBlue, inputFillColor),
                      ),
                      const SizedBox(height: 16),

                      // DOB
                      TextField(
                        controller: _dobController,
                        decoration: _inputDecoration("DOB (YYYY-MM-DD)", Icons.calendar_today_outlined, primaryBlue, inputFillColor),
                      ),
                      const SizedBox(height: 16),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: _inputDecoration("Select Gender", Icons.wc, primaryBlue, inputFillColor),
                        items: ['Male', 'Female', 'Other'].map((gender) {
                          return DropdownMenuItem(value: gender, child: Text(gender, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedGender = val),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Role-specific fields
                      if (_selectedRole == 'Doctor') ...[
                        TextField(
                          controller: _specialityController,
                          decoration: _inputDecoration("Speciality", Icons.medical_services, primaryBlue, inputFillColor),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _licenseNumberController,
                          decoration: _inputDecoration("License Number", Icons.badge, primaryBlue, inputFillColor),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedRole == 'Pharmacist') ...[
                        TextField(
                          controller: _pharmacyNameController,
                          decoration: _inputDecoration("Pharmacy Name", Icons.add_business, primaryBlue, inputFillColor),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _pharmacyAddressController,
                          decoration: _inputDecoration("Pharmacy Address", Icons.map_outlined, primaryBlue, inputFillColor),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _drugLicenseController,
                          decoration: _inputDecoration("Drug License Number", Icons.description, primaryBlue, inputFillColor),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_selectedRole == 'Caregiver' && _caregiverType == 'Nurse') ...[
                        TextField(
                          controller: _nursingLicenseController,
                          decoration: _inputDecoration("Nursing License Number", Icons.badge, primaryBlue, inputFillColor),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.lock_outline, color: primaryBlue),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: primaryBlue),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: inputFillColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sign Up Button
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("SIGN UP", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Go back to login
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Already have an account? Login", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                      )
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

  InputDecoration _inputDecoration(String hint, IconData icon, Color iconColor, Color fillColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: iconColor),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }
}