import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'parent_map_screen.dart';
import 'attendance_page.dart';
import 'profile_page.dart';
import 'driver_profile.dart';
import 'safety_detail_page.dart';
import 'settings_page.dart';
import 'services/database_service.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();

    // Listen for Emergency SOS
    FirebaseDatabase.instance.ref("sos").onValue.listen((event) {
      if (event.snapshot.value != null) {
        var data = event.snapshot.value as Map<dynamic, dynamic>;
        bool isActive = data['active'] ?? false;

        if (isActive && mounted) {
          _showEmergencyDialog(data['message'] ?? "Emergency Alert!");
        }
      }
    });
  }

  void _showEmergencyDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Icon(Icons.warning, color: Colors.white, size: 50),
        content: Text(
          "EMERGENCY SOS\n\n$message",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "DISMISS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTrackingClick() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    Query studentQuery = FirebaseDatabase.instance
        .ref("students")
        .orderByChild("parentEmail")
        .equalTo(user.email!);

    DataSnapshot snapshot = await studentQuery.get();

    if (!mounted) return;

    if (snapshot.exists) {
      Map<dynamic, dynamic> studentsMap =
          snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> studentList = [];

      studentsMap.forEach((key, value) {
        studentList.add({"name": value['name'], "vanId": value['vanId']});
      });

      _showStudentSelectionDialog(studentList);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No students found linked to your account."),
        ),
      );
    }
  }

  void _showStudentSelectionDialog(List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Student"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: students.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.face, color: Colors.green),
                title: Text(students[index]['name']),
                subtitle: Text("Van: ${students[index]['vanId']}"),
                onTap: () {
                  Navigator.pop(context);
                  _checkTripAndNavigate(students[index]['vanId']);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ✅ FIX: Correct trip active check using today's trip ID format
  // Firebase structure: trips/trip_{vanId}_{YYYYMMDD} with vanId field
  Future<void> _checkTripAndNavigate(String vanId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      bool isTripActive = false;

      // ✅ Method 1: Check today's trip directly using the correct ID format
      // Matches driver AttendanceScreen._todayTripId format: trip_{vanId}_{YYYYMMDD}
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final todayTripId = 'trip_${vanId}_$dateStr';

      final todaySnap = await FirebaseDatabase.instance
          .ref('trips/$todayTripId')
          .get();

      if (todaySnap.exists) {
        final tripData = todaySnap.value as Map?;
        if (tripData?['status'] == 'active') {
          isTripActive = true;
        }
      }

      // ✅ Method 2: Fallback — query all trips for this vanId (handles edge cases)
      if (!isTripActive) {
        final querySnap = await FirebaseDatabase.instance
            .ref('trips')
            .orderByChild('vanId')
            .equalTo(vanId)
            .get();

        if (querySnap.exists) {
          final trips = querySnap.value as Map;
          isTripActive = trips.values.any(
            (trip) => trip is Map && trip['status'] == 'active',
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (isTripActive) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParentMapScreen(vanId: vanId),
          ),
        );
      } else {
        _showNoActiveTripMessage();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Trip Check Error: $e");
    }
  }

  void _showNoActiveTripMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Trip Not Started"),
        content: const Text(
          "The driver has not started the trip yet. Please try again later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSafetyClick() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    Query studentQuery = FirebaseDatabase.instance
        .ref("students")
        .orderByChild("parentEmail")
        .equalTo(user.email!);

    DataSnapshot snapshot = await studentQuery.get();

    if (!mounted) return;

    if (snapshot.exists) {
      Map<dynamic, dynamic> studentsMap = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> studentList = [];

      studentsMap.forEach((key, value) {
        studentList.add({
          "name":     value['name'],
          "vanId":    value['vanId']    ?? 'van01',
          "driverId": value['driverId'] ?? '',       // ✅ driverId include
        });
      });

      _showStudentSelectionDialogForSafety(studentList);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No students found linked to your account.")),
      );
    }
  }

  void _showStudentSelectionDialogForSafety(List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Student for Safety"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: students.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.security, color: Colors.blue),
                title: Text(students[index]['name']),
                subtitle: Text("Van: ${students[index]['vanId']}"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SafetyDetailPage(
                        studentName: students[index]['name'],
                        vanId:       students[index]['vanId'],
                        driverId:    students[index]['driverId'] ?? '', // ✅
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleDriverClick() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    Query studentQuery = FirebaseDatabase.instance
        .ref("students")
        .orderByChild("parentEmail")
        .equalTo(user.email!);

    DataSnapshot snapshot = await studentQuery.get();

    if (!mounted) return;

    if (snapshot.exists) {
      Map<dynamic, dynamic> studentsMap = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> studentList = [];

      studentsMap.forEach((key, value) {
        studentList.add({
          "name": value['name'],
          "vanId": value['vanId'],
          "driverId": value['driverId']
        });
      });

      _showStudentSelectionDialogForDriver(studentList);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No students found linked to your account."),
        ),
      );
    }
  }

  void _showStudentSelectionDialogForDriver(List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Student"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: students.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.face, color: Colors.green),
                title: Text(students[index]['name']),
                subtitle: Text("Van: ${students[index]['vanId']}"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverProfilePage(
                        driverId: students[index]['driverId'] ?? 'driver_001',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
              MaterialPageRoute(builder: (context) => const ProfilePage()),
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
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 20,
              top: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: nameRef == null
                ? const Text(
                    "Loading...",
                    style: TextStyle(color: Colors.white),
                  )
                : StreamBuilder(
                    stream: nameRef.onValue,
                    builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                      String name = "Parent";
                      if (snapshot.hasData &&
                          snapshot.data!.snapshot.value != null) {
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
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
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
                  StreamBuilder(
                    stream: _dbService.getDrowsinessAlerts('van01'),
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data!.snapshot.value != null) {
                        var alertData =
                            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        bool isDrowsy = alertData['isDrowsy'] ?? false;

                        if (isDrowsy) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(
                                    "⚠️ ALERT: ${alertData['lastAlert']}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "SafeRide Services",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                            _buildNavCard(
                              context,
                              "Live Tracking",
                              'assets/tracking_card.jpg',
                              const SizedBox.shrink(),
                              onTapOverride: _handleTrackingClick,
                            ),
                            _buildNavCard(
                              context,
                              "Driver Profile",
                              'assets/driver_card.jpg',
                              const SizedBox.shrink(),
                              onTapOverride: _handleDriverClick,
                            ),
                            _buildNavCard(
                              context,
                              "Safety Analysis",
                              'assets/ai_logs_card.jpg',
                              const SizedBox.shrink(),
                              onTapOverride: _handleSafetyClick,
                            ),
                            _buildNavCard(
                              context,
                              "Attendance",
                              'assets/attendance_card.jpg',
                              const AttendancePage(),
                            ),
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

  Widget _buildNavCard(
    BuildContext context,
    String title,
    String path,
    Widget dest, {
    VoidCallback? onTapOverride,
  }) {
    return InkWell(
      onTap:
          onTapOverride ??
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => dest),
          ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(path),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.4),
              BlendMode.darken,
            ),
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(12),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListTile(
        leading: const Icon(Icons.settings, color: Colors.green),
        title: const Text("General Settings"),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}