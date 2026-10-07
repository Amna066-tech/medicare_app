import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class PayDoctorScreen extends StatefulWidget {
  final String requestId;
  final String doctorEmail;
  final String doctorName;

  const PayDoctorScreen({
    super.key,
    required this.requestId,
    required this.doctorEmail,
    required this.doctorName,
  });

  @override
  State<PayDoctorScreen> createState() => _PayDoctorScreenState();
}

class _PayDoctorScreenState extends State<PayDoctorScreen> {
  static const Color brandBlue = Color(0xFF1565C0);

  String? selectedRequestId;
  String? selectedDoctorName;
  String? selectedDoctorEmail;
  String selectedMethod = 'EasyPaisa';

  final TextEditingController _doctorNumberController = TextEditingController(text: '0300-1234567');
  final TextEditingController _transactionController = TextEditingController();

  XFile? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.requestId.isNotEmpty && widget.doctorEmail.isNotEmpty) {
      selectedRequestId = widget.requestId;
      selectedDoctorName = widget.doctorName;
      selectedDoctorEmail = widget.doctorEmail;
    }
  }

  @override
  void dispose() {
    _doctorNumberController.dispose();
    _transactionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
      await _uploadToCloudinary();
    }
  }

  Future<void> _uploadToCloudinary() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);

    try {
      try {
        const cloudName = 'bliywgyk';
        const uploadPreset = 'medicare_preset';

        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        var request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset;
        
        if (kIsWeb) {
          var bytes = await _selectedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'receipt.jpg'));
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));
        }

        var response = await request.send().timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonData = json.decode(responseData);
          setState(() {
            _uploadedImageUrl = jsonData['secure_url'];
            _isUploading = false;
          });
        } else {
          final responseData = await response.stream.bytesToString();
          throw Exception("Cloudinary Error: $responseData");
        }
      } catch (e) {
        debugPrint("Cloudinary failed, trying Firebase: $e");
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref('receipts/receipt_$timestamp.jpg');
        if (kIsWeb) {
          await ref.putData(await _selectedImage!.readAsBytes()).timeout(const Duration(seconds: 15));
        } else {
          await ref.putFile(File(_selectedImage!.path)).timeout(const Duration(seconds: 15));
        }
        final downloadUrl = await ref.getDownloadURL();
        setState(() {
          _uploadedImageUrl = downloadUrl;
          _isUploading = false;
        });
      }

      if (_uploadedImageUrl != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Receipt uploaded successfully!")),
          );
        }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e")),
        );
      }
    }
  }

  void _submitPayment() async {
    if (selectedRequestId == null || selectedRequestId!.isEmpty || selectedDoctorEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a doctor first")),
      );
      return;
    }

    if (_transactionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the transaction ID")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final transactionId = _transactionController.text.trim();
      final receiptUrl = _uploadedImageUrl ?? '';
      final doctorPhone = _doctorNumberController.text.trim();
      final formattedDoctorEmail = selectedDoctorEmail!.toLowerCase().trim();

      // 1. Add record to global payments collection tied to doctor's email
      await FirebaseFirestore.instance.collection('payments').add({
        'requestId': selectedRequestId,
        'doctorEmail': formattedDoctorEmail,
        'doctorName': selectedDoctorName ?? 'Doctor',
        'doctorPhone': doctorPhone,
        'patientId': user?.uid ?? '',
        'patientEmail': user?.email ?? '',
        'patientName': user?.displayName ?? 'Patient',
        'transactionId': transactionId,
        'paymentMethod': selectedMethod,
        'receiptUrl': receiptUrl,
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the specific access_request document using the doctor's email so their dashboard catches it
      await FirebaseFirestore.instance.collection('access_requests').doc(selectedRequestId).update({
        'doctorEmail': formattedDoctorEmail,
        'paymentStatus': 'Pending',
        'transactionId': transactionId,
        'paymentMethod': selectedMethod,
        'receiptUrl': receiptUrl,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment request sent to doctor's dashboard successfully!")),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting payment: $e")),
        );
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
        title: const Text("Pay Doctor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Make a Payment", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 4),
            const Text("Select your doctor to send the payment verification request.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),

            const Text("Select Doctor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            // Stream connected/accepted requests to get doctor name and email
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('access_requests')
                  .where('patientId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text("No connected doctors available.", style: TextStyle(color: Colors.grey)),
                  );
                }

                final acceptedDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? '';
                  return status == 'accepted' || status == 'Approved';
                }).toList();

                if (acceptedDocs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text("No doctors have accepted your connection request yet.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRequestId,
                      hint: const Text("Choose Doctor"),
                      isExpanded: true,
                      items: acceptedDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final docName = data['doctorName'] ?? 'Doctor';
                        final docEmail = data['doctorEmail'] ?? '';
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text("Dr. $docName ($docEmail)", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final selectedDoc = acceptedDocs.firstWhere((d) => d.id == val);
                          final data = selectedDoc.data() as Map<String, dynamic>;
                          setState(() {
                            selectedRequestId = val;
                            selectedDoctorName = data['doctorName'];
                            selectedDoctorEmail = data['doctorEmail'];
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),

            if (selectedRequestId != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Payment info for Dr. $selectedDoctorName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("Email: $selectedDoctorEmail", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    const Text("Payment Method", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => selectedMethod = 'EasyPaisa'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selectedMethod == 'EasyPaisa' ? Colors.green.shade50 : Colors.white,
                              side: BorderSide(color: selectedMethod == 'EasyPaisa' ? Colors.green : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 18),
                            label: const Text("EasyPaisa", style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() => selectedMethod = 'JazzCash'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selectedMethod == 'JazzCash' ? Colors.orange.shade50 : Colors.white,
                              side: BorderSide(color: selectedMethod == 'JazzCash' ? Colors.orange : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 18),
                            label: const Text("JazzCash", style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _doctorNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_android, color: Colors.green),
                        labelText: "$selectedMethod Account Number",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text("Submission Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              TextField(
                controller: _transactionController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.tag, color: Colors.grey),
                  labelText: "Transaction ID",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              const Text("Payment Screenshot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isUploading
                      ? const Center(child: CircularProgressIndicator(color: brandBlue))
                      : _selectedImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                        : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Select Screenshot", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
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
                  onPressed: _isSubmitting ? null : _submitPayment,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SUBMIT PAYMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}