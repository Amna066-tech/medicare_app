import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Custom Contact", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Contact Name")),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone Number"), keyboardType: TextInputType.phone),
            TextField(controller: _roleController, decoration: const InputDecoration(labelText: "Role (e.g. Doctor, Personal Assistant)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CA1AF)),
            onPressed: () async {
              String name = _nameController.text.trim();
              String phone = _phoneController.text.trim();
              String role = _roleController.text.trim();
              String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

              if (name.isEmpty || phone.isEmpty) return;

              await FirebaseFirestore.instance.collection('emergency_contacts').add({
                'userId': uid,
                'name': name,
                'phone': phone,
                'role': role,
                'isDefault': false,
              });

              _nameController.clear();
              _phoneController.clear();
              _roleController.clear();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save Contact", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        backgroundColor: const Color(0xFF4CA1AF),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Default Emergency Helplines", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            color: Colors.red[50],
            child: const ListTile(
              leading: Icon(Icons.emergency, color: Colors.red, size: 30),
              title: Text("Rescue 1122 Hotline", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("National Emergency Medical Service Response"),
              trailing: Text("1122", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Your Custom Contacts (Doctors / Helpers)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('emergency_contacts')
                .where('userId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.contact_phone, color: Color(0xFF2C3E50)),
                      title: Text(data['name'] ?? 'Unknown Name'),
                      subtitle: Text("${data['role'] ?? 'Helper'} — ${data['phone'] ?? ''}"),
                      trailing: const Icon(Icons.phone, color: Colors.green),
                    ),
                  );
                },
              );
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4CA1AF),
        onPressed: _showAddContactDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}