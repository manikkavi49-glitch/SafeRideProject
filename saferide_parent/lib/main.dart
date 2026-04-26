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