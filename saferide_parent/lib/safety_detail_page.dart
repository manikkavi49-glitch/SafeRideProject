import 'package:flutter/material.dart';

class SafetyDetailPage extends StatelessWidget {
  const SafetyDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Analysis"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.verified_user, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 20),
            const Text(
              "Current Status: SECURE", 
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: Colors.green
              )
            ),
            const Divider(height: 30),
            const Text(
              "AI Analysis Details:", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            const SizedBox(height: 15),
            _buildSafetyFactor("Driver Alertness", "Optimal (EAR: 0.32)"),
            _buildSafetyFactor("Vehicle Speed", "42 km/h"),
            _buildSafetyFactor("Route Adherence", "On Track"),
            // Emergency button and Spacer removed from here
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFactor(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)), 
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
        ],
      ),
    );
  }
}