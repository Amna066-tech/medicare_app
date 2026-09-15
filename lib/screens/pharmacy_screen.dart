import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _medicineNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _pharmacyNameController = TextEditingController();
  final _pharmacyAddressController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isSubmitting = false;

  void _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('pharmacy_requests').add({
        'patientId': user.uid,
        'patientEmail': user.email ?? '',
        'medicineName': _medicineNameController.text.trim(),
        'quantity': _quantityController.text.trim(),
        'pharmacyName': _pharmacyNameController.text.trim(),
        'pharmacyAddress': _pharmacyAddressController.text.trim(),
        'pharmacyManagerEmail': _managerEmailController.text.trim(),
        'patientPhone': _phoneController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request sent successfully!"), backgroundColor: Colors.green),
        );
        _formKey.currentState!.reset();
        _medicineNameController.clear();
        _quantityController.clear();
        _pharmacyNameController.clear();
        _pharmacyAddressController.clear();
        _managerEmailController.clear();
        _phoneController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _quantityController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyAddressController.dispose();
    _managerEmailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'out for delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Pharmacy Delivery Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F3057),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("New Pharmacy Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3057))),
                    const SizedBox(height: 16),
                    _buildTextField(_medicineNameController, "Medicine Name", Icons.medical_services_outlined),
                    const SizedBox(height: 12),
                    _buildTextField(_quantityController, "Quantity", Icons.numbers, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildTextField(_pharmacyNameController, "Pharmacy Name", Icons.local_pharmacy_outlined),
                    const SizedBox(height: 12),
                    _buildTextField(_pharmacyAddressController, "Pharmacy Address", Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    _buildTextField(_managerEmailController, "Pharmacy Manager Email", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneController, "Your Phone Number", Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting ? null : _sendRequest,
                        child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Send Request to Pharmacy", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text("Request History & Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3057))),
            const SizedBox(height: 12),
            
            // History Section
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pharmacy_requests')
                  .where('patientId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No requests found."));
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String status = data['status'] ?? 'pending';
                    Color statusColor = _getStatusColor(status);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    data['medicineName'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Quantity: ${data['quantity'] ?? '-'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            Text("To: ${data['pharmacyName'] ?? '-'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            
                            if (status.toLowerCase() == 'out for delivery' || status.toLowerCase() == 'delivered') ...[
                              const SizedBox(height: 8),
                              const Divider(),
                              Row(
                                children: [
                                  Icon(Icons.local_shipping, size: 16, color: statusColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    status.toLowerCase() == 'delivered' ? "Order Delivered!" : "Order is on the way!",
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                            
                            if (data['totalAmount'] != null) ...[
                               const SizedBox(height: 8),
                               Text("Total Billed: Rs. ${data['totalAmount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            ]
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
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (value) => value == null || value.trim().isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0F3057)),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}