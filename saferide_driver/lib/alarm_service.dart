import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  // vanId dynamically set වෙනවා — setVanId() call කළාම
  DatabaseReference _safetyRef = FirebaseDatabase.instance.ref("v1/alerts/van01");
  String _currentVanId = 'van01';

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<DatabaseEvent>? _subscription;

  bool _isAlarming = false;
  bool get isAlarming => _isAlarming;
  bool _isListening = false;

  Function(bool isDrowsy, String lastAlert)? onStatusChanged;

  /// vanId update කරලා listener restart කරනවා
  void setVanId(String vanId) {
    if (vanId == _currentVanId) return;
    _currentVanId = vanId;
    _safetyRef = FirebaseDatabase.instance.ref("v1/alerts/$vanId");
    if (_isListening) {
      _subscription?.cancel();
      _subscription = null;
      _isListening = false;
      startListening();
    }
  }

  /// Start listening safely (no duplicates)
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    _subscription = _safetyRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final isDrowsy = data['isDrowsy'] == true;
      final lastAlert = data['lastAlert']?.toString() ?? '';

      onStatusChanged?.call(isDrowsy, lastAlert);

      if (isDrowsy && !_isAlarming) {
        await _triggerAlarm();
      } else if (!isDrowsy && _isAlarming) {
        await _stopAlarm();
      }
    });
  }

  Future<void> _triggerAlarm() async {
    if (_isAlarming) return;
    _isAlarming = true;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/alarm.mp3'));
    } catch (e) { debugPrint("Audio error: $e"); }
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 500, 300, 500, 300, 500], repeat: 0);
      }
    } catch (e) { debugPrint("Vibration error: $e"); }
  }

  Future<void> _stopAlarm() async {
    if (!_isAlarming) return;
    _isAlarming = false;
    try { await _audioPlayer.stop(); } catch (e) { debugPrint("Stop audio error: $e"); }
    try { Vibration.cancel(); } catch (e) { debugPrint("Vibration cancel error: $e"); }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _stopAlarm();
  }

  void dispose() {
    stopListening();
    _audioPlayer.dispose();
  }
}
