import cv2
import time
import firebase_admin
from firebase_admin import credentials, db
from scipy.spatial import distance as dist
import mediapipe as mp

# =========================
# 1. FIREBASE INIT
# =========================
cred = credentials.Certificate("serviceAccountKey.json")

firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://saferide-g5-default-rtdb.firebaseio.com/'
})

safety_ref = db.reference('safety_status/van01')
log_ref = db.reference('ai_logs')

print("🔥 Firebase Connected")

# =========================
# 2. MEDIAPIPE SETUP
# =========================
mp_face = mp.solutions.face_mesh
face_mesh = mp_face.FaceMesh(
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

LEFT_EYE = [362, 385, 387, 263, 373, 380]
RIGHT_EYE = [33, 160, 158, 133, 153, 144]

EAR_THRESHOLD = 0.21
FRAME_LIMIT = 15

frame_counter = 0
is_drowsy = False
last_update = 0

# =========================
# 3. EAR FUNCTION
# =========================
def eye_aspect_ratio(eye, landmarks, w, h):
    points = [(landmarks[i].x * w, landmarks[i].y * h) for i in eye]

    v1 = dist.euclidean(points[1], points[5])
    v2 = dist.euclidean(points[2], points[4])
    h1 = dist.euclidean(points[0], points[3])

    return (v1 + v2) / (2.0 * h1)

# =========================
# 4. CAMERA
# =========================
cap = cv2.VideoCapture(0)
print("🚗 SafeRide AI Engine Running...")

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        continue

    frame = cv2.flip(frame, 1)
    h, w, _ = frame.shape

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    result = face_mesh.process(rgb)

    if result.multi_face_landmarks:
        for face in result.multi_face_landmarks:

            left_ear = eye_aspect_ratio(LEFT_EYE, face.landmark, w, h)
            right_ear = eye_aspect_ratio(RIGHT_EYE, face.landmark, w, h)
            avg_ear = (left_ear + right_ear) / 2

            # =========================
            # DROWSINESS DETECTION
            # =========================
            if avg_ear < EAR_THRESHOLD:
                frame_counter += 1
            else:
                frame_counter = 0
                is_drowsy = False

            # =========================
            # ALERT CONDITION
            # =========================
            if frame_counter >= FRAME_LIMIT:
                is_drowsy = True
                cv2.putText(frame, "DROWSY ALERT!", (50, 80),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)

                now = time.time()

                # prevent spam updates
                if now - last_update > 5:
                    safety_ref.update({
                        "isDrowsy": True,
                        "lastAlert": "Driver Drowsy Detected",
                        "timestamp": now
                    })

                    log_ref.push({
                        "event": "drowsy",
                        "timestamp": now
                    })

                    last_update = now

            else:
                # reset state
                if is_drowsy:
                    safety_ref.update({
                        "isDrowsy": False,
                        "lastAlert": "Normal"
                    })
                    is_drowsy = False

            cv2.putText(frame, f"EAR: {avg_ear:.2f}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

    cv2.imshow("SafeRide AI Engine", frame)

    if cv2.waitKey(1) & 0xFF == 27:
        break

cap.release()
cv2.destroyAllWindows()