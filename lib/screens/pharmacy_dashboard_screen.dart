import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'feedback_screen.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  const PharmacyDashboardScreen({super.key});

  @override
  State<PharmacyDashboardScreen> createState() => _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  void _showAcceptDialog(String docId) {
    final costController = TextEditingController();
    final feeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accept Order & Set Price"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Medicine Cost (Rs.)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Delivery Fee (Rs.)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              double cost = double.tryParse(costController.text) ?? 0;
              double fee = double.tryParse(feeController.text) ?? 0;
              double total = cost + fee;

              await FirebaseFirestore.instance.collection('pharmacy_requests').doc(docId).update({
                'status': 'approved',
                'medicineCost': cost,
                'deliveryFee': fee,
                'totalAmount': total,
                'acceptedByPharmacistId': currentUser?.uid,
              });

              if (mounted) Navigator.pop(context);
            },
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }

  void _advanceStatus(String docId, String currentStatus) async {
    String nextStatus = 'approved';
    if (currentStatus == 'approved') nextStatus = 'out for delivery';
    else if (currentStatus == 'out for delivery') nextStatus = 'delivered';
    else return;

    await FirebaseFirestore.instance.collection('pharmacy_requests').doc(docId).update({
      'status': nextStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Pharmacist Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F3057),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined, color: Colors.white),
            tooltip: 'Send Feedback',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
            },
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(icon: Icon(Icons.move_to_inbox), text: "Incoming"),
            Tab(icon: Icon(Icons.check_circle), text: "Approved"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncomingTab(),
          _buildAcceptedTab(),
        ],
      ),
    );
  }

  Widget _buildIncomingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No incoming requests"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['medicineName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text("Qty: ${data['quantity']}", style: const TextStyle(color: Colors.grey)),
                    Text("Patient Email: ${data['patientEmail']}", style: const TextStyle(color: Colors.grey)),
                    Text("Patient Phone: ${data['patientPhone']}", style: const TextStyle(color: Colors.grey)),
                    Text("Delivery Address: ${data['pharmacyAddress']}", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _showAcceptDialog(doc.id),
                        child: const Text("Accept", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAcceptedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pharmacy_requests')
          .where('acceptedByPharmacistId', isEqualTo: currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No accepted requests"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'approved';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['medicineName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Chip(
                          label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: status == 'approved' ? Colors.blue : (status == 'out for delivery' ? Colors.purple : Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Qty: ${data['quantity']}", style: const TextStyle(color: Colors.grey)),
                    Text("Patient Email: ${data['patientEmail']}", style: const TextStyle(color: Colors.grey)),
                    Text("Patient Phone: ${data['patientPhone']}", style: const TextStyle(color: Colors.grey)),
                    Text("Address: ${data['pharmacyAddress']}", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text("Medicine Cost: Rs. ${data['medicineCost']}", style: const TextStyle(color: Colors.grey)),
                    Text("Delivery Fee: Rs. ${data['deliveryFee']}", style: const TextStyle(color: Colors.grey)),
                    Text("Total Billed: Rs. ${data['totalAmount']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    
                    if (status == 'out for delivery') ...[
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.directions_bike, color: Colors.purple),
                          SizedBox(width: 8),
                          Text("Order is on the way!", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],

                    if (status != 'delivered') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: status == 'approved' ? Colors.purple : Colors.green,
                          ),
                          onPressed: () => _advanceStatus(doc.id, status),
                          child: Text(
                            status == 'approved' ? "Mark as Out for Delivery" : "Mark as Delivered",
                            style: const TextStyle(color: Colors.white),
                          ),
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
    );
  }
}
