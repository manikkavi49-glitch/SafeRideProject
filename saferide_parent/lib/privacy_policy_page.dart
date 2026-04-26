import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Privacy & Data Protection", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildSection("1. Data Collection", 
              "SafeRide collects real-time GPS coordinates and driver facial landmark data (EAR) to ensure student safety. This data is processed securely via Firebase infrastructure."),
            _buildSection("2. AI Monitoring", 
              "Facial analysis for drowsiness detection is performed locally on the driver's device. No raw video footage is stored or transmitted to our servers; only numeric 'Alertness Scores' are recorded."),
            _buildSection("3. Location Privacy", 
              "Child location data is shared only with registered parents/guardians and is encrypted using 256-bit SSL protocols."),
            _buildSection("4. Your Rights", 
              "Users can request data deletion or opt-out of history logging at any time through the support portal."),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.black87, height: 1.4)),
        ],
      ),
    );
  }
}