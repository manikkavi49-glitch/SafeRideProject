import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _forceUpdateTimer;        // ← periodic force-push even if GPS hasn't moved
  Position? _lastPosition;         // ← cache last known position

  bool get isTracking => _positionStream != null;

  // ── Dynamic vanId from Firebase ───────────────────────────────────────────
  String? _cachedVanId;

  Future<String> _getVanId() async {
    if (_cachedVanId != null) return _cachedVanId!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'van01';
    try {
      final snap = await FirebaseDatabase.instance
          .ref('drivers/${user.uid}')
          .get();
      if (snap.exists) {
        final d = snap.value as Map;
        final v = d['vanId']?.toString() ??
            (d['profile'] as Map?)?['vehicle']?.toString();
        if (v != null && v.isNotEmpty) {
          _cachedVanId = v.toLowerCase();
          return _cachedVanId!;
        }
      }
    } catch (_) {}
    return 'van01';
  }

  void clearCache() => _cachedVanId = null;

  // ── Start tracking ────────────────────────────────────────────────────────
  Future<bool> startTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    final vanId   = await _getVanId();
    final dateStr = _todayStr();
    final tripId  = 'trip_${vanId}_$dateStr';

    final locationRef = FirebaseDatabase.instance.ref('v1/locations/$vanId');
    final tripRef     = FirebaseDatabase.instance.ref('trips/$tripId');

    await tripRef.update({
      'status'    : 'active',
      'vanId'     : vanId,
      'startTime' : ServerValue.timestamp,
    });
    await locationRef.update({
      'isActive'   : true,
      'lastUpdate' : ServerValue.timestamp,
    });

    // ── GPS stream — distanceFilter 0 so EVERY position fires ───────────
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 0,          // ← was 5, now 0 = update on every fix
      ),
    ).listen((Position pos) {
      _lastPosition = pos;
      _pushLocation(locationRef, tripRef, pos);
    });

    // ── Force-push every 5 s even if GPS reports no movement ─────────────
    // Fixes the "only updates on app restart" issue seen in testing
    _forceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastPosition != null) {
        _pushLocation(locationRef, tripRef, _lastPosition!);
      }
    });

    return true;
  }

  void _pushLocation(
    DatabaseReference locationRef,
    DatabaseReference tripRef,
    Position pos,
  ) {
    final speedKmh = (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;

    locationRef.set({
      'lat'        : pos.latitude,
      'lng'        : pos.longitude,
      'speed'      : speedKmh.toStringAsFixed(1),   // km/h string
      'heading'    : pos.heading.toStringAsFixed(1),
      'isActive'   : true,
      'lastUpdate' : ServerValue.timestamp,
    });

    tripRef.update({
      'lat'         : pos.latitude,
      'lng'         : pos.longitude,
      'speed'       : speedKmh,
      'last_update' : ServerValue.timestamp,
    });
  }

  // ── Stop tracking ─────────────────────────────────────────────────────────
  Future<void> stopTracking() async {
    _forceUpdateTimer?.cancel();
    _forceUpdateTimer = null;
    await _positionStream?.cancel();
    _positionStream = null;
    _lastPosition   = null;

    final vanId   = await _getVanId();
    final dateStr = _todayStr();
    final tripId  = 'trip_${vanId}_$dateStr';

    await FirebaseDatabase.instance
        .ref('v1/locations/$vanId')
        .update({'isActive': false, 'lastUpdate': ServerValue.timestamp});

    await FirebaseDatabase.instance.ref('trips/$tripId').update({
      'status'  : 'completed',
      'endTime' : ServerValue.timestamp,
    });
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}'
        '${n.month.toString().padLeft(2, '0')}'
        '${n.day.toString().padLeft(2, '0')}';
  }
}