import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  // 1. Face Detector එක නිර්මාණය කිරීම
  late FaceDetector _faceDetector;

  FaceDetectorService() {
    // AI එක වැඩ කරන්න ඕනේ විදිහ මෙතනින් තීරණය කරනවා
    final options = FaceDetectorOptions(
      enableClassification: true, // මේක 'true' කළොත් විතරයි ඇස් ඇරිලද වහලද කියලා හොයන්න පුළුවන්
      enableLandmarks: true,       // මූණේ හැඩය හඳුනාගැනීමට
      performanceMode: FaceDetectorMode.accurate, // වේගයට වඩා නිවැරදි බව (Accuracy) වැඩි කිරීමට
    );
    _faceDetector = FaceDetector(options: options);
  }

  // 2. පින්තූරයක් (Image) පරීක්ෂා කර ප්‍රතිඵලය ලබා දෙන Function එක
  Future<bool> detectDrowsiness(InputImage inputImage) async {
    print("AI is checking for faces...");
  final List<Face> faces = await _faceDetector.processImage(inputImage);
  
  // 1. මූණවල් කීයක් හඳුනාගත්තාද කියලා බලන්න (මේක loop එකෙන් පිටත)
  print("Faces found: ${faces.length}"); 

  for (Face face in faces) {
    double? leftEye = face.leftEyeOpenProbability;
    double? rightEye = face.rightEyeOpenProbability;

    // 2. ඇස් වල අගයන් බලන්න (මේක අනිවාර්යයෙන්ම loop එක ඇතුළේ තියෙන්න ඕනේ)
    print("Left Eye: $leftEye, Right Eye: $rightEye"); 

    if (leftEye != null && rightEye != null) {
      if (leftEye < 0.2 && rightEye < 0.2) {
        return true; 
      }
    }
  }
  return false; 
}

  void dispose() {
    _faceDetector.close();
  }
}