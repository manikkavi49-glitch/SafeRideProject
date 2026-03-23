# 🚌 SafeRide: Real-Time Transport Tracking & AI Safety System
### Group 05 - Batch 77 | Final Year Research Project

**SafeRide** is an innovative IoT and Mobile ecosystem designed to bridge the safety gap in school commutes. By integrating high-frequency GPS telemetry with Computer Vision-based AI, SafeRide ensures that students are tracked in real-time and drivers are monitored for fatigue to prevent accidents.

---

## 🏗️ System Architecture Overview
The project is built on a distributed architecture:
1. **Driver Hub (`saferide_driver`)**: A Flutter app that acts as a sensor node, streaming live coordinates and running background AI for Drowsiness Detection.
2. **Parent Dashboard (`saferide_parent`)**: A Flutter app providing live map visualization, speed monitoring, and instant SOS notifications.
3. **AI Engine**: A Python-based module utilizing **OpenCV** and **Dlib** to calculate the **Eye Aspect Ratio (EAR)** for real-time fatigue alerts.

---

## 👥 Group 05: Task Responsibility Matrix

| Team Member | Role | Assigned Task | Target Module |
| :--- | :--- | :--- | :--- |
| **Kavi (Lead)** | Architect | AI Engine & GPS Telemetry | `saferide_driver` |
| **Lochi** | UI/UX Dev | Parent Login Authentication | `saferide_parent` |
| **Gayu** | Backend Dev | Parent Registration & Profiling | `saferide_parent` |
| **Nimnaka** | UI/UX Dev | Driver Login Authentication | `saferide_driver` |
| **Nipuna** | Backend Dev | Driver Registration & Binding | `saferide_driver` |

---

## 🛠️ Developer Setup Instructions

### 1. Initial Environment Setup
* **Flutter SDK**: Version 3.10.x or higher.
* **Clone Repo**: `git clone https://github.com/manikkavi49-glitch/SafeRideProject.git`
* **Firebase**: Obtain `google-services.json` from Kavi and place it in `android/app/` of your module.

### 2. Standardized Authentication Implementation
Create `lib/services/auth_service.dart` and use the following code for consistency:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) { return null; }
  }

  Future<User?> signUp(String email, String password, String role, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _db.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return result.user;
    } catch (e) { return null; }
  }
}
```

🌿 Git Branching Strategy (CRITICAL)
To keep the main branch stable, DO NOT push directly to main. Every member must work on their own branch.

Step 1: Create your own branch
Before you start coding, create a branch named after your task:
git checkout -b feature/login-lochi (Example for Lochi)

Step 2: Work and Commit
Code your feature, then stage and commit:
git add .
git commit -m "Completed login UI"

Step 3: Push your branch to GitHub
git push origin feature/login-lochi

Step 4: Pull Request
Go to GitHub and create a Pull Request (PR). Kavi will review the code before merging it into the main branch.

🚩 Project Roadmap
Sprint 1 (Current): Infrastructure Setup & User Authentication.

Sprint 2: Real-time GPS Telemetry & Google Maps Integration.

Sprint 3: AI Drowsiness Engine Integration (Kavi).

Sprint 4: SOS Alerts & Final Testing.

🆘 Support
Contact Kavi for Firebase SHA-1 registration or Merge Conflict resolution.

© 2026 SafeRide Project | Batch 77 Group 05
