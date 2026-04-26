import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Communication"),
        backgroundColor: Colors.green.shade700, // Matching your theme
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              // REMOVED 'const' from here because of the shaded color below
              children: [
                // Automated Broadcast Example
                Card(
                  color: Colors.blueGrey.shade50, // This is not a constant
                  child: const ListTile(
                    leading: Icon(Icons.notifications_active, color: Colors.blue),
                    title: Text("System Update"),
                    subtitle: Text("Van 01 has entered the 1km Geofence."),
                  ),
                ),
                // Manual Message Example
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text("Good morning! Is the van on time?")),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Message driver...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green), 
                  onPressed: () {
                    // Logic for sending message goes here
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}