import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("My Profile"),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(child: Text("Please log in again.")),
      );
    }

    final ref = FirebaseDatabase.instance.ref("parents/${user.uid}");

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: ref.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

            return SingleChildScrollView(
              child: Column(
                children: [
                  // --- TOP GREEN STRIP (HEADER) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        // UPDATED: Profile Image with fallback to Icon
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: data['profile_image'] != null 
                              ? NetworkImage(data['profile_image'].toString()) 
                              : null,
                          child: data['profile_image'] == null 
                              ? const Icon(Icons.person, size: 55, color: Colors.green) 
                              : null,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          data['name']?.toString() ?? "User Name",
                          style: const TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white
                          ),
                        ),
                        Text(
                          user.email ?? "email@example.com",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // --- INFORMATION TILES ---
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildInfoTile(Icons.home, "Home Address", data['address']?.toString() ?? "Not set"),
                        // REMOVED: Child's School tile
                        _buildInfoTile(Icons.phone, "Contact Number", data['contact_number']?.toString() ?? "Not set"),
                        
                        const SizedBox(height: 30),
                        
                        // --- LOGOUT BUTTON ---
                        ElevatedButton.icon(
                          onPressed: () => _handleLogout(context),
                          icon: const Icon(Icons.logout),
                          label: const Text("Log Out"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.red, width: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const Center(child: Text("No profile data found in database."));
        },
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.green.shade700, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}