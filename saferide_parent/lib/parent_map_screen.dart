import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTANT: Replace with your own Google Maps Directions API key
// Enable "Directions API" in Google Cloud Console
const String _kDirectionsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
// ─────────────────────────────────────────────────────────────────────────────

class ParentMapScreen extends StatefulWidget {
  final String vanId;
  const ParentMapScreen({super.key, required this.vanId});

  @override
  State<ParentMapScreen> createState() => _ParentMapScreenState();
}

class _ParentMapScreenState extends State<ParentMapScreen> {
  LatLng _busPos = const LatLng(6.9271, 79.8612);
  GoogleMapController? _mapController;
  String? _todayTripId;
  

  // ── Route breadcrumb trail ────────────────────────────────────────────────
  final List<LatLng> _routePoints = [];
  static const int _maxRoutePoints = 200;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  // Van icon — loaded asynchronously from custom painter
  BitmapDescriptor _vanIcon =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

  // Stops from attendance
  final List<_AttendanceStop> _stops = [];
  StreamSubscription<DatabaseEvent>? _attendanceSub;  // real-time listener
  

  // Directions cache: key = "boardLat,boardLng→exitLat,exitLng"
  // value = decoded polyline points
  final Map<String, List<LatLng>> _directionsCache = {};
  final Set<String> _pendingDirections = {};   // avoid duplicate fetches

  static const List<Color> _studentColors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6B6B),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFF4CAF50),
  ];

  @override
  void initState() {
    super.initState();
    _reconstructTodayTripId();
    _loadVanIcon();               // custom van icon
    _startLocationListener();
    _loadAttendanceStops();
    _rebuildMapObjects();
  }

  // ── Custom van icon ───────────────────────────────────────────────────────
  Future<void> _loadVanIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    const double iconSize = 72;

    // ── Shadow ────────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 10, 64, 46),
        const Radius.circular(10),
      ),
      shadowPaint,
    );

    // ── Body ──────────────────────────────────────────────────────────────
    final bodyPaint = Paint()..color = const Color(0xFF1B5E20); // dark green
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 6, 64, 44),
        const Radius.circular(10),
      ),
      bodyPaint,
    );

    // ── Roof highlight ────────────────────────────────────────────────────
    final roofPaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 6, 64, 18),
        const Radius.circular(10),
      ),
      roofPaint,
    );

    // ── Windshield ────────────────────────────────────────────────────────
    final glassPaint = Paint()..color = const Color(0xFFB3E5FC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 10, 52, 18),
        const Radius.circular(4),
      ),
      glassPaint,
    );

    // ── Windshield divider ────────────────────────────────────────────────
    final divPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 2;
    canvas.drawLine(
      const Offset(34, 10), const Offset(34, 28), divPaint);

    // ── Door panels ───────────────────────────────────────────────────────
    final doorPaint = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 30, 24, 16),
        const Radius.circular(3),
      ),
      doorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 30, 24, 16),
        const Radius.circular(3),
      ),
      doorPaint,
    );

    // ── Wheels ────────────────────────────────────────────────────────────
    final rimPaint  = Paint()..color = const Color(0xFF212121);
    final tyrePaint = Paint()..color = const Color(0xFF424242);
    for (final cx in [18.0, 54.0]) {
      canvas.drawCircle(Offset(cx, 52), 9, tyrePaint);
      canvas.drawCircle(Offset(cx, 52), 5, rimPaint);
      canvas.drawCircle(Offset(cx, 52), 2,
          Paint()..color = Colors.white.withValues(alpha: 0.8));
    }

    // ── Headlights ───────────────────────────────────────────────────────
    final lightPaint = Paint()..color = const Color(0xFFFFF176);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 32, 8, 6), const Radius.circular(2)),
      lightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(54, 32, 8, 6), const Radius.circular(2)),
      lightPaint,
    );

    // ── Fin: convert to BitmapDescriptor ─────────────────────────────────
    final picture = recorder.endRecording();
    final img     = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final bytes   = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || !mounted) return;

    final icon = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width:  40,
      height: 40,
    );
    if (mounted) setState(() => _vanIcon = icon);
  }

  void _reconstructTodayTripId() {
    final now     = DateTime.now();
    final dateStr = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    _todayTripId = 'trip_${widget.vanId}_$dateStr';
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Load attendance stops ─────────────────────────────────────────────────
  Future<void> _loadAttendanceStops() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('attendance/$_todayTripId')
          .get();

      if (!mounted || !snapshot.exists) return;

      final tripData = snapshot.value as Map<dynamic, dynamic>;
      final List<_AttendanceStop> stops = [];

      tripData.forEach((studentId, sData) {
        if (sData is Map) {
          final boardLat = sData['boardLat'];
          final boardLng = sData['boardLng'];
          final exitLat  = sData['exitLat'];
          final exitLng  = sData['exitLng'];
          final name     = sData['name']?.toString() ?? 'Student';

          if (boardLat != null && boardLng != null) {
            stops.add(_AttendanceStop(
              name:     name,
              position: LatLng(boardLat.toDouble(), boardLng.toDouble()),
              type:     'board',
              time:     sData['boardTime']?.toString() ?? '',
            ));
          }
          if (exitLat != null && exitLng != null) {
            stops.add(_AttendanceStop(
              name:     name,
              position: LatLng(exitLat.toDouble(), exitLng.toDouble()),
              type:     'exit',
              time:     sData['exitTime']?.toString() ?? '',
            ));
          }
        }
      });

      if (mounted) {
        setState(() {
          _stops
            ..clear()
            ..addAll(stops);
          
        });
        // Fetch road directions for all board→exit pairs
        await _fetchAllDirections();
        if (mounted) setState(_rebuildMapObjects);
      }
    } catch (_) {
      // stops optional — continue silently
    }
  }

  // ── Fetch road directions for every board→exit pair ───────────────────────
  Future<void> _fetchAllDirections() async {
    // Group stops by student name
    final Map<String, _AttendanceStop> boardByName = {};
    final Map<String, _AttendanceStop> exitByName  = {};
    for (final s in _stops) {
      if (s.type == 'board') boardByName[s.name] = s;
      if (s.type == 'exit')  exitByName[s.name]  = s;
    }

    final futures = <Future>[];
    for (final name in boardByName.keys) {
      final board = boardByName[name];
      final exit  = exitByName[name];
      if (board != null && exit != null) {
        futures.add(_fetchDirections(board.position, exit.position));
      }
    }
    await Future.wait(futures);
  }

  /// Calls Google Maps Directions API and decodes the polyline.
  Future<void> _fetchDirections(LatLng origin, LatLng destination) async {
    final cacheKey =
        '${origin.latitude},${origin.longitude}→${destination.latitude},${destination.longitude}';

    if (_directionsCache.containsKey(cacheKey)) return; // already have it
    if (_pendingDirections.contains(cacheKey))  return; // already fetching
    _pendingDirections.add(cacheKey);

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$_kDirectionsApiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return;

      final routes = data['routes'] as List;
      if (routes.isEmpty) return;

      final overviewPolyline =
          routes[0]['overview_polyline']['points'] as String;
      final points = _decodePolyline(overviewPolyline);

      _directionsCache[cacheKey] = points;
    } catch (_) {
      // Directions failed — will fall back to straight line
    } finally {
      _pendingDirections.remove(cacheKey);
    }
  }

  /// Decode Google's encoded polyline format into LatLng list.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ── Rebuild markers + polylines ───────────────────────────────────────────
  void _rebuildMapObjects() {
    final Set<Marker>   markers   = {};
    final Set<Polyline> polylines = {};

    // ── 1. Route breadcrumb trail — solid thick green line ───────────────
    if (_routePoints.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_trail'),
        points:     List.from(_routePoints),
        color:      const Color(0xFF00C853),
        width:      5,
        startCap:   Cap.roundCap,
        endCap:     Cap.roundCap,
        jointType:  JointType.round,
      ));
    }

    // ── 2. Per-student road directions: board → exit ──────────────────────
    final Map<String, _AttendanceStop> boardByName = {};
    final Map<String, _AttendanceStop> exitByName  = {};
    for (final s in _stops) {
      if (s.type == 'board') boardByName[s.name] = s;
      if (s.type == 'exit')  exitByName[s.name]  = s;
    }

    int colorIdx = 0;
    final allNames = {...boardByName.keys, ...exitByName.keys}.toList();

    for (final name in allNames) {
      final color     = _studentColors[colorIdx % _studentColors.length];
      final boardStop = boardByName[name];
      final exitStop  = exitByName[name];
      colorIdx++;

      // ── a) Van → board stop: ONBOARD section — solid orange line ────────
      if (boardStop != null) {
        polylines.add(Polyline(
          polylineId: PolylineId('van_to_board_$name'),
          points:     [_busPos, boardStop.position],
          color:      const Color(0xFFFF6F00),   // deep orange
          width:      4,
          patterns:   [PatternItem.dash(16), PatternItem.gap(8)],
          startCap:   Cap.roundCap,
          endCap:     Cap.roundCap,
        ));
      }

      // ── b) Board → exit: EXIT section — road directions, solid blue ──────
      if (boardStop != null && exitStop != null) {
        final cacheKey =
            '${boardStop.position.latitude},${boardStop.position.longitude}'
            '→${exitStop.position.latitude},${exitStop.position.longitude}';
        final roadPoints = _directionsCache[cacheKey];

        polylines.add(Polyline(
          polylineId: PolylineId('board_to_exit_$name'),
          points:     roadPoints ?? [boardStop.position, exitStop.position],
          color:      color,
          width:      5,
          startCap:   Cap.roundCap,
          endCap:     Cap.squareCap,
          jointType:  JointType.round,
        ));
      }

      // ── c) Board stop marker (green pin) ─────────────────────────────────
      if (boardStop != null) {
        markers.add(Marker(
          markerId:   MarkerId('board_${name}_${boardStop.position.latitude}'),
          position:   boardStop.position,
          icon:       BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title:   '🟢 $name boarded',
            snippet: boardStop.time.isNotEmpty
                ? 'Time: ${boardStop.time}'
                : null,
          ),
          zIndexInt: 1,
          alpha:  0.9,
        ));
      }

      // ── d) Exit stop marker (blue pin) ────────────────────────────────────
      if (exitStop != null) {
        markers.add(Marker(
          markerId:   MarkerId('exit_${name}_${exitStop.position.latitude}'),
          position:   exitStop.position,
          icon:       BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title:   '🔵 $name exited',
            snippet: exitStop.time.isNotEmpty
                ? 'Time: ${exitStop.time}'
                : null,
          ),
          zIndexInt: 1,
          alpha:  0.9,
        ));
      }
    }

    // ── 3. Van marker (always on top) ─────────────────────────────────────
    markers.add(Marker(
      markerId:   const MarkerId('moving_van'),
      position:   _busPos,
      icon:       _vanIcon,
      infoWindow: InfoWindow(
        title:   'SafeRide Van: ${widget.vanId}',
        snippet: _todayTripId != null
            ? 'Trip: $_todayTripId'
            : 'Real-time location active',
      ),
      zIndexInt: 3,
    ));

    _markers   = markers;
    _polylines = polylines;
  }

  // ── Update bus position ───────────────────────────────────────────────────
  void _updateBusPosition(double lat, double lng) {
    final newPos = LatLng(lat, lng);

    bool shouldAdd = _routePoints.isEmpty;
    if (!shouldAdd) {
      final last = _routePoints.last;
      shouldAdd  = ((last.latitude - lat).abs() + (last.longitude - lng).abs()) > 0.0001;
    }

    if (shouldAdd) {
      _routePoints.add(newPos);
      if (_routePoints.length > _maxRoutePoints) _routePoints.removeAt(0);
    }

    _busPos = newPos;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: _busPos, zoom: 16)),
    );
    _rebuildMapObjects();
  }

  // ── Firebase location listener (separate from map widget) ───────────────
  StreamSubscription<DatabaseEvent>? _locationSub;

  void _startLocationListener() {
    _locationSub?.cancel();
    _locationSub = FirebaseDatabase.instance
        .ref('v1/locations/${widget.vanId}')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final rawData = event.snapshot.value;
      if (rawData is Map) {
        final double? lat = (rawData['lat'])?.toDouble();
        final double? lng = (rawData['lng'])?.toDouble();
        if (lat != null && lng != null) {
          setState(() => _updateBusPosition(lat, lng));
        }
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking: ${widget.vanId}'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_routePoints.isNotEmpty)
            IconButton(
              icon:    const Icon(Icons.cleaning_services_rounded),
              tooltip: 'Clear route trail',
              onPressed: () => setState(() {
                _routePoints.clear();
                _rebuildMapObjects();
              }),
            ),
        ],
      ),
      body: Stack(
        children: [
          // GoogleMap is always present — never recreated by StreamBuilder
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // Pan to actual van position immediately on map ready
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_busPos, 16),
                  );
                }
              });
              if (_routePoints.length > 1) _fitBoundsToAll();
            },
            initialCameraPosition: CameraPosition(
              target: _busPos,
              zoom:   15,
            ),
            myLocationButtonEnabled: false,
            zoomControlsEnabled:    false,
            markers:   _markers,
            polylines: _polylines,
            mapType:   MapType.normal,
          ),

          Positioned(top: 12, left: 12, child: _buildLegend()),

          if (_routePoints.length >= 2)
            Positioned(
              top:   12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_routePoints.length} GPS pts',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),

          // Connecting overlay — shown until first GPS point arrives
          if (_routePoints.isEmpty)
            Positioned(
              bottom: 100,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green.shade400),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Connecting to ${widget.vanId}…',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_stops.isNotEmpty || _routePoints.length > 1)
            FloatingActionButton.small(
              heroTag:         'fit_all',
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade800,
              tooltip:         'Fit everything in view',
              onPressed:       _fitBoundsToAll,
              child:           const Icon(Icons.fit_screen),
            ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag:         'locate_van',
            backgroundColor: Colors.green.shade800,
            onPressed: () {
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(_busPos, 17),
                );
              }
            },
            label: const Text('Locate Van',
                style: TextStyle(color: Colors.white)),
            icon:  const Icon(Icons.directions_bus, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Fit map to show van + all stops ──────────────────────────────────────
  void _fitBoundsToAll() {
    final allPoints = [
      _busPos,
      ..._routePoints,
      ..._stops.map((s) => s.position),
      // Include road route points too
      for (final pts in _directionsCache.values) ...pts,
    ];
    if (allPoints.length < 2 || _mapController == null) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;
    for (final p in allPoints) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64.0,
      ),
    );
  }

  // ── Legend ────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:       MainAxisSize.min,
        children: [
          _legendItem(color: const Color(0xFF1B5E20),
              label: 'Van (live)', isVan: true),
          const SizedBox(height: 4),
          _legendItem(color: const Color(0xFF00C853),
              label: 'Route trail'),
          const SizedBox(height: 4),
          _legendItem(color: const Color(0xFFFF6F00),
              label: 'Van → boarded', isDashed: true),
          if (_stops.any((s) => s.type == 'board')) ...[
            const SizedBox(height: 4),
            _legendItem(color: Colors.green,
                label: 'Boarded here'),
          ],
          if (_stops.any((s) => s.type == 'exit')) ...[
            const SizedBox(height: 4),
            _legendItem(color: Colors.blue,
                label: 'Exited here'),
            const SizedBox(height: 4),
            _legendItem(color: const Color(0xFF6C63FF),
                label: 'Board → Exit route'),
          ],
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color  color,
    required String label,
    bool isDashed = false,
    bool isVan    = false,
  }) {
    Widget icon;
    if (isVan) {
      icon = Container(
        width: 20, height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Icon(Icons.directions_bus,
            color: Colors.white, size: 11),
      );
    } else if (isDashed) {
      icon = Row(children: List.generate(3, (_) => Container(
          width:  6, height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ))));
    } else {
      icon = Container(
          width:  12, height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _AttendanceStop {
  final String name;
  final LatLng position;
  final String type; // 'board' | 'exit'
  final String time;
  const _AttendanceStop({
    required this.name,
    required this.position,
    required this.type,
    required this.time,
  });
}