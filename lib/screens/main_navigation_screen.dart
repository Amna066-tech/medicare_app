import 'package:flutter/material.dart';

// Your 4 screen imports!
import 'reminders_dashboard.dart';
import 'measurement_tracker_screen.dart';
import 'chatbot_screen.dart'; // ADDED THIS IMPORT
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // FIXED: The list now has exactly 4 items to match your 4 buttons!
  final List<Widget> _screens = [
    const RemindersDashboard(),       // Index 0: Reminders
    const MeasurementTrackerScreen(), // Index 1: Tracker
    const ChatbotScreen(),            // Index 2: Chatbot (This was missing!)
    const ProfileScreen(),            // Index 3: Profile
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body changes based on which tab is selected
      body: _screens[_selectedIndex],

      // Your custom Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Keeps all text visible
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF4CA1AF), // Your app's theme color
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active_outlined),
            activeIcon: Icon(Icons.notifications_active),
            label: 'Reminders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_weight_outlined),
            activeIcon: Icon(Icons.monitor_weight),
            label: 'Tracker',
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