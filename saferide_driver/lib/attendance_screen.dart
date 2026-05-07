import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart'; // ✅ FIX: GPS import

// ── Student model ──────────────────────────────────────────────────────────────
class Student {
  final String id;
  final String name;
  final String grade;
  final String parentEmail;
  AttendanceStatus status;
  String? boardTime;
  String? exitTime;

  Student({
    required this.id,
    required this.name,
    required this.grade,
    required this.parentEmail,
    this.status = AttendanceStatus.waiting,
    this.boardTime,
    this.exitTime,
  });

  factory Student.fromMap(String id, Map data) {
    return Student(
      id:          id,
      name:        data['name']?.toString()        ?? 'Unknown',
      grade:       data['grade']?.toString()       ?? '',
      parentEmail: data['parentEmail']?.toString() ?? '',
    );
  }
}

enum AttendanceStatus { waiting, onBoard, exited }

// ── Screen ─────────────────────────────────────────────────────────────────────
class AttendanceScreen extends StatefulWidget {
  final bool isTripActive;
  const AttendanceScreen({super.key, required this.isTripActive});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController gradeCtrl = TextEditingController();
  final TextEditingController parentEmailCtrl = TextEditingController();

  List<Student> _students  = [];
  bool          _isLoading = true;
  bool          _isSaving  = false;
  String?       _vanId;

  // Stable trip ID for the day: trip_{vanId}_{YYYYMMDD}
  String get _todayTripId {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'trip_${_vanId ?? 'van01'}_$date';
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(AttendanceScreen old) {
    super.didUpdateWidget(old);
    if (widget.isTripActive && !old.isTripActive) {
      _resetAttendance();
      _writeTripRecord();
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    gradeCtrl.dispose();
    parentEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadVanId();
    await _fetchStudents();
    if (widget.isTripActive) await _restoreAttendance();
  }

  // ── Load vanId from driver profile ──────────────────────────────────────────
  Future<void> _loadVanId() async {
    if (_user == null) return;
    try {
      final snap =
          await FirebaseDatabase.instance.ref('drivers/${_user!.uid}').get();
      if (snap.exists) {
        final d = snap.value as Map;
        _vanId = d['vanId']?.toString() ??
            (d['profile'] as Map?)?['vehicle']?.toString() ??
            'van01';
      }
    } catch (_) {
      _vanId = 'van01';
    }
  }

  // ── Fetch students assigned to this driver ───────────────────────────────────
  Future<void> _fetchStudents() async {
    if (_user == null) return;
    setState(() => _isLoading = true);

    try {
      final snap = await FirebaseDatabase.instance
          .ref('drivers/${_user!.uid}/students')
          .get();

      final loaded = <Student>[];
      if (snap.exists) {
        final data = snap.value as Map;
        data.forEach((key, val) {
          if (val is Map) loaded.add(Student.fromMap(key.toString(), val));
        });
        loaded.sort((a, b) => a.name.compareTo(b.name));
      }

      if (mounted) setState(() { _students = loaded; _isLoading = false; });
    } catch (e) {
      debugPrint('Fetch students error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Restore today's attendance from Firebase ─────────────────────────────────
  Future<void> _restoreAttendance() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('attendance/$_todayTripId')
          .get();
      if (!snap.exists) return;

      final data = snap.value as Map;
      if (mounted) {
        setState(() {
          for (final s in _students) {
            final rec = data[s.id] as Map?;
            if (rec == null) continue;
            final status = rec['status']?.toString() ?? 'waiting';
            if (status == 'onBoard') {
              s.status    = AttendanceStatus.onBoard;
              s.boardTime = rec['boardTime']?.toString();
            } else if (status == 'exited') {
              s.status    = AttendanceStatus.exited;
              s.boardTime = rec['boardTime']?.toString();
              s.exitTime  = rec['exitTime']?.toString();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Restore attendance error: $e');
    }
  }

  void _resetAttendance() {
    for (final s in _students) {
      s.status    = AttendanceStatus.waiting;
      s.boardTime = null;
      s.exitTime  = null;
    }
  }

  Future<void> _writeTripRecord() async {
    try {
      await FirebaseDatabase.instance.ref('trips/$_todayTripId').set({
        'vanId'     : _vanId,
        'driverId'  : _user?.uid,
        'status'    : 'active',
        'startTime' : ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Trip record error: $e');
    }
  }

  // ✅ FIX: Helper to get current GPS position safely
  Future<Position?> _getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('GPS error: $e');
      return null;
    }
  }

  // ✅ FIX: Mark boarded — NOW saves boardLat + boardLng
  Future<void> _markBoarded(Student student) async {
    final time = _timeNow();
    setState(() { student.status = AttendanceStatus.onBoard; student.boardTime = time; });
    try {
      // Get GPS coordinates at the moment of boarding
      final Position? pos = await _getCurrentPosition();

      await FirebaseDatabase.instance
          .ref('attendance/$_todayTripId/${student.id}')
          .update({
        'name'           : student.name,
        'grade'          : student.grade,
        'parentEmail'    : student.parentEmail,
        'status'         : 'onBoard',
        'boardTime'      : time,
        'boardTimestamp' : ServerValue.timestamp,
        'tripId'         : _todayTripId,
        'vanId'          : _vanId,
        // ✅ GPS coordinates — parent map will show green marker here
        if (pos != null) 'boardLat' : pos.latitude,
        if (pos != null) 'boardLng' : pos.longitude,
      });
    } catch (e) {
      setState(() { student.status = AttendanceStatus.waiting; student.boardTime = null; });
      _snack('Save failed. Try again.', Colors.red);
    }
  }

  // ✅ FIX: Mark exited — NOW saves exitLat + exitLng
  Future<void> _markExited(Student student) async {
    final time = _timeNow();
    setState(() { student.status = AttendanceStatus.exited; student.exitTime = time; });
    try {
      // Get GPS coordinates at the moment of exit
      final Position? pos = await _getCurrentPosition();

      await FirebaseDatabase.instance
          .ref('attendance/$_todayTripId/${student.id}')
          .update({
        'status'        : 'exited',
        'exitTime'      : time,
        'exitTimestamp' : ServerValue.timestamp,
        // ✅ GPS coordinates — parent map will show blue marker here
        if (pos != null) 'exitLat' : pos.latitude,
        if (pos != null) 'exitLng' : pos.longitude,
      });
    } catch (e) {
      setState(() { student.status = AttendanceStatus.onBoard; student.exitTime = null; });
      _snack('Save failed. Try again.', Colors.red);
    }
  }

  // ── Add Student Dialog ─────────────────────────────────────────────────────
  void _showAddStudentDialog() {
    nameCtrl.clear();
    gradeCtrl.clear();
    parentEmailCtrl.clear();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 24, left: 20, right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_add, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Student',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Student data will be linked to the parent via their email.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                _dialogField(
                  controller: nameCtrl,
                  label: 'Student Full Name',
                  icon: Icons.badge_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: gradeCtrl,
                  label: 'Grade / Class',
                  icon: Icons.school_outlined,
                  hint: 'e.g. Grade 7',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _dialogField(
                  controller: parentEmailCtrl,
                  label: "Parent's Email Address",
                  icon: Icons.email_outlined,
                  hint: 'Must match parent app login email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The parent must register in the Parent App using this exact email.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setLocal(() => _isSaving = true);
                            setState(() => _isSaving = true);

                            final name        = nameCtrl.text.trim();
                            final grade       = gradeCtrl.text.trim();
                            final parentEmail = parentEmailCtrl.text.trim().toLowerCase();
                            final studentId =
                                'stu_${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

                            try {
                              await FirebaseDatabase.instance
                                  .ref('drivers/${_user!.uid}/students/$studentId')
                                  .set({
                                'name'        : name,
                                'grade'       : grade,
                                'parentEmail' : parentEmail,
                                'vanId'       : _vanId ?? 'van01',
                                'driverId'    : _user!.uid,
                                'addedAt'     : ServerValue.timestamp,
                              });
                              await FirebaseDatabase.instance
                                  .ref('students/$studentId')
                                  .set({
                                'name'        : name,
                                'grade'       : grade,
                                'parentEmail' : parentEmail,
                                'vanId'       : _vanId ?? 'van01',
                                'driverId'    : _user!.uid,
                                'addedAt'     : ServerValue.timestamp,
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              await _fetchStudents();
                              _snack('✅ $name added successfully!', Colors.green);
                            } catch (e) {
                              _snack('Failed to add student: $e', Colors.red);
                            }
                            setLocal(() => _isSaving = false);
                            setState(() => _isSaving = false);
                          },
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Add Student',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete student ────────────────────────────────────────────────────────────
  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Student?'),
        content: Text(
            'Remove ${student.name} from your manifest? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseDatabase.instance
          .ref('drivers/${_user!.uid}/students/${student.id}')
          .remove();
      await FirebaseDatabase.instance
          .ref('students/${student.id}')
          .remove();
      await _fetchStudents();
      _snack('${student.name} removed.', Colors.orange);
    } catch (e) {
      _snack('Remove failed: $e', Colors.red);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _timeNow() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  int get _onBoardCount =>
      _students.where((s) => s.status == AttendanceStatus.onBoard).length;
  int get _exitedCount =>
      _students.where((s) => s.status == AttendanceStatus.exited).length;
  int get _waitingCount =>
      _students.where((s) => s.status == AttendanceStatus.waiting).length;

  Color _cardColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.waiting:  return Colors.grey.shade100;
      case AttendanceStatus.onBoard:  return Colors.green.shade50;
      case AttendanceStatus.exited:   return Colors.blue.shade50;
    }
  }

  Widget _statusBadge(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.waiting:
        return _badge('Waiting', Colors.grey.shade600);
      case AttendanceStatus.onBoard:
        return _badge('On Board', Colors.green.shade700);
      case AttendanceStatus.exited:
        return _badge('Exited', Colors.blue.shade700);
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
        filled: true,
        fillColor: Colors.green.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade600, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildQuickActionButton(Student student) {
    if (student.status == AttendanceStatus.exited) return const SizedBox.shrink();

    bool isWaiting = student.status == AttendanceStatus.waiting;

    return IconButton(
      onPressed: isWaiting
          ? () => _markBoarded(student)
          : () => _markExited(student),
      style: IconButton.styleFrom(
        backgroundColor: isWaiting ? Colors.green.shade600 : Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(40, 40),
      ),
      icon: Icon(
        isWaiting ? Icons.login_rounded : Icons.logout_rounded,
        size: 20,
      ),
      tooltip: isWaiting ? 'Mark Boarded' : 'Mark Exited',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryTile('Total',    '${_students.length}', Colors.grey.shade700),
                _summaryTile('Waiting',  '$_waitingCount',      Colors.orange.shade700),
                _summaryTile('On Board', '$_onBoardCount',      Colors.green.shade700),
                _summaryTile('Exited',   '$_exitedCount',       Colors.blue.shade700),
              ],
            ),
          ),
          const Divider(height: 1),
          if (widget.isTripActive)
            Container(
              width: double.infinity,
              color: Colors.green.shade50,
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.directions_bus,
                      size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Trip: $_todayTripId',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 12),
                    Text('Loading students...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_students.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No students added yet',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap + to add your first student',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showAddStudentDialog,
                      icon: const Icon(Icons.person_add,
                          color: Colors.white),
                      label: const Text('Add Student',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchStudents,
                color: Colors.green,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return _buildStudentCard(student);
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Add Student',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Dismissible(
      key: Key(student.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(height: 4),
            Text('Remove', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteStudent(student);
        return false;
      },
      child: Card(
        color: _cardColor(student.status),
        margin: const EdgeInsets.only(bottom: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      student.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Row(
                          children: [
                            if (student.grade.isNotEmpty)
                              Text(student.grade,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                            if (student.parentEmail.isNotEmpty) ...[
                              Text(' · ',
                                  style: TextStyle(
                                      color: Colors.grey.shade400)),
                              Icon(Icons.link,
                                  size: 12,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  student.parentEmail,
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.isTripActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildQuickActionButton(student),
                    ),
                  _statusBadge(student.status),
                ],
              ),
              if (student.boardTime != null || student.exitTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Wrap(
                    spacing: 16,
                    children: [
                      if (student.boardTime != null)
                        Text('🟢 Boarded: ${student.boardTime}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      if (student.exitTime != null)
                        Text('🔵 Exited: ${student.exitTime}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
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
                                borderRadius: BorderRadius.circular(8)),
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
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    if (student.status == AttendanceStatus.exited)
                      const Expanded(
                        child: Center(
                          child: Text('✓ Attendance recorded',
                              style: TextStyle(
                                  color: Colors.blueGrey, fontSize: 13)),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
