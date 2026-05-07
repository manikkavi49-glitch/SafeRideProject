import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // 1. Live GPS location for a van
  Stream<DatabaseEvent> getLiveLocation(String vanId) {
    return _db.ref('v1/locations/$vanId').onValue;
  }

  // 2. AI Drowsiness Alerts for a van
  Stream<DatabaseEvent> getDrowsinessAlerts(String vanId) {
    return _db.ref('v1/alerts/$vanId').onValue;
  }

  // 3. SOS Status
  Stream<DatabaseEvent> getSOSStatus() {
    return _db.ref('sos').onValue;
  }

  // 4. Attendance for a specific student in a trip
  Stream<DatabaseEvent> getAttendance(String tripId, String studentId) {
    return _db.ref('attendance/$tripId/$studentId').onValue;
  }

  // 🔥 5. Get all students linked to this parent's email
  // Driver saves: /students/{id} { parentEmail: "...", vanId: "...", name: "..." }
  Future<List<Map<String, dynamic>>> getStudentsByParentEmail(String email) async {
    try {
      final snap = await _db
          .ref('students')
          .orderByChild('parentEmail')
          .equalTo(email.toLowerCase().trim())
          .get();

      if (!snap.exists) return [];

      final data  = snap.value as Map;
      final result = <Map<String, dynamic>>[];

      data.forEach((key, val) {
        if (val is Map) {
          result.add({
            'id'         : key.toString(),
            'name'       : val['name']?.toString()        ?? 'Unknown',
            'grade'      : val['grade']?.toString()       ?? '',
            'vanId'      : val['vanId']?.toString()       ?? 'van01',
            'driverId'   : val['driverId']?.toString()    ?? '',
            'parentEmail': val['parentEmail']?.toString() ?? '',
          });
        }
      });

      return result;
    } catch (e) {
      return [];
    }
  }

  // 🔥 6. Get today's attendance for a specific student
  // Trip ID format: trip_{vanId}_{YYYYMMDD}
  String getTodayTripId(String vanId) {
    final now  = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'trip_${vanId}_$date';
  }

  Stream<DatabaseEvent> getTodayAttendance(String vanId, String studentId) {
    final tripId = getTodayTripId(vanId);
    return _db.ref('attendance/$tripId/$studentId').onValue;
  }

  // 7. Driver profile (for parent to see who is driving)
  Stream<DatabaseEvent> getDriverProfile(String driverId) {
    return _db.ref('drivers/$driverId').onValue;
  }

  // 8. Messages for a van
  Stream<DatabaseEvent> getMessages(String vanId) {
    return _db
        .ref('messages/$vanId')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue;
  }

  // 9. Send a message from parent
  Future<void> sendParentMessage({
    required String vanId,
    required String senderName,
    required String text,
  }) async {
    await _db.ref('messages/$vanId').push().set({
      'sender'    : senderName,
      'text'      : text,
      'fromDriver': false,
      'timestamp' : ServerValue.timestamp,
    });
  }

  Stream<DatabaseEvent> getBusLocation(String vanId) {
  // This points to the location node where the driver updates coordinates
  return FirebaseDatabase.instance.ref("v1/locations/$vanId").onValue;
}
}