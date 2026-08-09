import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalProfessionalScreen extends StatefulWidget {
  const MedicalProfessionalScreen({super.key});

  @override
  State<MedicalProfessionalScreen> createState() => _MedicalProfessionalScreenState();
}

class _MedicalProfessionalScreenState extends State<MedicalProfessionalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  // Controllers for the doctor request form
  final TextEditingController _doctorEmailController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // Controllers for the caregiver request form
  final TextEditingController _caregiverEmailController = TextEditingController();
  final TextEditingController _caregiverNameController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _doctorEmailController.dispose();
    _doctorNameController.dispose();
    _specialtyController.dispose();
    _reasonController.dispose();
    _caregiverEmailController.dispose();
    _caregiverNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getPatientName(String uid) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return (userDoc.data() as Map<String, dynamic>)['name'] ?? 'Patient User';
    }
    return "Patient User";
  }

  void _submitDoctorRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    final docEmail = _doctorEmailController.text.trim().toLowerCase();
    final docName = _doctorNameController.text.trim();
    final specialty = _specialtyController.text.trim();
    final reason = _reasonController.text.trim();

    if (user == null || docEmail.isEmpty || docName.isEmpty || specialty.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String actualName = await _getPatientName(user.uid);
      await FirebaseFirestore.instance.collection('connection_requests').add({
        'patientId': user.uid,
        'patientName': actualName,
        'patientEmail': user.email?.toLowerCase(),
        'doctorEmail': docEmail,
        'doctorName': docName,
        'specialty': specialty,
        'reason': reason,
        'status': 'pending',
        'recommendations': '',
        'suggestCaregiver': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent to Dr. $docName")));
        _doctorEmailController.clear();
        _doctorNameController.clear();
        _specialtyController.clear();
        _reasonController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _submitCaregiverRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    final cgEmail = _caregiverEmailController.text.trim().toLowerCase();
    final cgName = _caregiverNameController.text.trim();

    if (user == null || cgEmail.isEmpty || cgName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String actualName = await _getPatientName(user.uid);
      await FirebaseFirestore.instance.collection('caregiver_requests').add({
        'patientId': user.uid,
        'patientName': actualName,
        'patientEmail': user.email?.toLowerCase(),
        'caregiverEmail': cgEmail,
        'caregiverName': cgName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent to Caregiver $cgName")));
        _caregiverEmailController.clear();
        _caregiverNameController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // DIALOG FORM TO ADD NEW APPOINTMENT
  void _showAddAppointmentDialog() {
    final nameCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Schedule Appointment", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, "Doctor's Name", Icons.person),
                const SizedBox(height: 10),
                _buildTextField(specialtyCtrl, "Specialty / Reason", Icons.medical_services),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Select Date",
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF4CA1AF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null) {
                      dateCtrl.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Select Time",
                    prefixIcon: const Icon(Icons.access_time, color: Color(0xFF4CA1AF)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onTap: () async {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      timeCtrl.text = pickedTime.format(context);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || nameCtrl.text.isEmpty || dateCtrl.text.isEmpty || timeCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
                  return;
                }

                await FirebaseFirestore.instance.collection('appointments').add({
                  'patientId': user.uid,
                  'doctorName': nameCtrl.text.trim(),
                  'specialty': specialtyCtrl.text.trim(),
                  'date': dateCtrl.text.trim(),
                  'time': timeCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment added successfully!")));
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email?.toLowerCase() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF4CA1AF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Medical Directory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: false,
          tabs: const [
            Tab(icon: Icon(Icons.medical_services), text: "Doctor"),
            Tab(icon: Icon(Icons.person_add), text: "Caregiver"),
            Tab(icon: Icon(Icons.calendar_month), text: "Appointments"),
          ],
        ),
      ),
      // SHOW FLOATING ACTION BUTTON ONLY ON APPOINTMENTS TAB (INDEX 2)
      floatingActionButton: _activeTabIndex == 2
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF4CA1AF),
        onPressed: _showAddAppointmentDialog,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Doctor Request & Recommendations Response List
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Request Doctor Connection", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField(_doctorNameController, "Doctor's Name", Icons.person),
                const SizedBox(height: 12),
                _buildTextField(_doctorEmailController, "Doctor's Email", Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(_specialtyController, "Specialty", Icons.badge),
                const SizedBox(height: 12),
                _buildTextField(_reasonController, "Reason/Symptoms", Icons.description, maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
                    onPressed: _isSubmitting ? null : _submitDoctorRequest,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Send Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(thickness: 1.2),
                const SizedBox(height: 16),
                const Text(
                  "Sent Requests & Responses",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 12),

                // STREAM BUILDER FOR DOCTOR RESPONSES
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('connection_requests')
                      .where('patientEmail', isEqualTo: userEmail)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text("No connection requests submitted yet.", style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    final requests = snapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final data = requests[index].data() as Map<String, dynamic>;
                        final isApproved = data['status'] == 'approved';
                        final bool suggestCaregiver = data['suggestCaregiver'] == true;
                        final String recommendations = data['recommendations'] ?? '';

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Dr. ${data['doctorName'] ?? 'Doctor'}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2C3E50)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isApproved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isApproved ? "Approved" : "Pending",
                                        style: TextStyle(
                                          color: isApproved ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Reason/Symptoms: ${data['reason'] ?? ''}",
                                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                                ),

                                // Doctor Recommendations Banner
                                if (isApproved && recommendations.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CA1AF).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF4CA1AF).withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Doctor's Prescribed Advice:",
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CA1AF), fontSize: 13),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          recommendations,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Caregiver Suggestion Banner
                                if (isApproved && suggestCaregiver) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      border: Border.all(color: Colors.amber.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_add_alt_1_outlined, color: Colors.amber.shade900, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            "Caregiver Suggested: Your doctor recommends continuous at-home monitoring.",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // TAB 2: Caregiver Request Form
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Request Caregiver Connection", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField(_caregiverNameController, "Caregiver's Name", Icons.person),
                const SizedBox(height: 12),
                _buildTextField(_caregiverEmailController, "Caregiver's Email", Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
                    onPressed: _isSubmitting ? null : _submitCaregiverRequest,
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Send Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // TAB 3: Appointments List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('appointments').where('patientId', isEqualTo: user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF4CA1AF)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("No appointments scheduled.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(data['doctorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${data['specialty'] ?? ''} - ${data['date']} at ${data['time']}"),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4CA1AF).withValues(alpha: 0.1),
                        child: const Icon(Icons.event, color: Color(0xFF4CA1AF)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4CA1AF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}