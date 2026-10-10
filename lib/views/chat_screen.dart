import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String peerName;

  const ChatScreen({super.key, required this.chatId, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  String _currentUserRole = 'Patient';
  bool _isLoading = true;
  bool _hasTabs = true;
  String _doctorPrivateChatTarget = 'Patient'; // 'Patient' or 'Caregiver'

  List<String> _groupParticipants = [];
  List<String> _privatePatientParticipants = [];
  List<String> _privateCaregiverParticipants = [];

  static const Color brandBlue = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _initializeChat();
  }

  String get _baseRequestId {
    if (widget.chatId.endsWith('_patient')) {
      return widget.chatId.substring(0, widget.chatId.length - '_patient'.length);
    }
    if (widget.chatId.endsWith('_caregiver')) {
      return widget.chatId.substring(0, widget.chatId.length - '_caregiver'.length);
    }
    return widget.chatId;
  }

  Future<void> _initializeChat() async {
    if (currentUser == null) return;
    
    // 1. Fetch current user role
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (userDoc.exists) {
      _currentUserRole = userDoc.data()?['role'] ?? 'Patient';
    }

    // 2. Resolve participants
    final baseReq = _baseRequestId;
    final patientId = baseReq.split('_').last;
    String? doctorId;
    String? doctorEmail;
    final accessReq = await FirebaseFirestore.instance.collection('access_requests').doc(baseReq).get();
    if (accessReq.exists) {
      doctorEmail = accessReq.data()?['doctorEmail'];
    }

    if (doctorEmail != null) {
      final docQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: doctorEmail).limit(1).get();
      if (docQuery.docs.isNotEmpty) doctorId = docQuery.docs.first.id;
    }

    String? caregiverId;
    // We check both 'caregiver_requests' and 'users' to find the caregiver
    final cgQuery = await FirebaseFirestore.instance.collection('caregiver_requests').where('patientId', isEqualTo: patientId).get();
    for (var doc in cgQuery.docs) {
      final status = doc.data()['status']?.toString().toLowerCase();
      if (status == 'accepted' || status == 'approved') {
        final cgEmail = doc.data()['caregiverEmail'];
        if (cgEmail != null) {
          final cgUserQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: cgEmail).limit(1).get();
          if (cgUserQuery.docs.isNotEmpty) {
            caregiverId = cgUserQuery.docs.first.id;
            break;
          }
        }
      }
    }

    final group = <String>[];
    if (patientId.isNotEmpty) group.add(patientId);
    if (doctorId != null) group.add(doctorId);
    if (caregiverId != null) group.add(caregiverId);
    _groupParticipants = group;

    final pp = <String>[];
    if (patientId.isNotEmpty) pp.add(patientId);
    if (doctorId != null) pp.add(doctorId);
    _privatePatientParticipants = pp;

    final pc = <String>[];
    if (caregiverId != null) pc.add(caregiverId);
    if (doctorId != null) pc.add(doctorId);
    _privateCaregiverParticipants = pc;

    _hasTabs = doctorId != null;

    if (mounted) {
      setState(() => _isLoading = false);
      _markAsRead(_currentActiveRootId);
    }
  }

  String get _groupChatId => _baseRequestId;
  String get _privatePatientId => '${_baseRequestId}_patient';
  String get _privateCaregiverId => '${_baseRequestId}_caregiver';

  String get _currentActiveRootId {
    if (!_hasTabs) return _groupChatId;
    if (_tabController.index == 0) return _groupChatId;
    if (_currentUserRole == 'Doctor') {
      return _doctorPrivateChatTarget == 'Patient' ? _privatePatientId : _privateCaregiverId;
    } else if (_currentUserRole == 'Patient') {
      return _privatePatientId;
    } else {
      return _privateCaregiverId;
    }
  }

  List<String> get _currentActiveParticipants {
    if (!_hasTabs) return _groupParticipants;
    if (_tabController.index == 0) return _groupParticipants;
    if (_currentUserRole == 'Doctor') {
      return _doctorPrivateChatTarget == 'Patient' ? _privatePatientParticipants : _privateCaregiverParticipants;
    } else if (_currentUserRole == 'Patient') {
      return _privatePatientParticipants;
    } else {
      return _privateCaregiverParticipants;
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;
    _messageController.clear();

    final activeRoot = _currentActiveRootId;
    final activeParticipants = _currentActiveParticipants;

    try {
      final docRef = FirebaseFirestore.instance.collection('chats').doc(activeRoot);
      await docRef.collection('messages').add({
        'senderId': currentUser!.uid,
        'senderEmail': currentUser!.email,
        'senderRole': _currentUserRole,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [currentUser!.uid],
      });

      await docRef.set({
        'lastMessage': text,
        'lastSenderId': currentUser!.uid,
        'lastSenderName': currentUser!.displayName ?? currentUser!.email?.split('@').first ?? 'User',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'participants': FieldValue.arrayUnion(activeParticipants),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _markAsRead(String rootDocId) async {
    if (currentUser == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('chats').doc(rootDocId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        if (data['lastSenderId'] != currentUser!.uid && data['isRead'] == false) {
          await docRef.update({'isRead': true});
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        title: Text(widget.peerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: (_isLoading || !_hasTabs)
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: "Group Chat"),
                  Tab(text: "Private Chat"),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: brandBlue))
          : Column(
              children: [
                if (_hasTabs && _tabController.index == 1 && _currentUserRole == 'Doctor')
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDoctorToggle("With Patient", "Patient"),
                        const SizedBox(width: 12),
                        _buildDoctorToggle("With Caregiver", "Caregiver"),
                      ],
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(_currentActiveRootId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No messages yet.", style: TextStyle(color: Colors.grey)));
                      }

                      final docs = snapshot.data!.docs;
                      
                      final unreadDocs = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final readBy = List<String>.from(data['readBy'] ?? []);
                        return data['senderId'] != currentUser?.uid && !readBy.contains(currentUser?.uid);
                      }).toList();

                      if (unreadDocs.isNotEmpty) {
                        Future.microtask(() {
                          if (!mounted) return;
                          final batch = FirebaseFirestore.instance.batch();
                          int count = 0;
                          for (var doc in unreadDocs) {
                            batch.update(doc.reference, {'readBy': FieldValue.arrayUnion([currentUser?.uid])});
                            count++;
                            if (count >= 500) break; // Firestore limit
                          }
                          if (count > 0) batch.commit();
                          _markAsRead(_currentActiveRootId); // update root doc as well just in case
                        });
                      }

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final bool isMe = data['senderId'] == currentUser?.uid;
                          final messageText = data['message'] ?? '';
                          final senderRole = data['senderRole'] ?? 'User';

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe && (!_hasTabs || _tabController.index == 0)) // Show role label
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                                    child: Text(
                                      senderRole,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: senderRole == 'Patient' ? Colors.green[700] : (senderRole == 'Caregiver' ? Colors.orange[700] : brandBlue),
                                      ),
                                    ),
                                  ),
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                  decoration: BoxDecoration(
                                    color: isMe ? brandBlue : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))
                                    ]
                                  ),
                                  child: Text(
                                    messageText,
                                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: (!_hasTabs || _tabController.index == 1) ? "Type a message..." : "Type a group message...",
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: brandBlue),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDoctorToggle(String title, String target) {
    final isSelected = _doctorPrivateChatTarget == target;
    return GestureDetector(
      onTap: () {
        setState(() => _doctorPrivateChatTarget = target);
        _markAsRead(_currentActiveRootId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? brandBlue : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            if (isSelected) const Icon(Icons.check, size: 16, color: brandBlue),
            if (isSelected) const SizedBox(width: 4),
            Text(title, style: TextStyle(color: isSelected ? brandBlue : Colors.grey.shade700, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}