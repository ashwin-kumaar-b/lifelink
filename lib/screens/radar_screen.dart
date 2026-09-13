import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/message_packet.dart';
import '../services/gps_service.dart';
import '../services/native_bridge.dart';
import '../utils/gps_calculator.dart';
import '../widgets/app_drawer.dart';

class RadarScreen extends StatefulWidget {
  final String selectedLanguage;
  final List<MessagePacket> messages;

  const RadarScreen({
    super.key,
    this.selectedLanguage = 'en',
    this.messages = const [],
  });

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  final NativeBridge _bridge = NativeBridge();
  final GpsService _gpsService = GpsService();
  StreamSubscription? _gpsSubscription;

  late String _currentLanguage;

  // Base coordinates (my phone location)
  double _myLat = 13.0827;
  double _myLon = 80.2707;

  RadarNode? _selectedNode;
  String? _trackedNodeId; // ID of the phone being single-tracked

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.selectedLanguage;

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _bridge.discoverPeers();
    _initGps();
  }

  void _initGps() async {
    final pos = await _gpsService.initialize();
    if (pos != null && mounted) {
      setState(() {
        _myLat = pos.latitude;
        _myLon = pos.longitude;
      });
    }

    _gpsSubscription = _gpsService.getPositionStream().listen((pos) {
      if (mounted) {
        setState(() {
          _myLat = pos.latitude;
          _myLon = pos.longitude;
        });
      }
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _sweepController.dispose();
    super.dispose();
  }

  /// Calculates dynamic auto-scaling distance and builds RadarNodes
  Map<String, dynamic> _getScaledRadarNodes() {
    final List<RadarNode> allNodes = [];
    final peerMessages = widget.messages.where((msg) => !msg.isSelf).toList();

    for (var msg in peerMessages) {
      final double distMeters = GpsCalculator.calculateDistanceMeters(
        _myLat,
        _myLon,
        msg.latitude,
        msg.longitude,
      );

      final String formattedDist = GpsCalculator.formatDistance(distMeters);

      double bearing = GpsCalculator.calculateBearingRadians(
        _myLat,
        _myLon,
        msg.latitude,
        msg.longitude,
      );

      if (distMeters < 1) {
        final hash = msg.id.hashCode.abs();
        bearing = ((hash % 360) * pi) / 180.0;
      }

      final String displayName = msg.id.startsWith('NODE-')
          ? msg.id
          : 'Sender';

      allNodes.add(
        RadarNode(
          id: msg.id,
          name: displayName,
          angle: bearing,
          rawDistanceMeters: distMeters,
          distanceFactor: 0.5, // Will be scaled below
          distanceText: formattedDist,
          lastMessage: msg.text,
          isEmergency: msg.isEmergency,
          ttl: msg.ttl,
          timestamp: msg.timestamp.length > 18
              ? msg.timestamp.substring(11, 19)
              : 'Just now',
        ),
      );
    }

    // Determine max distance for dynamic auto-scaling
    double maxDist = 100.0; // Default minimum 100 meters
    for (var node in allNodes) {
      if (node.rawDistanceMeters > maxDist) {
        maxDist = node.rawDistanceMeters;
      }
    }

    // Round up maxDist to neat scale boundary (e.g. 100m, 500m, 1km, 5km)
    double scaleMaxMeters = 100.0;
    if (maxDist > 100 && maxDist <= 500) {
      scaleMaxMeters = 500.0;
    } else if (maxDist > 500 && maxDist <= 1000) {
      scaleMaxMeters = 1000.0;
    } else if (maxDist > 1000 && maxDist <= 5000) {
      scaleMaxMeters = 5000.0;
    } else if (maxDist > 5000) {
      scaleMaxMeters = maxDist * 1.1;
    }

    // Apply distance factor scaling (0.15 to 0.95 relative to scaleMaxMeters)
    final scaledNodes = allNodes.map((n) {
      final factor = min(0.95, max(0.15, n.rawDistanceMeters / scaleMaxMeters));
      return n.copyWith(distanceFactor: factor);
    }).toList();

    return {
      'nodes': scaledNodes,
      'scaleMaxMeters': scaleMaxMeters,
      'scaleText': GpsCalculator.formatDistance(scaleMaxMeters),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scaledData = _getScaledRadarNodes();
    final List<RadarNode> allNodes = scaledData['nodes'] as List<RadarNode>;
    final String scaleText = scaledData['scaleText'] as String;

    // Filter nodes if single-target tracking mode is active
    final List<RadarNode> displayedNodes = _trackedNodeId == null
        ? allNodes
        : allNodes.where((n) => n.id == _trackedNodeId).toList();

    final RadarNode? trackedNode = _trackedNodeId == null
        ? null
        : allNodes.firstWhere(
            (n) => n.id == _trackedNodeId,
            orElse: () => RadarNode(
              id: _trackedNodeId!,
              name: 'Target Phone',
              angle: 0.0,
              rawDistanceMeters: 50.0,
              distanceFactor: 0.5,
              distanceText: '50m',
              lastMessage: 'Tracking active',
              isEmergency: true,
              ttl: 5,
              timestamp: 'Now',
            ),
          );

    return Container(
      color: Colors.grey.shade900,
      child: Column(
        children: [
          // Sleek Sub-Header for Radar Controls & Scale Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black,
            child: Row(
              children: [
                Icon(
                  _trackedNodeId == null ? Icons.radar : Icons.gps_fixed,
                  color: _trackedNodeId == null ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _trackedNodeId == null ? 'Radar (Auto-Scale: $scaleText)' : 'Tracking Target Phone',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_trackedNodeId != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _trackedNodeId = null; // Exit tracking mode
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    label: const Text('Exit Track', style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: () {
                      final random = Random();
                      final mockId = 'NODE-${random.nextInt(900) + 100}';
                      final mockDistOffset = (random.nextDouble() * 0.01) - 0.005;
                      final packet = MessagePacket(
                        id: mockId,
                        type: random.nextBool() ? 'EMERGENCY' : 'NORMAL',
                        language: _currentLanguage,
                        text: 'Simulated P2P message from $mockId',
                        latitude: 13.0827 + mockDistOffset,
                        longitude: 80.2707 + mockDistOffset,
                        ttl: random.nextInt(4) + 1,
                        timestamp: DateTime.now().toIso8601String(),
                      );
                      _bridge.sendMessage(packet);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Simulated Peer Broadcast from $mockId')),
                      );
                    },
                    icon: const Icon(Icons.add_location_alt, color: Colors.yellowAccent, size: 16),
                    label: const Text('+ Sim Peer', style: TextStyle(color: Colors.yellowAccent, fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.green, size: 20),
                    tooltip: 'Rescan P2P Nodes',
                    onPressed: () {
                      _bridge.discoverPeers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rescanning real P2P nodes...')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          // Single-Target Tracking Mode Active Banner
          if (_trackedNodeId != null && trackedNode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade900,
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.yellowAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TRACKING: ${trackedNode.name} | ${trackedNode.distanceText} away',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _trackedNodeId = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Show All'),
                  )
                ],
              ),
            ),
          ],

          // Radar Scope Container with Dynamic Scale Rings
          Container(
            height: 340,
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Animated Radar Painter
                AnimatedBuilder(
                  animation: _sweepController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: RadarPainter(
                        angle: _sweepController.value * 2 * pi,
                        nodes: displayedNodes,
                        selectedNodeId: _selectedNode?.id,
                        isTrackMode: _trackedNodeId != null,
                      ),
                    );
                  },
                ),

                // Scale Indicator Overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                    ),
                    child: Text(
                      'Max Radius: $scaleText',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Touch Overlay for Radar Nodes
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                      final maxRadius = min(constraints.maxWidth, constraints.maxHeight) / 2 - 10;

                      return Stack(
                        children: displayedNodes.map((node) {
                          final r = node.distanceFactor * maxRadius;
                          final x = center.dx + r * cos(node.angle) - 16;
                          final y = center.dy + r * sin(node.angle) - 16;
                          final isTracked = _trackedNodeId == node.id;

                          return Positioned(
                            left: x,
                            top: y,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedNode = node;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isTracked ? 40 : 32,
                                height: isTracked ? 40 : 32,
                                decoration: BoxDecoration(
                                  color: isTracked
                                      ? Colors.yellowAccent
                                      : (node.isEmergency ? Colors.red : Colors.green),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: isTracked ? 3 : 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isTracked ? Colors.yellow : (node.isEmergency ? Colors.red : Colors.green)).withOpacity(0.8),
                                      blurRadius: isTracked ? 14 : 8,
                                      spreadRadius: isTracked ? 4 : 2,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  isTracked
                                      ? Icons.gps_fixed
                                      : (node.isEmergency ? Icons.warning : Icons.person),
                                  color: isTracked ? Colors.black : Colors.white,
                                  size: isTracked ? 22 : 18,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                // Empty State Overlay if no real nodes detected yet
                if (displayedNodes.isEmpty)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Scanning real Wi-Fi & Bluetooth nodes...\nNo messages or P2P senders received yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Selected Node Details Card with "TRACK THIS PHONE" Action!
          if (_selectedNode != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedNode!.isEmergency ? Colors.red.shade900 : Colors.green.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedNode!.isEmergency ? Icons.warning : Icons.radar,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedNode!.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_selectedNode!.distanceText} (${_selectedNode!.ttl} hops)',
                                    style: const TextStyle(
                                      color: Colors.yellowAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Last Msg: "${_selectedNode!.lastMessage}"',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.white),
                        onPressed: () {
                          _bridge.speakTTS(_selectedNode!.lastMessage, language: _currentLanguage);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Button to Trigger Single-Target Phone Tracking Mode
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _trackedNodeId = _selectedNode!.id;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tracking Target: ${_selectedNode!.name} (${_selectedNode!.distanceText})'),
                            backgroundColor: Colors.orange.shade900,
                          ),
                        );
                      },
                      icon: const Icon(Icons.gps_fixed, color: Colors.black, size: 18),
                      label: Text(
                        _trackedNodeId == _selectedNode!.id ? 'TRACKING ACTIVE' : '🎯 TRACK THIS PHONE ONLY',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellowAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Live Real P2P Senders & GPS Distance',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // List of Real Nearby Senders
          Expanded(
            child: displayedNodes.isEmpty
                ? const Center(
                    child: Text(
                      'No P2P messages received yet.\nSend or transmit speech/text to plot senders and GPS distance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayedNodes.length,
                    itemBuilder: (context, index) {
                      final node = displayedNodes[index];
                      final isTracked = _trackedNodeId == node.id;
                      return Card(
                        color: isTracked ? Colors.yellow.shade900.withOpacity(0.6) : Colors.grey.shade800,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: isTracked ? const BorderSide(color: Colors.yellowAccent, width: 2) : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isTracked ? Colors.yellowAccent : (node.isEmergency ? Colors.red : Colors.green),
                            child: Icon(
                              isTracked ? Icons.gps_fixed : (node.isEmergency ? Icons.warning : Icons.person),
                              color: isTracked ? Colors.black : Colors.white,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                node.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                node.distanceText,
                                style: const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Msg: "${node.lastMessage}"\nTime: ${node.timestamp} | TTL: ${node.ttl}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedNode = node;
                                _trackedNodeId = node.id;
                              });
                            },
                            icon: const Icon(Icons.gps_fixed, size: 14),
                            label: const Text('Track', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTracked ? Colors.yellowAccent : Colors.grey.shade700,
                              foregroundColor: isTracked ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class RadarNode {
  final String id;
  final String name;
  final double angle; // In radians
  final double rawDistanceMeters;
  final double distanceFactor; // 0.0 to 1.0 relative to dynamic max radius
  final String distanceText; // e.g. "50m", "500m", "2.4 km"
  final String lastMessage;
  final bool isEmergency;
  final int ttl;
  final String timestamp;

  RadarNode({
    required this.id,
    required this.name,
    required this.angle,
    required this.rawDistanceMeters,
    required this.distanceFactor,
    required this.distanceText,
    required this.lastMessage,
    required this.isEmergency,
    required this.ttl,
    required this.timestamp,
  });

  RadarNode copyWith({double? distanceFactor}) {
    return RadarNode(
      id: id,
      name: name,
      angle: angle,
      rawDistanceMeters: rawDistanceMeters,
      distanceFactor: distanceFactor ?? this.distanceFactor,
      distanceText: distanceText,
      lastMessage: lastMessage,
      isEmergency: isEmergency,
      ttl: ttl,
      timestamp: timestamp,
    );
  }
}

class RadarPainter extends CustomPainter {
  final double angle;
  final List<RadarNode> nodes;
  final String? selectedNodeId;
  final bool isTrackMode;

  RadarPainter({
    required this.angle,
    required this.nodes,
    this.selectedNodeId,
    this.isTrackMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2 - 10;

    final gridPaint = Paint()
      ..color = isTrackMode ? Colors.yellow.shade800 : Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 1. Concentric Range Rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (maxRadius / 4) * i, gridPaint);
    }

    // 2. Crosshair Lines
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), gridPaint);

    // 3. Rotating Sweep Line
    final sweepPaint = Paint()
      ..color = (isTrackMode ? Colors.yellowAccent : Colors.greenAccent).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final sweepEnd = Offset(
      center.dx + maxRadius * cos(angle),
      center.dy + maxRadius * sin(angle),
    );
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Sweep Sector Glow
    final sweepArcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          (isTrackMode ? Colors.yellow : Colors.green).withOpacity(0.0),
          (isTrackMode ? Colors.yellowAccent : Colors.greenAccent).withOpacity(0.25),
        ],
        stops: const [0.8, 1.0],
        transform: GradientRotation(angle - 0.5),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepArcPaint);

    // 4. Directional Compass Line to Tracked Node in Track Mode
    if (isTrackMode && nodes.isNotEmpty) {
      final target = nodes.first;
      final targetRadius = target.distanceFactor * maxRadius;
      final targetOffset = Offset(
        center.dx + targetRadius * cos(target.angle),
        center.dy + targetRadius * sin(target.angle),
      );

      final trackLinePaint = Paint()
        ..color = Colors.yellowAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(center, targetOffset, trackLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.nodes != nodes ||
        oldDelegate.isTrackMode != isTrackMode;
  }
}
