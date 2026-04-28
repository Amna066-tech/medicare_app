import 'package:flutter/material.dart';
import 'add_measurement_screen.dart'; // Assuming you still have your add screen!

class MeasurementTrackerScreen extends StatelessWidget {
  const MeasurementTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Health Tracker", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4CA1AF),
        elevation: 0,
        automaticallyImplyLeading: false, // Hides back button
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMeasurementScreen()));
        },
        backgroundColor: const Color(0xFF4CA1AF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Vitals", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24, top: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF4CA1AF),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Vital Signs", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 8),
                Text("Monitor your BP, Sugar, and Weight.", style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildTrackerCard(
                  title: "Blood Pressure (BP)",
                  subtitle: "Track your systolic and diastolic",
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  recentValue: "120/80 mmHg",
                ),
                const SizedBox(height: 16),
                _buildTrackerCard(
                  title: "Blood Sugar",
                  subtitle: "Fasting & Post-meal glucose",
                  icon: Icons.water_drop,
                  color: Colors.blueAccent,
                  recentValue: "95 mg/dL",
                ),
                const SizedBox(height: 16),
                _buildTrackerCard(
                  title: "Body Weight",
                  subtitle: "Track your BMI and weight goals",
                  icon: Icons.monitor_weight,
                  color: Colors.teal,
                  recentValue: "72 kg",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A custom widget to make beautiful, consistent cards
  Widget _buildTrackerCard({required String title, required String subtitle, required IconData icon, required Color color, required String recentValue}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text("Recent: $recentValue", style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                  )
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}