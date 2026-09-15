import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import 'chat_screen.dart'; // Ensure this is imported for navigation to the chat room
import 'pay_doctor_screen.dart'; // Import your full-screen payment view

class MedicalProfessionalScreen extends StatefulWidget {
  const MedicalProfessionalScreen({super.key});

  @override
  State<MedicalProfessionalScreen> createState() => _MedicalProfessionalScreenState();
}

class _MedicalProfessionalScreenState extends State<MedicalProfessionalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  // Controllers for doctor request form
  final TextEditingController _doctorEmailController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  // Controllers for caregiver request form
  final TextEditingController _caregiverEmailController = TextEditingController();
  final TextEditingController _caregiverNameController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedRelationship = 'Relative';
  static const Color brandBlue = Color(0xFF1565C0);

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
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['name'] ?? data['displayName'] ?? 'Patient User';
      }
    } catch (_) {}
    return "Patient User";
  }

  void _submitDoctorRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    final doctorEmail = _doctorEmailController.text.trim().toLowerCase();
    final docName = _doctorNameController.text.trim();
    final specialty = _specialtyController.text.trim();
    final reason = _reasonController.text.trim();

    if (user == null || doctorEmail.isEmpty || docName.isEmpty || specialty.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String actualName = await _getPatientName(user.uid);
      final String safeEmailId = doctorEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final String requestId = "${safeEmailId}_${user.uid}";

      await FirebaseFirestore.instance.collection('access_requests').doc(requestId).set({
        'requestId': requestId,
        'patientId': user.uid,
        'patientName': actualName,
        'patientEmail': user.email?.toLowerCase(),
        'doctorEmail': doctorEmail,
        'doctorName': docName,
        'specialty': specialty,
        'symptoms': reason,
        'status': 'pending',
        'recommendations': '',
        'suggestCaregiver': false,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent to Dr. $docName ($doctorEmail)")));
        _doctorEmailController.clear();
        _doctorNameController.clear();
        _specialtyController.clear();
        _reasonController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error sending request: $e")));
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
        'relationship': _selectedRelationship,
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

  void _showAddAppointmentDialog() {
    final nameCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    DateTime? selectedDateObj;
    TimeOfDay? selectedTimeObj;

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
                    prefixIcon: const Icon(Icons.calendar_today, color: brandBlue),
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
                      selectedDateObj = pickedDate;
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
                    prefixIcon: const Icon(Icons.access_time, color: brandBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onTap: () async {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      selectedTimeObj = pickedTime;
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
              style: ElevatedButton.styleFrom(backgroundColor: brandBlue),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || nameCtrl.text.isEmpty || dateCtrl.text.isEmpty || timeCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
                  return;
                }

                if (selectedDateObj != null && selectedTimeObj != null) {
                  DateTime scheduledDate = DateTime(
                    selectedDateObj!.year,
                    selectedDateObj!.month,
                    selectedDateObj!.day,
                    selectedTimeObj!.hour,
                    selectedTimeObj!.minute,
                  );

                  if (scheduledDate.isBefore(DateTime.now())) {
                    if (DateTime.now().difference(scheduledDate).inMinutes < 5) {
                      scheduledDate = DateTime.now().add(const Duration(seconds: 5));
                    }
                  }

                  int notificationId = scheduledDate.millisecondsSinceEpoch.remainder(100000);

                  await FirebaseFirestore.instance.collection('appointments').add({
                    'patientId': user.uid,
                    'doctorName': nameCtrl.text.trim(),
                    'specialty': specialtyCtrl.text.trim(),
                    'date': dateCtrl.text.trim(),
                    'time': timeCtrl.text.trim(),
                    'appointmentDate': Timestamp.fromDate(scheduledDate),
                    'notificationId': notificationId,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (scheduledDate.isAfter(DateTime.now())) {
                    await NotificationService().scheduleReminderNotification(
                      id: notificationId,
                      itemTitle: nameCtrl.text.trim(),
                      category: "Appointment",
                      subtitle: specialtyCtrl.text.trim(),
                      scheduledTime: scheduledDate,
                    );
                  }
                }

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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: brandBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void deleteAppointment(BuildContext context, String docId, int? notificationId) async {
    try {
      if (notificationId != null) {
        await NotificationService().cancelNotification(notificationId);
      }
      await FirebaseFirestore.instance.collection('appointments').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment deleted and reminder cancelled.")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: brandBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Medical Directory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.medical_services), text: "Doctor"),
            Tab(icon: Icon(Icons.person_add), text: "Caregiver"),
            Tab(icon: Icon(Icons.calendar_month), text: "Appointments"),
          ],
        ),
      ),
      floatingActionButton: _activeTabIndex == 2
          ? FloatingActionButton(
        backgroundColor: brandBlue,
        onPressed: _showAddAppointmentDialog,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Request Doctor Connection", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField(_doctorEmailController, "Doctor's Email", Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(_doctorNameController, "Doctor's Name", Icons.person),
                const SizedBox(height: 12),
                _buildTextField(_specialtyController, "Specialty", Icons.badge),
                const SizedBox(height: 12),
                _buildTextField(_reasonController, "Reason/Symptoms", Icons.description, maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: brandBlue),
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

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('access_requests')
                      .where('patientId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: brandBlue));
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
                        final doc = requests[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;
                        final String chatId = data['requestId'] ?? docId;
                        final bool isAccepted = data['status'] == 'accepted' || data['status'] == 'Approved';
                        final bool suggestCaregiver = data['suggestCaregiver'] == true;
                        final String recommendations = data['recommendations'] ?? '';

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Dr. ${data['doctorName'] ?? 'Doctor'}",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2C3E50)),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            data['specialty'] ?? 'General Specialist',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isAccepted ? Colors.green[50] : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isAccepted ? "Approved" : "Pending",
                                        style: TextStyle(
                                          color: isAccepted ? Colors.green[700] : Colors.orange[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Doctor Email: ${data['doctorEmail'] ?? ''}",
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Reason/Symptoms: ${data['symptoms'] ?? ''}",
                                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                                ),

                                if (isAccepted && recommendations.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[5],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue[100]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.info_outline, size: 16, color: brandBlue),
                                            SizedBox(width: 6),
                                            Text("Doctor's Recommendations:", style: TextStyle(fontWeight: FontWeight.bold, color: brandBlue)),
                                          ],
                                        ),
                                        const Divider(),
                                        const SizedBox(height: 4),
                                        Text(
                                          recommendations,
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (isAccepted) ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            // Replaced the bottom sheet popup with full-screen navigation to PayDoctorScreen
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PayDoctorScreen(
                                                  requestId: doc.id,
                                                  doctorEmail: data['doctorEmail'] ?? '',
                                                  doctorName: data['doctorName'] ?? 'Doctor',
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: const Icon(Icons.payment, color: Colors.white, size: 18),
                                          label: const Text("Pay Doctor", style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: isAccepted
                                            ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                chatId: chatId,
                                                peerName: "Dr. ${data['doctorName'] ?? 'Doctor'}",
                                              ),
                                            ),
                                          );
                                        }
                                            : () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Chat will be available once the doctor accepts your request.")),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isAccepted ? brandBlue : Colors.grey,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 18),
                                        label: const Text("Chat", style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),

                                if (isAccepted && suggestCaregiver) ...[
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
                                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
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
          // Tab 2: Caregiver Request Form
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Request Caregiver Connection", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTextField(_caregiverNameController, "Caregiver Full Name", Icons.person),
                const SizedBox(height: 12),
                _buildTextField(_caregiverEmailController, "Caregiver Email", Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRelationship,
                  decoration: InputDecoration(
                    labelText: "Relationship",
                    prefixIcon: const Icon(Icons.people, color: brandBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Relative', 'Friend', 'Other'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedRelationship = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: brandBlue),
                    onPressed: _isSubmitting ? null : _submitCaregiverRequest,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Send Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(thickness: 1.2),
                const SizedBox(height: 16),
                const Text(
                  "Caregiver Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('caregiver_requests')
                      .where('patientId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: brandBlue));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text("No caregiver requests yet.", style: TextStyle(color: Colors.grey));
                    }
                    
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        bool isAccepted = data['status'] == 'accepted';
                        
                        return Card(
                          elevation: 0,
                          color: const Color(0xFFF8F9FA),
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['caregiverName'] ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['relationship'] ?? 'Relative',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isAccepted ? "accepted" : "Pending",
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
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
          // Tab 3: Appointments List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientId', isEqualTo: user?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: brandBlue));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text("No appointments scheduled yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                );
              }

              final appointments = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: appointments.length,
                itemBuilder: (context, index) {
                  final String docId = appointments[index].id;
                  final appt = appointments[index].data() as Map<String, dynamic>;
                  
                  // Handle both possible date formats saved by different screens
                  final timestamp = appt['appointmentDate'] as Timestamp?;
                  String displayDate = appt['date'] ?? '';
                  String displayTime = appt['time'] ?? appt['appointmentTime'] ?? '';
                  if (timestamp != null) {
                    final d = timestamp.toDate();
                    displayDate = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                  }

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: brandBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.medical_services, color: brandBlue),
                      ),
                      title: Text(appt['doctorName'] ?? 'Doctor', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${appt['specialty'] ?? ''}\nDate: $displayDate at $displayTime"),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => deleteAppointment(context, docId, appt['notificationId'] as int?),
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
}