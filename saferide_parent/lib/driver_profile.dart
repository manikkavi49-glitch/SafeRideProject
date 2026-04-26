import 'package:flutter/material.dart';
import 'chat_page.dart'; // Make sure this file exists in your lib folder

class DriverProfilePage extends StatelessWidget {
  const DriverProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Profile"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 30),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text("Sumith Perera", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Vehicle: WP - CAS 1234"),
            const Divider(indent: 50, endIndent: 50, height: 40),
            const ListTile(
              leading: Icon(Icons.star, color: Colors.orange),
              title: Text("4.9 Rating"),
            ),
            const ListTile(
              leading: Icon(Icons.verified_user, color: Colors.green),
              title: Text("Background Checked"),
            ),
            const SizedBox(height: 30),
            // --- NEW CHAT BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatPage()),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Chat with Driver"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}