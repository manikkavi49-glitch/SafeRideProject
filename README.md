======================================================================
   SAFERIDE: REAL-TIME TRANSPORT TRACKING & AI SAFETY SYSTEM
   GROUP 05 - BATCH 77 | PROJECT DOCUMENTATION & SETUP GUIDE
======================================================================

1. PROJECT OVERVIEW
----------------------------------------------------------------------
SafeRide is a dual-app ecosystem built with Flutter and Firebase. 
The goal is to provide real-time GPS tracking for school vans and 
utilize AI (Computer Vision) to monitor driver fatigue (Drowsiness).

2. TEAM ROLES & ASSIGNMENTS
----------------------------------------------------------------------
* KAVI (Project Lead): 
  - AI Drowsiness Engine (EAR Algorithm) 
  - Real-time GPS Telemetry Logic
  - Repository Management

* LOCHI: 
  - Parent App: Login Screen UI & Firebase Auth Logic

* GAYU: 
  - Parent App: Registration/Signup UI & Firestore User Profiling

* NIMNAKA: 
  - Driver App: Login Screen UI & Firebase Auth Logic

* NIPUNA: 
  - Driver App: Registration/Signup UI & Vehicle Data Integration

3. INITIAL ENVIRONMENT SETUP
----------------------------------------------------------------------
Before coding, ensure your PC is ready:
1. Install Flutter SDK (3.10 or higher).
2. Install Git (git-scm.com).
3. Clone the Repository:
   Open terminal and run: 
   git clone https://github.com/manikkavi49-glitch/SafeRideProject.git

4. FIREBASE CONFIGURATION (CRITICAL)
----------------------------------------------------------------------
You MUST have the 'google-services.json' file for the app to work.
1. Get the file from KAVI.
2. Place it in: 
   [Your_App_Folder] / android / app / (Paste here)

5. SHARED AUTH SERVICE CODE
----------------------------------------------------------------------
Create a file at 'lib/services/auth_service.dart' in your app folder.
Use this standardized code for Login/Register:

--- START CODE ---
'''import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // SIGN IN (For Lochi & Nimnaka)
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print("Login Failed: ${e.toString()}");
      return null;
    }
  }

  // SIGN UP (For Gayu & Nipuna)
  Future<User?> signUp(String email, String password, String role, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      
      // Save User Data to Firestore
      await _db.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'name': name,
        'email': email,
        'role': role, // Must be 'Driver' or 'Parent'
        'createdAt': FieldValue.serverTimestamp(),
      });
      return result.user;
    } catch (e) {
      print("Registration Failed: ${e.toString()}");
      return null;
    }
  }
}
'''
--- END CODE ---

6. GIT WORKFLOW (HOW TO UPDATE)
----------------------------------------------------------------------
To avoid losing code, follow this order every time:
1. Update your local code:  git pull origin main
2. Add your changes:        git add .
3. Save your work:          git commit -m "Completed [Your Task Name]"
4. Upload to GitHub:        git push origin main

7. SUPPORT
----------------------------------------------------------------------
If you have "Merge Conflicts" or Firebase connection issues, 
contact KAVI immediately. Do not delete any folders!

======================================================================
   STAY SAFE. DRIVE SMART. SAFERIDE 2026.
======================================================================
