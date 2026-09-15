import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const RegisteredUsersTab(),
      const LicenseVerificationTab(),
      const UserFeedbackTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Admin Control Center", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => logout(context),
          )
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF4CA1AF),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: "Verification"),
          BottomNavigationBarItem(icon: Icon(Icons.feedback), label: "Feedback"),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 1. Registered Users Tab
// ---------------------------------------------------------
class RegisteredUsersTab extends StatefulWidget {
  const RegisteredUsersTab({super.key});
  @override
  State<RegisteredUsersTab> createState() => _RegisteredUsersTabState();
}
class _RegisteredUsersTabState extends State<RegisteredUsersTab> {
  String _searchQuery = "";

  Widget _buildRoleBadge(String role) {
    Color bgColor;
    Color textColor = Colors.white;
    switch (role) {
      case 'Doctor':
        bgColor = Colors.blue;
        break;
      case 'Pharmacist':
        bgColor = Colors.purple;
        break;
      case 'Caregiver':
        bgColor = Colors.orange;
        break;
      case 'Patient':
      default:
        bgColor = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(role, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF2C3E50),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search by name or email...",
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No users found."));

              var users = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String name = (data['name'] ?? "").toLowerCase();
                String email = (data['email'] ?? "").toLowerCase();
                return name.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var data = users[index].data() as Map<String, dynamic>;
                  String name = data['name'] ?? "Unknown User";
                  String email = data['email'] ?? "No Email";
                  String role = data['role'] ?? "Patient";

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4CA1AF).withValues(alpha: 0.2),
                        child: const Icon(Icons.person, color: Color(0xFF4CA1AF)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      trailing: _buildRoleBadge(role),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// 2. License Verification Tab
// ---------------------------------------------------------
class LicenseVerificationTab extends StatefulWidget {
  const LicenseVerificationTab({super.key});
  @override
  State<LicenseVerificationTab> createState() => _LicenseVerificationTabState();
}
class _LicenseVerificationTabState extends State<LicenseVerificationTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedRole = 'Doctors';

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

  Future<void> _updateStatus(String uid, String newStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'verificationStatus': newStatus});
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Image.network(imageUrl, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('verificationStatus', isEqualTo: statusFilter)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No records found."));

        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String role = data['role'] ?? '';
          if (_selectedRole == 'Doctors') return role == 'Doctor';
          if (_selectedRole == 'Pharmacists') return role == 'Pharmacist';
          if (_selectedRole == 'Nurses') return role == 'Caregiver' && data['caregiverType'] == 'Nurse';
          return false;
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("No records found for this category."));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String uid = docs[index].id;
            String name = data['name'] ?? 'Unknown';
            String email = data['email'] ?? '';
            String imageUrl = data['certificateImageUrl'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(email, style: const TextStyle(color: Colors.grey)),
                    const Divider(),
                    if (_selectedRole == 'Doctors') ...[
                      Text("Speciality: ${data['speciality'] ?? 'N/A'}"),
                      Text("License: ${data['licenseNumber'] ?? 'N/A'}"),
                    ] else if (_selectedRole == 'Pharmacists') ...[
                      Text("Pharmacy: ${data['pharmacyName'] ?? 'N/A'}"),
                      Text("Address: ${data['pharmacyAddress'] ?? 'N/A'}"),
                      Text("Drug License: ${data['drugLicenseNumber'] ?? 'N/A'}"),
                      Text("Reg Number: ${data['pharmacistRegistrationNumber'] ?? 'N/A'}"),
                    ] else if (_selectedRole == 'Nurses') ...[
                      Text("Nursing License: ${data['nursingLicenseNumber'] ?? 'N/A'}"),
                    ],
                    const SizedBox(height: 12),
                    if (imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showImageDialog(imageUrl),
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                          ),
                          child: const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.zoom_in, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                            ),
                          ),
                        ),
                      )
                    else
                      const Text("No Certificate Uploaded", style: TextStyle(color: Colors.red)),
                    
                    const SizedBox(height: 16),
                    if (statusFilter == 'PENDING')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _updateStatus(uid, 'APPROVED'),
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text("Approve", style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => _updateStatus(uid, 'REJECTED'),
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text("Reject", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
                    else if (statusFilter == 'APPROVED')
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                          onPressed: () => _updateStatus(uid, 'PENDING'),
                          icon: const Icon(Icons.warning),
                          label: const Text("Revoke Approval"),
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            items: ['Doctors', 'Pharmacists', 'Nurses'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedRole = val);
            },
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2C3E50),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4CA1AF),
          tabs: const [
            Tab(text: "Incoming"),
            Tab(text: "Approved"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildVerificationList('PENDING'),
              _buildVerificationList('APPROVED'),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// 3. User Feedback Tab
// ---------------------------------------------------------
class UserFeedbackTab extends StatelessWidget {
  const UserFeedbackTab({super.key});

  Widget _buildRoleBadge(String role) {
    Color bgColor;
    switch (role) {
      case 'Doctor': bgColor = Colors.blue; break;
      case 'Pharmacist': bgColor = Colors.purple; break;
      case 'Caregiver': bgColor = Colors.orange; break;
      case 'Patient':
      default: bgColor = Colors.green; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('feedback').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No feedback received yet."));

        var feedbackDocs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: feedbackDocs.length,
          itemBuilder: (context, index) {
            var data = feedbackDocs[index].data() as Map<String, dynamic>;
            String name = data['userName'] ?? 'Unknown';
            String email = data['userEmail'] ?? '';
            String role = data['role'] ?? 'Patient';
            String text = data['feedbackText'] ?? '';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildRoleBadge(role),
                      ],
                    ),
                    Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    Text(text, style: const TextStyle(fontSize: 14)),
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