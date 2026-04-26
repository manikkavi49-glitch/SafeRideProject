import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final DatabaseReference _locationRef =
      FirebaseDatabase.instance.ref("v1/locations/van01");
  final DatabaseReference _tripRef =
      FirebaseDatabase.instance.ref("trips/trip_001");

  StreamSubscription<Position>? _positionStream;
  bool get isTracking => _positionStream != null;

  Future<bool> startTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    // Write trip start to Firebase
    await _tripRef.update({
      'status': 'active',
      'startTime': ServerValue.timestamp,
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      // Push coords + speed + heading to Firebase
      _locationRef.set({
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed.toStringAsFixed(1),   // m/s
        'heading': position.heading.toStringAsFixed(1),
        'lastUpdate': ServerValue.timestamp,
      });

      // Also keep trip telemetry updated
      _tripRef.update({
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed,
        'last_update': ServerValue.timestamp,
      });
    });

    return true;
  }

  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;

    // Mark location as inactive
    await _locationRef.update({'isActive': false});
    await _tripRef.update({
      'status': 'completed',
      'endTime': ServerValue.timestamp,
    });
  }
}
