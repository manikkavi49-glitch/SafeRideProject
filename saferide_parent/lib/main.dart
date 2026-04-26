import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Your local page imports
import 'splash_screen.dart';
import 'login_page.dart';
import 'navigation_menu.dart';
import 'register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDMmTpVj-sAc7RnPFVHaqp2e_6vFY9BUwg",
      appId: "1:116790427666:android:a8ab2bb963e9c33b7498cb",
      messagingSenderId: "116790427666",
      projectId: "saferide-g5",
      databaseURL: "https://saferide-g5-default-rtdb.firebaseio.com",
      storageBucket: "saferide-g5.firebasestorage.app",
    ),
  );

  runApp(const SafeRideParentApp());
}

class SafeRideParentApp extends StatelessWidget {
  const SafeRideParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeRide Parent',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      // The app starts at the Splash Screen
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        // This is the "Gatekeeper" that checks if user is logged in
        '/gatekeeper': (context) => const AuthWrapper(), 
        '/register': (context) => const RegisterPage(),
        '/login_page': (context) => const LoginPage(), // Direct access if needed
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
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
      debugPrint("Firebase Error: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loader while Firebase checks the login status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, take them to the Dashboard (NavigationMenu)
        if (snapshot.hasData) {
          return const NavigationMenu();
        } 
        
        // If not logged in, take them to the Login Page
        return const LoginPage();
      },
    );
  }
}