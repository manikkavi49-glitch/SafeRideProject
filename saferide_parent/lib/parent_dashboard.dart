import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'parent_map_screen.dart';
import 'attendance_page.dart';
import 'profile_page.dart';
import 'driver_profile.dart'; 
import 'safety_detail_page.dart'; 
import 'settings_page.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  List<String> assignedVans = ['van01', 'van02', 'van03']; 
  String? selectedVan = 'van01';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // Prevent the app from requesting 'parents/null'
    DatabaseReference? nameRef;
    if (user != null) {
      nameRef = FirebaseDatabase.instance.ref("parents/${user.uid}/name");
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "SafeRide Portal",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const ProfilePage())
            ),
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.green),
            ),
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 5),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: nameRef == null 
              ? const Text("Loading...", style: TextStyle(color: Colors.white))
              : StreamBuilder(
                  stream: nameRef.onValue,
                  builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                    String name = "Parent";
                    if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                      name = snapshot.data!.snapshot.value.toString();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome, $name",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Your child's safety is our priority",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVanSelector(),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SafeRide Services", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                        const SizedBox(height: 15),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          childAspectRatio: 1.1,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildNavCard(context, "Live Tracking", 'assets/tracking_card.jpg', ParentMapScreen(vanId: selectedVan!)),
                            _buildNavCard(context, "Driver Profile", 'assets/driver_card.jpg', const DriverProfilePage()),
                            _buildNavCard(context, "Safety Analysis", 'assets/ai_logs_card.jpg', const SafetyDetailPage()),
                            _buildNavCard(context, "Attendance", 'assets/attendance_card.jpg', const AttendancePage()),
                          ],
                        ),
                      ],
                    ),
                  ),

                  _buildSettingsSection(context),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildVanSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Van", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: assignedVans.map((van) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(van),
                    selected: selectedVan == van,
                    selectedColor: Colors.green.shade700,
                    labelStyle: TextStyle(color: selectedVan == van ? Colors.white : Colors.black),
                    onSelected: (val) => setState(() => selectedVan = van),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavCard(BuildContext context, String title, String path, Widget dest) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => dest)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(path), 
            fit: BoxFit.cover, 
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(12),
        child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListTile(
        leading: const Icon(Icons.settings, color: Colors.green),
        title: const Text("General Settings"),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), 
          side: BorderSide(color: Colors.grey.shade200)
        ),
      ),
    );
  }
}