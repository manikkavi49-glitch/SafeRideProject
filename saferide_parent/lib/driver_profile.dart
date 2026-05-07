import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverProfilePage extends StatefulWidget {
  final String driverId;

  const DriverProfilePage({super.key, required this.driverId});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  // පණිවිඩ යැවීමට මවුපියන්ගේ දත්ත ලබා ගැනීම
  Future<void> _navigateToChat(BuildContext context) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in first")),
      );
      return;
    }

    String pEmail = currentUser.email ?? "";
    String pName = currentUser.displayName ?? "Parent";

    // දත්ත පද්ධතියෙන් (Database) මවුපියන්ගේ නම පරීක්ෂා කිරීම (විකල්ප පියවරක්)
    final DatabaseReference studentsRef = FirebaseDatabase.instance.ref("students");
    final snapshot = await studentsRef.orderByChild('parentEmail').equalTo(pEmail).limitToFirst(1).get();

    if (snapshot.exists) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      pName = data.values.first['name'] ?? pName; // Database එකේ නම තිබේ නම් එය ගනී
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          vanId: "van01", // මෙහිදී අවශ්‍ය නම් dynamic වෑන් ID එකක් ලබා දෙන්න
          parentEmail: pEmail, // අත්‍යවශ්‍ය parameter එක
          parentName: pName,   // අත්‍යවශ්‍ය parameter එක
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference driverRef = 
        FirebaseDatabase.instance.ref("drivers/${widget.driverId}/profile");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Profile"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: driverRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            
            return SingleChildScrollView(
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: data['photoBase64'] != null 
                          ? MemoryImage(base64Decode(data['photoBase64'])) 
                          : null,
                      child: data['photoBase64'] == null 
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    
                    const SizedBox(height: 15),
                    
                    Text(
                      data['name'] ?? "Unknown Driver", 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                    ),
                    Text(
                      "Vehicle: ${data['vehicle'] ?? 'N/A'}", 
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    
                    const Divider(indent: 50, endIndent: 50, height: 40),

                    _buildListTile(
                      icon: Icons.phone, 
                      color: Colors.green, 
                      text: data['phone'] ?? "No phone provided"
                    ),
                    _buildListTile(
                      icon: Icons.star, 
                      color: Colors.orange, 
                      text: "4.9 Rating"
                    ),
                    _buildListTile(
                      icon: Icons.verified_user, 
                      color: Colors.blue, 
                      text: "License: ${data['license'] ?? 'Verified'}"
                    ),
                    
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToChat(context), // වෙනම function එකක් ලෙස හැඳින්වීම
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }

          return const Center(child: Text("Driver profile not found."));
        },
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required Color color, required String text}) {
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(left: 30),
        child: Icon(icon, color: color),
      ),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }
}