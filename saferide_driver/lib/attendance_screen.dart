import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Student {
  final String id;
  final String name;
  final String grade;
  AttendanceStatus status;
  String? boardTime;
  String? exitTime;

  Student({
    required this.id,
    required this.name,
    required this.grade,
    this.status = AttendanceStatus.waiting,
    this.boardTime,
    this.exitTime,
  });

  // Firebase දත්ත Student object එකක් බවට පත් කිරීම
  factory Student.fromMap(String id, Map data) {
    return Student(
      id: id,
      name: data['name'] ?? 'Unknown',
      grade: data['grade'] ?? 'N/A',
    );
  }
}

enum AttendanceStatus { waiting, onBoard, exited }

class AttendanceScreen extends StatefulWidget {
  final bool isTripActive;
  const AttendanceScreen({super.key, required this.isTripActive});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  List<Student> _students = [];
  bool _isLoading = true;
  
  // ගතිකව Trip ID එක ලබාගැනීම (උදා: වර්තමාන දිනය අනුව)
  String get _currentTripId => "trip_${DateTime.now().millisecondsSinceEpoch}";

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  // Firebase එකෙන් නියම ශිෂ්‍ය ලැයිස්තුව ලබාගැනීම
  Future<void> _fetchStudents() async {
    if (_user == null) return;

    try {
      // 1. මුලින්ම රියදුරාට අදාළ ශිෂ්‍ය ලැයිස්තුව ලබාගන්න
      final snapshot = await FirebaseDatabase.instance
          .ref("drivers/${_user!.uid}/students")
          .get();

      if (snapshot.exists) {
        final Map data = snapshot.value as Map;
        List<Student> loadedStudents = [];
        data.forEach((key, value) {
          loadedStudents.add(Student.fromMap(key, value));
        });

        if (mounted) {
          setState(() {
            _students = loadedStudents;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _now() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markBoarded(Student student) async {
    final time = _now();
    setState(() {
      student.status = AttendanceStatus.onBoard;
      student.boardTime = time;
    });
    
    // Hardcoded 'trip_001' වෙනුවට dynamic trip id එකක් භාවිතා කිරීම
    await FirebaseDatabase.instance
        .ref("attendance/$_currentTripId/${student.id}")
        .update({
      'name': student.name,
      'status': 'onBoard',
      'boardTime': time,
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<void> _markExited(Student student) async {
    final time = _now();
    setState(() {
      student.status = AttendanceStatus.exited;
      student.exitTime = time;
    });
    
    await FirebaseDatabase.instance
        .ref("attendance/$_currentTripId/${student.id}")
        .update({
      'status': 'exited',
      'exitTime': time,
      'exitTimestamp': ServerValue.timestamp,
    });
  }

  // UI Helper functions (Colors, Badges)
  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.waiting: return Colors.grey.shade200;
      case AttendanceStatus.onBoard: return Colors.green.shade50;
      case AttendanceStatus.exited: return Colors.blue.shade50;
    }
  }

  Widget _statusBadge(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.waiting: return _badge('Waiting', Colors.grey);
      case AttendanceStatus.onBoard: return _badge('On Board', Colors.green);
      case AttendanceStatus.exited: return _badge('Exited', Colors.blue);
    }
  }

  Widget _badge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      border: Border.all(
        color: color.withValues(alpha: 0.5), // 👈 මේ වරහන සහ කොමාව තිබේදැයි බලන්න
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color.shade700, 
        fontSize: 12, 
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : Column(
            children: [
              // Summary Bar
              _buildSummaryBar(),
              
              if (!widget.isTripActive)
                _buildWarningBanner(),

              // Student List
              Expanded(
                child: _students.isEmpty 
                  ? const Center(child: Text("No students assigned to this van"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _students.length,
                      itemBuilder: (context, index) => _buildStudentCard(_students[index]),
                    ),
              ),
            ],
          ),
    );
  }

  Widget _buildSummaryBar() {
    int onBoardCount = _students.where((s) => s.status == AttendanceStatus.onBoard).length;
    int exitedCount = _students.where((s) => s.status == AttendanceStatus.exited).length;
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryTile('Total', '${_students.length}', Colors.grey),
          _summaryTile('On Board', '$onBoardCount', Colors.green),
          _summaryTile('Exited', '$exitedCount', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.all(10),
      child: const Text(
        '⚠️ Start a trip first to record attendance',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.brown, fontSize: 13),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Card(
      color: _statusColor(student.status),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade700,
                  child: Text(student.name[0], style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(student.grade, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                _statusBadge(student.status),
              ],
            ),
            if (student.boardTime != null || student.exitTime != null)
              _buildTimestamps(student),
            const SizedBox(height: 10),
            if (widget.isTripActive) _buildActionButtons(student),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamps(Student student) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          if (student.boardTime != null)
            Text('🟢 Boarded: ${student.boardTime}', style: const TextStyle(fontSize: 12)),
          if (student.boardTime != null && student.exitTime != null)
            const SizedBox(width: 16),
          if (student.exitTime != null)
            Text('🔵 Exited: ${student.exitTime}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Student student) {
    if (student.status == AttendanceStatus.waiting) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _markBoarded(student),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
          child: const Text('Mark Boarded', style: TextStyle(color: Colors.white)),
        ),
      );
    } else if (student.status == AttendanceStatus.onBoard) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _markExited(student),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
          child: const Text('Mark Exited', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    return const Text('✓ Attendance recorded', style: TextStyle(color: Colors.blueGrey, fontSize: 13));
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade700)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

extension on Color {
  Color get shade700 {
    if (this == Colors.grey) return Colors.grey.shade700;
    if (this == Colors.green) return Colors.green.shade700;
    if (this == Colors.blue) return Colors.blue.shade700;
    return this;
  }
}