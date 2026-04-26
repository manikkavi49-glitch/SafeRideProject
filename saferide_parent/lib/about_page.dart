import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About SafeRide")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.security, size: 80, color: Colors.indigo),
            const SizedBox(height: 20),
            const Text("SafeRide AI", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const Text("Empowering School Transport Safety", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            const Text(
              "SafeRide is a next-generation safety solution designed for the Sri Lankan school transport sector. "
              "Our mission is to provide premium safety features—like AI drowsiness detection and live GPS tracking—without requiring expensive hardware. "
              "By leveraging existing smartphone sensors, we make safety accessible for every driver and every parent.",
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.6, fontSize: 15),
            ),
            const Divider(height: 40),
            _buildTechChip("Flutter / Dart", Icons.code),
            _buildTechChip("Firebase Realtime DB", Icons.cloud_done),
            _buildTechChip("Dlib Facial Landmarks (AI)", Icons.visibility),
            _buildTechChip("Zero-Hardware Vision", Icons.smartphone),
            const SizedBox(height: 40),
            const Text("© 2026 SafeRide Tech. All rights reserved.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTechChip(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(label),
    );
  }
}