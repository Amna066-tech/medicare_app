import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_navigation_screen.dart'; // <-- CHANGED THIS IMPORT

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // NEW: Variables for DOB and Gender
  DateTime? _selectedDate;
  String? _selectedGender;

  bool _isLoading = false;

  // NEW: Beautiful Date Picker for Date of Birth
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // Default to year 2000 for DOB
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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

  void signup() async {
    // UPDATED: Now checks if DOB and Gender are filled out too!
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _selectedDate == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields to create your profile.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the user in Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Save ALL details to Firestore so the Profile Screen works!
      if (userCredential.user != null) {
        String formattedDOB = _selectedDate!.toString().substring(0, 10); // YYYY-MM-DD

        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': DateTime.now().toString(),
          'dob': formattedDOB,          // Saved perfectly for the profile!
          'gender': _selectedGender,    // Saved perfectly for the profile!
        });

        if (mounted) {
          // <-- CHANGED THE ROUTE HERE
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Sign up failed")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CA1AF), Color(0xFF2C3E50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2), // <-- FIXED BLUE WARNING
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Create Account",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  ),
                  const Text(
                    "Start your health journey today",
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),

                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildInputField(
                            controller: _nameController,
                            label: "Full Name",
                            icon: Icons.badge_outlined,
                            isPassword: false,
                          ),
                          const SizedBox(height: 16),

                          _buildInputField(
                            controller: _emailController,
                            label: "Email Address",
                            icon: Icons.email_outlined,
                            isPassword: false,
                          ),
                          const SizedBox(height: 16),

                          _buildInputField(
                            controller: _passwordController,
                            label: "Password",
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 16),

                          // NEW: Date of Birth Field
                          InkWell(
                            onTap: () => _selectDate(context),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Date of Birth",
                                prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF4CA1AF)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              child: Text(
                                _selectedDate == null ? "Tap to select DOB" : _selectedDate!.toString().substring(0, 10),
                                style: TextStyle(
                                  color: _selectedDate == null ? Colors.grey[600] : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // NEW: Gender Dropdown
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: "Gender",
                              prefixIcon: const Icon(Icons.wc_outlined, color: Color(0xFF4CA1AF)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF4CA1AF), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            value: _selectedGender,
                            items: ['Male', 'Female', 'Other', 'Prefer not to say']
                                .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                          ),

                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CA1AF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              onPressed: signup,
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("SIGN UP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? ", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, required bool isPassword}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isPassword ? TextInputType.text : (label.contains("Email") ? TextInputType.emailAddress : TextInputType.name),
      decoration: InputDecoration(
        labelText: label,
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
}