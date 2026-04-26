import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class StatusScreen extends StatefulWidget {
  final bool isTripActive;
  const StatusScreen({super.key, required this.isTripActive});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final DatabaseReference _locationRef =
      FirebaseDatabase.instance.ref("v1/locations/van01");
  final DatabaseReference _safetyRef =
      FirebaseDatabase.instance.ref("safety_status");
  final DatabaseReference _attendanceRef =
      FirebaseDatabase.instance.ref("attendance/trip_001");

  StreamSubscription<DatabaseEvent>? _locationSub;
  StreamSubscription<DatabaseEvent>? _safetySub;
  StreamSubscription<DatabaseEvent>? _attendanceSub;

  // Live data
  double _speed = 0;
  double _lat = 0;
  double _lng = 0;
  String _lastUpdate = '--';
  bool _isDrowsy = false;
  String _lastAlert = '';
  int _studentsOnBoard = 0;
  int _studentsExited = 0;

  // Trip timer
  DateTime? _tripStart;
  Timer? _timer;
  String _elapsed = '00:00:00';

  @override
  void initState() {
    super.initState();
    _startListeners();
    if (widget.isTripActive) _startTimer();
  }

  @override
  void didUpdateWidget(StatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTripActive && !oldWidget.isTripActive) {
      _tripStart = DateTime.now();
      _startTimer();
    } else if (!widget.isTripActive && oldWidget.isTripActive) {
      _timer?.cancel();
      setState(() => _elapsed = '00:00:00');
    }
  }

  void _startTimer() {
    _tripStart ??= DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = DateTime.now().difference(_tripStart!);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      if (mounted) setState(() => _elapsed = '$h:$m:$s');
    });
  }

  void _startListeners() {
    _locationSub = _locationRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        final now = DateTime.now();
        setState(() {
          _speed = double.tryParse(data['speed']?.toString() ?? '0') ?? 0;
          _lat = (data['lat'] as num?)?.toDouble() ?? 0;
          _lng = (data['lng'] as num?)?.toDouble() ?? 0;
          _lastUpdate =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        });
      }
    });

    _safetySub = _safetyRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        setState(() {
          _isDrowsy = data['isDrowsy'] == true;
          _lastAlert = data['lastAlert']?.toString() ?? '';
        });
      }
    });

    _attendanceSub = _attendanceRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      int onBoard = 0, exited = 0;
      data.forEach((_, v) {
        if (v is Map) {
          if (v['status'] == 'onBoard') onBoard++;
          if (v['status'] == 'exited') exited++;
        }
      });
      if (mounted) {
        setState(() {
        _studentsOnBoard = onBoard;
        _studentsExited = exited;
      });
      }
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _safetySub?.cancel();
    _attendanceSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // Convert m/s to km/h
  String get _speedKmh => '${(_speed * 3.6).toStringAsFixed(0)} km/h';
  bool get _isOverSpeed => _speed * 3.6 > 60;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Status')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Trip active indicator
            _StatusCard(
              icon: widget.isTripActive
                  ? Icons.radio_button_on
                  : Icons.radio_button_off,
              iconColor:
                  widget.isTripActive ? Colors.green : Colors.grey,
              title: widget.isTripActive ? 'Trip Active' : 'No Active Trip',
              subtitle: widget.isTripActive
                  ? 'Elapsed: $_elapsed'
                  : 'Start a trip from the Home screen',
              backgroundColor: widget.isTripActive
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
            ),
            const SizedBox(height: 12),

            // Speed
            _StatusCard(
              icon: Icons.speed,
              iconColor: _isOverSpeed ? Colors.red : Colors.blue,
              title: 'Current Speed',
              subtitle: widget.isTripActive
                  ? (_isOverSpeed
                      ? '$_speedKmh  ⚠️ Over Speed Limit (60 km/h)'
                      : _speedKmh)
                  : '--',
              backgroundColor: _isOverSpeed
                  ? Colors.red.shade50
                  : Colors.blue.shade50,
            ),
            const SizedBox(height: 12),

            // Location
            _StatusCard(
              icon: Icons.location_on,
              iconColor: Colors.orange,
              title: 'Last Known Location',
              subtitle: widget.isTripActive && _lat != 0
                  ? '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}\nUpdated: $_lastUpdate'
                  : 'Not available',
              backgroundColor: Colors.orange.shade50,
            ),
            const SizedBox(height: 12),

            // Safety status
            _StatusCard(
              icon: _isDrowsy
                  ? Icons.warning_amber_rounded
                  : Icons.verified_user,
              iconColor: _isDrowsy ? Colors.red : Colors.green,
              title: 'Driver Safety',
              subtitle: _isDrowsy
                  ? 'ALERT: $_lastAlert'
                  : 'Status: Alert & Focused',
              backgroundColor:
                  _isDrowsy ? Colors.red.shade50 : Colors.green.shade50,
            ),
            const SizedBox(height: 12),

            // Students
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    // ✅ මේ විදිහට වෙනස් කරන්න:
color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.people, color: Colors.purple),
                      SizedBox(width: 10),
                      Text(
                        'Student Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat('On Board', '$_studentsOnBoard',
                          Colors.green.shade700),
                      _miniStat(
                          'Exited', '$_studentsExited', Colors.blue.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color backgroundColor;

  const _StatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
