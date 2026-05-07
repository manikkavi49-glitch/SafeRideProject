import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'services/database_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final DatabaseService _db    = DatabaseService();
  final User?           _user  = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyChildren();
  }

  Future<void> _loadMyChildren() async {
    if (_user == null) return;
    setState(() => _isLoading = true);

    // FIX: Removed unnecessary '!'
    final email    = _user.email ?? '';
    final children = await _db.getStudentsByParentEmail(email);

    if (mounted) {
      setState(() {
        _children  = children;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Children'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyChildren,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _children.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _children.length,
                  itemBuilder: (context, index) =>
                      _ChildAttendanceCard(
                        child: _children[index],
                        db:    _db,
                      ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.child_care, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No children linked yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your child\'s driver will add them using your registered email:\n\n${_user?.email ?? ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Once the driver adds your child with this email, they will appear here automatically.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadMyChildren,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                side: BorderSide(color: Colors.green.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildAttendanceCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final DatabaseService      db;

  const _ChildAttendanceCard({required this.child, required this.db});

  @override
  Widget build(BuildContext context) {
    final studentId = child['id']  as String;
    final vanId     = child['vanId'] as String? ?? 'van01';
    final name      = child['name']  as String? ?? 'Unknown';
    final grade     = child['grade'] as String? ?? '';

    return StreamBuilder<DatabaseEvent>(
      stream: db.getTodayAttendance(vanId, studentId),
      builder: (context, snapshot) {
        String status    = 'waiting';
        String boardTime = '--:--';
        String exitTime  = '--:--';

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map;
          status    = data['status']?.toString()    ?? 'waiting';
          boardTime = data['boardTime']?.toString()  ?? '--:--';
          exitTime  = data['exitTime']?.toString()   ?? '--:--';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _headerColor(status),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                            color: _iconColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          if (grade.isNotEmpty)
                            Text(grade,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _timelineRow(
                      icon: Icons.login_rounded,
                      color: Colors.green,
                      label: 'Boarded Van',
                      time: boardTime,
                      done: status == 'onBoard' || status == 'exited',
                    ),
                    const SizedBox(height: 12),
                    _timelineRow(
                      icon: Icons.logout_rounded,
                      color: Colors.orange,
                      label: 'Dropped Off',
                      time: exitTime,
                      done: status == 'exited',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_bus,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Van: $vanId  ·  Today',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _headerColor(String status) {
    switch (status) {
      case 'onBoard': return Colors.green.shade600;
      case 'exited':  return Colors.blue.shade600;
      default:        return Colors.grey.shade500;
    }
  }

  Color _iconColor(String status) {
    switch (status) {
      case 'onBoard': return Colors.green.shade600;
      case 'exited':  return Colors.blue.shade600;
      default:        return Colors.grey.shade500;
    }
  }

  Widget _statusChip(String status) {
    String label;
    Color  bg;
    switch (status) {
      case 'onBoard':
        label = '🚌 On Board'; bg = Colors.white24; break;
      case 'exited':
        label = '✅ Arrived';  bg = Colors.white24; break;
      default:
        label = '⏳ Waiting';  bg = Colors.white24;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _timelineRow({
    required IconData icon,
    required Color    color,
    required String   label,
    required String   time,
    required bool     done,
  }) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: done ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: 20, color: done ? color : Colors.grey.shade400),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: done ? Colors.black87 : Colors.grey.shade500)),
        ),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: done ? color : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}