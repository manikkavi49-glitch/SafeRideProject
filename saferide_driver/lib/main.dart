import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SafeRideDriverApp());
}

class SafeRideDriverApp extends StatelessWidget {
  const SafeRideDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const DriverScreen(),
    );
  }
}

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("v1/locations/van01");
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  void _toggleTracking() async {
    if (_isTracking) {
      _positionStream?.cancel();
      setState(() => _isTracking = false);
    } else {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        _positionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
        ).listen((Position position) {
          _dbRef.set({
            "lat": position.latitude,
            "lng": position.longitude,
            "lastUpdate": ServerValue.timestamp,
          });
        });
        setState(() => _isTracking = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SafeRide Driver Portal")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 100, color: _isTracking ? Colors.green : Colors.grey),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleTracking,
              style: ElevatedButton.styleFrom(backgroundColor: _isTracking ? Colors.red : Colors.green),
              child: Text(_isTracking ? "STOP TRIP" : "START TRIP"),
            ),
          ],
        ),
      ),
    );
  }
}