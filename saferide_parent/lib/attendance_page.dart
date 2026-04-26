import 'package:flutter/material.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance History"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: 10, // This will eventually pull from Firebase
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            elevation: 2, // Added a tiny bit of shadow for depth
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: Icon(
                index % 2 == 0 ? Icons.login : Icons.logout,
                color: index % 2 == 0 ? Colors.green : Colors.orange,
              ),
              title: Text(
                index % 2 == 0 ? "Boarded Van" : "Dropped Off",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("April ${22 - (index ~/ 2)}, 2026 • 07:${15 + index} AM"),
              // Trailing (arrow) icon has been removed from here
            ),
          );
        },
      ),
    );
  }
}