import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';

class EmergencyPanicScreen extends StatefulWidget {
  final String selectedLanguage;

  const EmergencyPanicScreen({
    super.key,
    this.selectedLanguage = 'en',
  });

  @override
  State<EmergencyPanicScreen> createState() => _EmergencyPanicScreenState();
}

class _EmergencyPanicScreenState extends State<EmergencyPanicScreen> {
  final NativeBridge _bridge = NativeBridge();
  late final MeshManager _meshManager;
  final Uuid _uuid = const Uuid();

  bool _isBroadcasting = false;
  bool _hasSent = false;
  String _broadcastText = "EMERGENCY SOS: IMMEDIATE ASSISTANCE NEEDED AT LOCATION";

  @override
  void initState() {
    super.initState();
    _meshManager = MeshManager(_bridge);
  }

  void _triggerPanicBroadcast() async {
    HapticFeedback.vibrate();
    setState(() {
      _isBroadcasting = true;
      _hasSent = false;
    });

    final packet = MessagePacket(
      id: 'SOS-${_uuid.v4().substring(0, 6).toUpperCase()}',
      type: 'EMERGENCY',
      language: widget.selectedLanguage,
      text: _broadcastText,
      latitude: 13.0827,
      longitude: 80.2707,
      ttl: 5,
      timestamp: DateTime.now().toIso8601String(),
    );

    _meshManager.registerSentMessage(packet);
    await _bridge.sendMessage(packet);

    // Read SOS message aloud locally via TTS
    _bridge.speakTTS(_broadcastText, language: widget.selectedLanguage);

    setState(() {
      _isBroadcasting = false;
      _hasSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'EMERGENCY SOS BROADCASTED TO ALL NEARBY MESH NODES!',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade600,
      appBar: AppBar(
        title: const Text(
          'PANIC SOS BROADCAST',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,

        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Warning Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning, color: Colors.yellowAccent, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'ONE-TAP EMERGENCY SOS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Instantly broadcasts maximum priority emergency packet with GPS location to all nearby mesh phones in range.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade100, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Huge High-Contrast Panic SOS Button
              Center(
                child: GestureDetector(
                  onTap: _isBroadcasting ? null : _triggerPanicBroadcast,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: _hasSent ? Colors.green.shade600 : Colors.red.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: [
                        BoxShadow(
                          color: (_hasSent ? Colors.green : Colors.red).withOpacity(0.8),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasSent
                                ? Icons.check_circle
                                : (_isBroadcasting
                                    ? Icons.sensors
                                    : Icons.touch_app),
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasSent
                                ? 'SOS SENT'
                                : (_isBroadcasting ? 'BROADCASTING...' : 'TAP SOS'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Quick Message Customizer or Send Confirmation Status
              Column(
                children: [
                  if (_hasSent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'SOS active & transmitting to nearby phones',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Press huge SOS button above to trigger instant broadcast.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade100, fontSize: 13),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
