import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParentMapScreen extends StatefulWidget {
  // 1. Accept the vanId from the Dashboard
  final String vanId; 

  const ParentMapScreen({super.key, required this.vanId});

  @override
  State<ParentMapScreen> createState() => _ParentMapScreenState();
}

class _ParentMapScreenState extends State<ParentMapScreen> {
  // Default to Colombo center
  LatLng _busPos = const LatLng(6.9271, 79.8612); 
  GoogleMapController? _mapController;
  
  // 2. Late initialization for the database reference using the dynamic ID
  late final DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    // Use the vanId passed from the dashboard to point to the correct node
    _dbRef = FirebaseDatabase.instance.ref("v1/locations/${widget.vanId}");
    _listenToBusLocation();
  }

  void _listenToBusLocation() {
    _dbRef.onValue.listen((event) {
      final dynamic rawData = event.snapshot.value;
      
      if (rawData != null && rawData is Map) {
        // Checking for 'lat' or 'latitude' to handle different driver app formats
        final double? lat = (rawData['lat'] ?? rawData['latitude'])?.toDouble();
        final double? lng = (rawData['lng'] ?? rawData['longitude'])?.toDouble();

        if (lat != null && lng != null) {
          final newPos = LatLng(lat, lng);
          
          if (mounted) {
            setState(() {
              _busPos = newPos;
            });

            // Smoothly move the camera to the new position as the driver moves
            _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _busPos, zoom: 16),
              ),
            );
          }
        }
      }
    }, onError: (error) {
      debugPrint("Firebase Permission or Path Error: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Shows which van is currently being tracked in the title
        title: Text("Tracking: ${widget.vanId}"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: CameraPosition(target: _busPos, zoom: 15),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false, 
        markers: {
          Marker(
            markerId: const MarkerId("van_marker"),
            position: _busPos,
            // Orange hue makes the school van stand out from normal traffic
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: "SafeRide Van: ${widget.vanId}",
              snippet: "Real-time location active",
            ),
          ),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green.shade800,
        onPressed: () {
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_busPos, 17));
        },
        label: const Text("Locate Van"),
        icon: const Icon(Icons.directions_bus, color: Colors.white),
      ),
    );
  }
}