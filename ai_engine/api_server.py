from flask import Flask, jsonify
import cv2

app = Flask(__name__)

# Example status (you will replace with real AI output)
drowsy_status = {
    "face_detected": False,
    "eyes_closed": False,
    "drowsy": False
}

@app.route("/status", methods=["GET"])
def get_status():
    return jsonify(drowsy_status)

@app.route("/update", methods=["POST"])
def update_status():
    global drowsy_status
    # here your AI engine will update values
    return jsonify({"message": "updated"})

if __name__ == "__main__":
    print("🚗 SafeRide API Running...")
    app.run(host="0.0.0.0", port=5000, debug=True)