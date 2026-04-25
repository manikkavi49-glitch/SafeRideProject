# SafeRide Driver App v2.0 — Setup Guide

## New Features in This Version
- Multi-screen bottom navigation (Home / Attendance / Messages / Status)
- Real-time GPS telemetry (coordinates, speed, heading → Firebase)
- Drowsiness alarm: sound + vibration + pulsing red overlay
- Emergency SOS button (writes to Firebase `sos` node)
- Digital attendance with Board/Exit buttons and timestamps
- Messages screen with read-only parent messages + Quick Replies
- Live trip status dashboard (speed, location, safety, student count)

---

## Project Structure

```
lib/
├── main.dart                     # App entry + bottom nav shell
├── screens/
│   ├── home_screen.dart          # Trip toggle + SOS + alarm overlay
│   ├── attendance_screen.dart    # Student board/exit logging
│   ├── messages_screen.dart      # Parent messages + quick replies
│   └── status_screen.dart        # Live trip info dashboard
└── services/
    ├── location_service.dart     # GPS streaming to Firebase
    └── alarm_service.dart        # Drowsiness alarm (audio + vibration)
```

---

## Setup Steps

### 1. Add the alarm sound file
Create the folder `assets/audio/` and place an alarm MP3 inside it:
```
saferide_driver/assets/audio/alarm.mp3
```
You can use any short, loud alarm sound (e.g. from freesound.org).

### 2. Android permissions
Add these to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### 3. Install dependencies
```bash
flutter pub get
```

### 4. Firebase
Make sure your `google-services.json` is in `android/app/`.
The app uses these Firebase paths:
- `v1/locations/van01` — live GPS (lat, lng, speed, heading)
- `trips/trip_001` — trip status and telemetry
- `attendance/trip_001/{studentId}` — boarding/exit records
- `safety_status` — isDrowsy + lastAlert (written by Python AI monitor)
- `messages/van01` — driver-parent message thread
- `sos` — emergency SOS flag

### 5. Student list
Currently hardcoded in `attendance_screen.dart`. To load from Firebase,
replace the `_students` list initialisation with a Firebase read from
`students/van01`.

---

## Firebase Database Structure

```json
{
  "v1": {
    "locations": {
      "van01": {
        "lat": 7.29317,
        "lng": 80.6343267,
        "speed": "12.3",
        "heading": "45.0",
        "lastUpdate": 1234567890,
        "isActive": true
      }
    }
  },
  "trips": {
    "trip_001": {
      "status": "active",
      "startTime": 1234567890,
      "lat": 7.29317,
      "lng": 80.6343267,
      "speed": 12.3
    }
  },
  "attendance": {
    "trip_001": {
      "stu_001": {
        "name": "Ashan Perera",
        "grade": "Grade 7",
        "status": "onBoard",
        "boardTime": "07:45",
        "boardTimestamp": 1234567890
      }
    }
  },
  "safety_status": {
    "isDrowsy": false,
    "lastAlert": "Eyes Closed Detected"
  },
  "messages": {
    "van01": {
      "-NxABC123": {
        "sender": "Mrs. Perera",
        "text": "Is Ashan on the van?",
        "fromDriver": false,
        "timestamp": 1234567890
      }
    }
  },
  "sos": {
    "active": false,
    "timestamp": 1234567890,
    "message": "Driver has triggered an emergency SOS."
  }
}
```
