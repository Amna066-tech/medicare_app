import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewPatientScreen extends StatefulWidget {
  final String requestId;
  final String patientName;
  final String symptoms;
  final Map<String, dynamic> requestData;

  const ReviewPatientScreen({
    super.key,
    required this.requestId,
    required this.patientName,
    required this.symptoms,
    required this.requestData,
  });

  @override
  State<ReviewPatientScreen> createState() => _ReviewPatientScreenState();
}

class _ReviewPatientScreenState extends State<ReviewPatientScreen> {
  late TextEditingController _medicationController;
  late TextEditingController _systolicController;
  late TextEditingController _diastolicController;
  late TextEditingController _measurementPlanController;
  late TextEditingController _activityDietController;
  String _managementSuggestion = 'Patient';
  bool _needsCaregiver = false;

  bool _isSaving = false;
  static const Color brandBlue = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _medicationController = TextEditingController(text: widget.requestData['medicationRec'] ?? '');
    _systolicController = TextEditingController(text: widget.requestData['targetSystolic'] ?? '');
    _diastolicController = TextEditingController(text: widget.requestData['targetDiastolic'] ?? '');
    _measurementPlanController = TextEditingController(text: widget.requestData['measurementPlan'] ?? '');
    _activityDietController = TextEditingController(text: widget.requestData['activityDietRec'] ?? '');
    _managementSuggestion = widget.requestData['managementSuggestion'] ?? 'Patient';
    _needsCaregiver = widget.requestData['suggestCaregiver'] == true;
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _measurementPlanController.dispose();
    _activityDietController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: RichText(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: brandBlue,
          ),
          children: isRequired
              ? [const TextSpan(text: ' *', style: TextStyle(color: brandBlue))]
              : [],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 3, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black54),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: brandBlue),
        ),
      ),
    );
  }

  Future<void> _submitRecommendations() async {
    setState(() => _isSaving = true);
    
    String combinedRecs = "";
    if (_medicationController.text.isNotEmpty) {
      combinedRecs += "Medication: ${_medicationController.text}\n";
    }
    if (_systolicController.text.isNotEmpty && _diastolicController.text.isNotEmpty) {
      combinedRecs += "Target BP: ${_systolicController.text}/${_diastolicController.text}\n";
    }
    if (_measurementPlanController.text.isNotEmpty) {
      combinedRecs += "Measurement Plan: ${_measurementPlanController.text}\n";
    }
    if (_activityDietController.text.isNotEmpty) {
      combinedRecs += "Activity/Diet: ${_activityDietController.text}\n";
    }
    if (_managementSuggestion.isNotEmpty) {
      combinedRecs += "Manager: $_managementSuggestion\n";
    }

    try {
      await FirebaseFirestore.instance
          .collection('access_requests')
          .doc(widget.requestId)
          .update({
        'status': 'accepted',
        'recommendations': combinedRecs.trim(),
        'medicationRec': _medicationController.text.trim(),
        'targetSystolic': _systolicController.text.trim(),
        'targetDiastolic': _diastolicController.text.trim(),
        'measurementPlan': _measurementPlanController.text.trim(),
        'activityDietRec': _activityDietController.text.trim(),
        'managementSuggestion': _managementSuggestion,
        'suggestCaregiver': _needsCaregiver,
      });

      // ADDED: Dual-write to medical_history so it displays on the Medical History dashboard
      await FirebaseFirestore.instance.collection('medical_history').add({
        'userId': widget.requestData['patientId'],
        'title': 'Doctor Recommendations Added',
        'category': 'Doctor',
        'status': 'Added',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recommendations submitted successfully!")),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving details: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: brandBlue,
        title: const Text('Review Patient', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: RichText(
                text: TextSpan(
                  text: '${widget.patientName}: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                  children: [
                    TextSpan(
                      text: widget.symptoms,
                      style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Provide Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const Divider(color: Colors.black26, height: 24),

            _buildSectionTitle('Medication Recommendation'),
            _buildTextField(_medicationController, 'e.g., Insulin 10 units before breakfast'),

            _buildSectionTitle('Target Blood Pressure', isRequired: true),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField(
                        _systolicController, 
                        '120', 
                        maxLines: 1, 
                        keyboardType: TextInputType.number
                      ),
                      const SizedBox(height: 4),
                      const Text('Systolic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('|', style: TextStyle(fontSize: 24, color: Colors.black45)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField(
                        _diastolicController, 
                        '80', 
                        maxLines: 1, 
                        keyboardType: TextInputType.number
                      ),
                      const SizedBox(height: 4),
                      const Text('Diastolic', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),

            _buildSectionTitle('Measurement Plan'),
            _buildTextField(_measurementPlanController, 'e.g., Check BP twice daily'),

            _buildSectionTitle('Activity/Diet Recommendation'),
            _buildTextField(_activityDietController, 'e.g., 30 mins morning walk, low salt'),

            const SizedBox(height: 24),
            const Text(
              'System Management Suggestion',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            const Text(
              'Who should manage the app reminders?',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _managementSuggestion,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  items: ['Patient', 'Caregiver', 'Both'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        _managementSuggestion = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Patient needs a physical caregiver at home?',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                Checkbox(
                  value: _needsCaregiver,
                  activeColor: brandBlue,
                  onChanged: (val) {
                    setState(() {
                      _needsCaregiver = val ?? false;
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _submitRecommendations,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SUBMIT RECOMMENDATIONS',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
