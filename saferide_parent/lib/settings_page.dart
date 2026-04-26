import 'package:flutter/material.dart';
import 'privacy_policy_page.dart'; // New file
import 'about_page.dart';         // New file

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Push Notifications"),
            subtitle: const Text("Alerts for boarding and arrival"),
            trailing: Switch(value: true, onChanged: (v) {}),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("Privacy"),
            subtitle: const Text("Data handling & encryption"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyPage())),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            trailing: const Text("English (SL)"),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About SafeRide"),
            subtitle: const Text("Version 1.0.4 - AI Safety Engine"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutPage())),
          ),
        ],
      ),
    );
  }
}