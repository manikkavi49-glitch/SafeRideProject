import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SafeRideParentApp());
}

class SafeRideParentApp extends StatelessWidget {
  const SafeRideParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const ParentMapScreen(),
    );
  }
}

class ParentMapScreen extends StatefulWidget {
  const ParentMapScreen({super.key});

  @override
  State<ParentMapScreen> createState() => _ParentMapScreenState();
}

class _ParentMapScreenState extends State<ParentMapScreen> {
  // Default position eka Colombo (6.9271, 79.8612)
  LatLng _busPos = const LatLng(6.9271, 79.8612); 
  GoogleMapController? _mapController;
  
  // Firebase reference eka hariyatama image eke thibuna path ekata
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("v1/locations/van01");

  @override
  void initState() {
    super.initState();
    _listenToBusLocation();
  }

  void _listenToBusLocation() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        // Data types double walata cast kirima
        double lat = (data['lat'] as num).toDouble();
        double lng = (data['lng'] as num).toDouble();

        setState(() {
          _busPos = LatLng(lat, lng);
        });

        // Bus eka move weddi Map Camera ekath bus eka passhen yanawa
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_busPos),
        );
      }
    }, onError: (error) {
      print("Firebase Error: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SafeRide - School Van Tracker"),
        backgroundColor: Colors.green.shade100,
        centerTitle: true,
      ),
      body: GoogleMap(
        // Map eka create unama controller eka ganna
        onMapCreated: (controller) => _mapController = controller,
        initialCameraPosition: CameraPosition(target: _busPos, zoom: 15),
        markers: {
          Marker(
            markerId: const MarkerId("van"),
            position: _busPos,
            // Marker eka Orange (Yellowish) karamu
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: const InfoWindow(
              title: "SafeRide School Van",
              snippet: "Live Tracking Active",
            ),
          ),
        },
      ),
      // Floating button ekak damma ayeth bus eka thiyena thanata camera eka ganna
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController?.animateCamera(CameraUpdate.newLatLng(_busPos));
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}