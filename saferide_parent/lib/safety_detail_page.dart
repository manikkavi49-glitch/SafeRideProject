import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyDetailPage extends StatefulWidget {
  final String studentName;
  final String vanId;
  final String driverId; // ✅ FIX 1: driverId parameter add කළා

  const SafetyDetailPage({
    super.key,
    required this.studentName,
    required this.vanId,
    this.driverId = '', // optional — fallback empty
  });

  @override
  State<SafetyDetailPage> createState() => _SafetyDetailPageState();
}

class _SafetyDetailPageState extends State<SafetyDetailPage> {
  double _speed = 0;
  bool _isDrowsy = false;
  String _studentStatus = "Not in Van";
  bool _isTripActive = false;
  String _driverPhone = "";
  String _driverName = "";

  // ✅ FIX 2: StreamSubscriptions track කරලා dispose() ලදී cancel කිරීමට
  final List<StreamSubscription<DatabaseEvent>> _subs = [];

  // ✅ FIX 3: Today's trip ID dynamically build කිරීම (trip_001 hardcode නොකිරීම)
  String get _todayTripId {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'trip_${widget.vanId}_$date';
  }

  @override
  void initState() {
    super.initState();
    _monitorTripStatus();
    _loadDriverProfile();
  }

  @override
  void dispose() {
    // ✅ FIX 2: සියලු listeners cancel කිරීම — memory leak නෑ
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  // ── Trip active status monitor ────────────────────────────────────────────
  void _monitorTripStatus() {
    // ✅ FIX 4: trips/trip_{vanId}_{date} direct path use — orderByChild bug fix
    final tripRef = FirebaseDatabase.instance.ref('trips/$_todayTripId');

    final sub = tripRef.onValue.listen((event) {
      if (!mounted) return;
      final val = event.snapshot.value;
      bool active = false;

      if (val is Map) {
        active = val['status']?.toString() == 'active';
      }

      final wasActive = _isTripActive;
      setState(() => _isTripActive = active);

      // Start safety listeners only when trip becomes active
      if (active && !wasActive) {
        _startSafetyListeners();
      }
    });

    _subs.add(sub);
  }

  // ── Load driver profile (phone, name) ────────────────────────────────────
  void _loadDriverProfile() {
    if (widget.driverId.isEmpty) return;

    final driverRef =
        FirebaseDatabase.instance.ref('drivers/${widget.driverId}/profile');

    final sub = driverRef.onValue.listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      setState(() {
        _driverPhone = data['phone']?.toString() ?? '';
        _driverName  = data['name']?.toString()  ?? '';
      });
    });

    _subs.add(sub);
  }

  // ── Safety listeners (speed + drowsy + attendance) ────────────────────────
  void _startSafetyListeners() {
    // 1. Speed (m/s → km/h)
    final locationSub = FirebaseDatabase.instance
        .ref('v1/locations/${widget.vanId}')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final rawSpeed =
          double.tryParse(data['speed']?.toString() ?? '0') ?? 0;
      setState(() => _speed = rawSpeed * 3.6);
    });
    _subs.add(locationSub);

    // 2. Drowsiness alert
    final safetySub = FirebaseDatabase.instance
        .ref('v1/alerts/${widget.vanId}')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      setState(() => _isDrowsy = data['isDrowsy'] == true);
    });
    _subs.add(safetySub);

    // 3. Student attendance — ✅ FIX 3: dynamic trip ID use
    final attendanceSub = FirebaseDatabase.instance
        .ref('attendance/$_todayTripId')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      String status = 'Not in Van';

      data.forEach((key, value) {
        if (value is Map) {
          final name = value['name']?.toString().toLowerCase().trim() ?? '';
          if (name == widget.studentName.toLowerCase().trim()) {
            status = value['status']?.toString() == 'onBoard'
                ? 'Inside the Van'
                : 'Dropped Off';
          }
        }
      });

      setState(() => _studentStatus = status);
    });
    _subs.add(attendanceSub);
  }

  // ── Phone call ────────────────────────────────────────────────────────────
  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open phone dialer')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final headerColor = !_isTripActive
        ? Colors.grey
        : (_isDrowsy ? Colors.red.shade700 : Colors.green.shade700);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("${widget.studentName}'s Safety"),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !_isTripActive ? _buildWaitingView() : _buildSafetyDashboard(),
    );
  }

  // ── Waiting view ──────────────────────────────────────────────────────────
  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bus_alert_rounded, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text(
            'Trip Not Active',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Trip ID: $_todayTripId',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 4),
          const Text(
            'Safety data will appear once the trip starts.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Safety dashboard ──────────────────────────────────────────────────────
  Widget _buildSafetyDashboard() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: _isDrowsy ? Colors.red.shade700 : Colors.green.shade700,
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isDrowsy
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user,
                  size:  80,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  _isDrowsy ? 'DRIVER DROWSY ALERT' : 'SAFE TRIP ACTIVE',
                  style: const TextStyle(
                      fontSize:   22,
                      fontWeight: FontWeight.bold,
                      color:      Colors.white),
                ),
                if (_driverName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Driver: $_driverName',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoCard(
                  'Student Status',
                  _studentStatus,
                  _studentStatusIcon(),
                  _studentStatusColor(),
                ),
                _buildInfoCard(
                  'Vehicle Speed',
                  '${_speed.toStringAsFixed(1)} km/h',
                  Icons.speed,
                  _speed > 80 ? Colors.red : Colors.orange,
                ),
                _buildInfoCard(
                  'Driver Alertness',
                  _isDrowsy ? 'Attention Needed ⚠️' : 'Optimal ✅',
                  Icons.psychology,
                  _isDrowsy ? Colors.red : Colors.green,
                ),

                const SizedBox(height: 30),

                // Call driver button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_driverPhone.isNotEmpty) {
                        _makePhoneCall(_driverPhone);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Driver's contact not available.")),
                        );
                      }
                    },
                    icon:  const Icon(Icons.call),
                    label: Text(
                      _driverPhone.isNotEmpty
                          ? 'Call Driver  $_driverPhone'
                          : 'Call Driver',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Trip ID debug chip
                Chip(
                  label: Text(
                    'Trip: $_todayTripId',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _studentStatusIcon() {
    switch (_studentStatus) {
      case 'Inside the Van': return Icons.airline_seat_recline_normal;
      case 'Dropped Off':    return Icons.home_rounded;
      default:               return Icons.person_pin_circle;
    }
  }

  Color _studentStatusColor() {
    switch (_studentStatus) {
      case 'Inside the Van': return Colors.blue;
      case 'Dropped Off':    return Colors.green;
      default:               return Colors.grey;
    }
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(15),
        border:       Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 15, color: Colors.black54)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
        ],
      ),
    );
  }
}