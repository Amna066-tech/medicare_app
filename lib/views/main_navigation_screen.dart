import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'measurement_tracker_screen.dart';
import 'pharmacy_screen.dart'; // <-- 1. Import your new Pharmacy screen here
import 'chatbot_screen.dart';
import 'profile_screen.dart';

import '../services/chat_notification_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final String? viewingPatientId;

  const MainNavigationScreen({super.key, this.viewingPatientId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    ChatNotificationService().startListening();
  }

  @override
  void dispose() {
    ChatNotificationService().stopListening();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 2. Add PharmacyScreen into the list between Tracker and Chatbot
    final List<Widget> screens = [
      HomeScreen(viewingPatientId: widget.viewingPatientId),
      MeasurementTrackerScreen(viewingPatientId: widget.viewingPatientId),
      PharmacyScreen(viewingPatientId: widget.viewingPatientId), // Index 2: Pharmacy
      const ChatbotScreen(),
      ProfileScreen(viewingPatientId: widget.viewingPatientId),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF4CA1AF),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_weight_outlined),
            activeIcon: Icon(Icons.monitor_weight),
            label: 'Tracker',
          ),
          // 3. Add Pharmacy icon right between Tracker and Chatbot
          BottomNavigationBarItem(
            icon: Icon(Icons.local_pharmacy_outlined),
            activeIcon: Icon(Icons.local_pharmacy),
            label: 'Pharmacy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}