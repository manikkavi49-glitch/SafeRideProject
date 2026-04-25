import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'location_service.dart';
import 'alarm_service.dart';
import 'face_detector_service.dart';

class HomeScreen extends StatefulWidget {
  final bool isTripActive;
  final ValueChanged<bool> onTripToggle;

  const HomeScreen({
    super.key,
    required this.isTripActive,
    required this.onTripToggle,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final AlarmService _alarmService = AlarmService();
  final FaceDetectorService _aiEngine = FaceDetectorService();

  bool _isDrowsy = false;
  String _lastAlert = '';
  bool _sosActive = false;
  bool _isProcessing = false;
  bool _isCameraReady = false;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera; // 🔥 store selected camera

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 0.15).animate(_pulseController);

    _alarmService.onStatusChanged = (isDrowsy, lastAlert) {
      if (mounted) {
        setState(() {
          _isDrowsy = isDrowsy;
          _lastAlert = lastAlert;
        });
      }
    };
    _alarmService.startListening();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();

    if (_cameras != null && _cameras!.isNotEmpty) {
      _selectedCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        _selectedCamera!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });

        _cameraController!.startImageStream((CameraImage image) {
          if (widget.isTripActive && !_isProcessing) {
            _processCameraImage(image);
          }
        });
      }
    }
  }

  /// 🔥 THE FIX: Convert YUV420 → NV21 manually before passing to ML Kit
  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    // NV21 = Y plane + interleaved V/U plane
    final Uint8List nv21 = Uint8List(width * height * 3 ~/ 2);

    // Copy Y plane directly
    for (int y = 0; y < height; y++) {
      final int yRowStart = y * image.planes[0].bytesPerRow;
      final int nv21RowStart = y * width;
      nv21.setRange(nv21RowStart, nv21RowStart + width,
          yPlane, yRowStart);
    }

    // Interleave V and U bytes (NV21 = VU order)
    int uvOffset = width * height;
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvIndex = uvRowStride * row + col * uvPixelStride;
        nv21[uvOffset++] = vPlane[uvIndex]; // V first
        nv21[uvOffset++] = uPlane[uvIndex]; // then U
      }
    }

    return nv21;
  }

  /// Determine correct rotation based on camera sensor orientation
  InputImageRotation _getRotation() {
    if (_selectedCamera == null) return InputImageRotation.rotation270deg;
    final sensorOrientation = _selectedCamera!.sensorOrientation;
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // 🔥 Convert YUV420 → NV21 (what ML Kit actually needs on Android)
      final Uint8List nv21Bytes = _convertYUV420ToNV21(image);

      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _getRotation(),
          format: InputImageFormat.nv21, // 🔥 Use NV21, not yuv420
          bytesPerRow: image.width,      // 🔥 For NV21, bytesPerRow = width
        ),
      );

      bool drowsyDetected = await _aiEngine.detectDrowsiness(inputImage);

      if (mounted) {
        setState(() {
          _isDrowsy = drowsyDetected;
        });

        await FirebaseDatabase.instance.ref("v1/alerts/van01").set({
          'isDrowsy': _isDrowsy,
          'lastAlert':
              _isDrowsy ? "Driver Drowsy Detected" : "Driver Alert",
          'timestamp': ServerValue.timestamp,
        });

        debugPrint("Drowsy Status: $_isDrowsy");
      }
    } catch (e) {
      debugPrint("AI Processing Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _alarmService.stopListening();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleTrip() async {
    if (widget.isTripActive) {
      await _locationService.stopTracking();
      widget.onTripToggle(false);
    } else {
      final success = await _locationService.startTracking();
      if (success) {
        widget.onTripToggle(true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission denied. Please enable in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _triggerSOS() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🚨 Emergency SOS'),
        content: const Text(
          'This will immediately alert all parents and administrators.\n\nAre you sure you want to send an SOS?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sosActive = true);

    await FirebaseDatabase.instance.ref("sos").set({
      'active': true,
      'timestamp': ServerValue.timestamp,
      'message': 'Driver has triggered an emergency SOS.',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('🚨 SOS sent — parents and admin have been alerted.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }

    Future.delayed(const Duration(minutes: 5), () async {
      await FirebaseDatabase.instance
          .ref("sos")
          .update({'active': false});
      if (mounted) setState(() => _sosActive = false);
    });
  }

  Future<void> _cancelSOS() async {
    await FirebaseDatabase.instance
        .ref("sos")
        .update({'active': false});
    setState(() => _sosActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SafeRide Driver Portal')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_bus,
                  size: 100,
                  color: widget.isTripActive
                      ? Colors.green.shade600
                      : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isTripActive
                      ? 'Trip In Progress'
                      : 'Ready to Start',
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.isTripActive
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _toggleTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isTripActive
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      widget.isTripActive ? 'STOP TRIP' : 'START TRIP',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _sosActive
                      ? OutlinedButton.icon(
                          onPressed: _cancelSOS,
                          icon: const Icon(Icons.cancel,
                              color: Colors.red),
                          label: const Text(
                            'CANCEL SOS',
                            style:
                                TextStyle(color: Colors.red, fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _triggerSOS,
                          icon: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red),
                          label: const Text(
                            '🚨 EMERGENCY SOS',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 32),

                _SafetyStatusCard(
                    isDrowsy: _isDrowsy, lastAlert: _lastAlert),
              ],
            ),
          ),

          // Drowsy overlay
          if (_isDrowsy)
            FadeTransition(
              opacity: _pulseAnimation,
              child: IgnorePointer(
                child: Container(
                  color: Colors.red.withValues(alpha: 0.25),
                ),
              ),
            ),

          // Camera Preview
          if (_isCameraReady && _cameraController != null)
            Positioned(
              right: 12,
              bottom: 12,
              width: 120,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CameraPreview(_cameraController!),
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyStatusCard extends StatelessWidget {
  final bool isDrowsy;
  final String lastAlert;

  const _SafetyStatusCard(
      {required this.isDrowsy, required this.lastAlert});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:
            isDrowsy ? Colors.red.shade50 : Colors.green.shade50,
        border: Border.all(
          color: isDrowsy
              ? Colors.red.shade300
              : Colors.green.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isDrowsy
                ? Icons.warning_amber_rounded
                : Icons.check_circle,
            color: isDrowsy
                ? Colors.red.shade700
                : Colors.green.shade700,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDrowsy
                      ? 'Drowsiness Detected!'
                      : 'Driver Status: Alert',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDrowsy
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
                if (isDrowsy && lastAlert.isNotEmpty)
                  Text(
                    lastAlert,
                    style: TextStyle(
                        color: Colors.red.shade600, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}