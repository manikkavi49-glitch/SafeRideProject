import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Represents a student in the transport manifest
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
}

enum AttendanceStatus { waiting, onBoard, exited }

class AttendanceScreen extends StatefulWidget {
  final bool isTripActive;
  const AttendanceScreen({super.key, required this.isTripActive});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseReference _attendanceRef =
      FirebaseDatabase.instance.ref("attendance/trip_001");

  // Sample manifest — in production, load from Firebase /students
  final List<Student> _students = [
    Student(id: 'stu_001', name: 'Ashan Perera', grade: 'Grade 7'),
    Student(id: 'stu_002', name: 'Nimaya Silva', grade: 'Grade 8'),
    Student(id: 'stu_003', name: 'Kavindi Rajapaksa', grade: 'Grade 6'),
    Student(id: 'stu_004', name: 'Dulith Fernando', grade: 'Grade 9'),
    Student(id: 'stu_005', name: 'Sithara Wijeratne', grade: 'Grade 7'),
  ];

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
    await _attendanceRef.child(student.id).update({
      'name': student.name,
      'grade': student.grade,
      'status': 'onBoard',
      'boardTime': time,
      'boardTimestamp': ServerValue.timestamp,
    });
  }

  Future<void> _markExited(Student student) async {
    final time = _now();
    setState(() {
      student.status = AttendanceStatus.exited;
      student.exitTime = time;
    });
    await _attendanceRef.child(student.id).update({
      'status': 'exited',
      'exitTime': time,
      'exitTimestamp': ServerValue.timestamp,
    });
  }

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.waiting:
        return Colors.grey.shade200;
      case AttendanceStatus.onBoard:
        return Colors.green.shade50;
      case AttendanceStatus.exited:
        return Colors.blue.shade50;
    }
  }

  Widget _statusBadge(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.waiting:
        return _badge('Waiting', Colors.grey);
      case AttendanceStatus.onBoard:
        return _badge('On Board', Colors.green);
      case AttendanceStatus.exited:
        return _badge('Exited', Colors.blue);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color.shade700, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  int get _onBoardCount =>
      _students.where((s) => s.status == AttendanceStatus.onBoard).length;
  int get _exitedCount =>
      _students.where((s) => s.status == AttendanceStatus.exited).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Attendance')),
      body: Column(
        children: [
          // Summary bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryTile('Total', '${_students.length}', Colors.grey),
                _summaryTile('On Board', '$_onBoardCount', Colors.green),
                _summaryTile('Exited', '$_exitedCount', Colors.blue),
              ],
            ),
          ),
          const Divider(height: 1),

          if (!widget.isTripActive)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(10),
              child: const Text(
                '⚠️  Start a trip first to record attendance',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.brown, fontSize: 13),
              ),
            ),

          // Student list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Card(
                  color: _statusColor(student.status),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.green.shade700,
                              child: Text(
                                student.name[0],
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    student.grade,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            _statusBadge(student.status),
                          ],
                        ),

                        // Timestamps
                        if (student.boardTime != null ||
                            student.exitTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Row(
                              children: [
                                if (student.boardTime != null)
                                  Text(
                                    '🟢 Boarded: ${student.boardTime}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                if (student.boardTime != null &&
                                    student.exitTime != null)
                                  const SizedBox(width: 16),
                                if (student.exitTime != null)
                                  Text(
                                    '🔵 Exited: ${student.exitTime}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 10),

                        // Action buttons
                        if (widget.isTripActive)
                          Row(
                            children: [
                              if (student.status == AttendanceStatus.waiting)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _markBoarded(student),
                                    icon: const Icon(Icons.login, size: 18),
                                    label: const Text('Mark Boarded'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              if (student.status == AttendanceStatus.onBoard)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _markExited(student),
                                    icon: const Icon(Icons.logout, size: 18),
                                    label: const Text('Mark Exited'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              if (student.status == AttendanceStatus.exited)
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      '✓ Attendance recorded',
                                      style: TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color.shade700)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
