import 'dart:async';
import 'dart:ui';
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

class _EmergencyPanicScreenState extends State<EmergencyPanicScreen>
    with SingleTickerProviderStateMixin {
  final NativeBridge _bridge = NativeBridge();
  late final MeshManager _meshManager;
  final Uuid _uuid = const Uuid();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isBroadcasting = false;
  bool _hasSent = false;
  bool _isCountdownActive = false;
  int _secondsRemaining = 10;
  Timer? _countdownTimer;

  final String _broadcastText =
      "EMERGENCY SOS: IMMEDIATE ASSISTANCE NEEDED AT LOCATION";

  @override
  void initState() {
    super.initState();
    _meshManager = MeshManager(_bridge);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSosButtonPressed() {
    if (_isBroadcasting || _isCountdownActive) return;
    HapticFeedback.heavyImpact();
    _showSosCountdownDialog();
  }

  void _showSosCountdownDialog() {
    setState(() {
      _isCountdownActive = true;
      _secondsRemaining = 10;
    });

    _countdownTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start 10-second countdown timer once when dialog opens
            _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (_secondsRemaining > 1) {
                if (mounted) {
                  setDialogState(() {
                    _secondsRemaining--;
                  });
                  setState(() {
                    _secondsRemaining = _secondsRemaining;
                  });
                }
              } else {
                timer.cancel();
                _countdownTimer = null;
                if (mounted) {
                  Navigator.of(dialogCtx, rootNavigator: true).pop();
                  setState(() {
                    _isCountdownActive = false;
                  });
                  _triggerPanicBroadcast();
                }
              }
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.4),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER: Title & Top-Right 10s Countdown Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.amberAccent, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'EMERGENCY SOS',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),

                            // TOP RIGHT COUNTDOWN TIMER BADGE
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.8), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.8),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_secondsRemaining}s',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        Divider(color: Colors.white.withOpacity(0.2), height: 1),
                        const SizedBox(height: 16),

                        // BODY: Professional Warning Text
                        const Text(
                          'Emergency SOS Protocol Initiated',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'An urgent distress broadcast with your live GPS coordinates will be transmitted to all nearby off-grid mesh nodes unless cancelled.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // FOOTER: Read-only YES Indicator + Clickable NO Button
                        Column(
                          children: [
                            // READ-ONLY "YES" DISPATCH INDICATOR (NOT A BUTTON)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.amberAccent),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Auto-Dispatching in $_secondsRemaining seconds...',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // CLICKABLE "NO" BUTTON (CANCEL ALERT)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade800,
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.8),
                                      width: 1.5,
                                    ),
                                  ),
                                  shadowColor: Colors.redAccent,
                                ),
                                icon: const Icon(Icons.cancel_rounded, size: 22),
                                label: const Text(
                                  'NO  (CANCEL ALERT)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                onPressed: () {
                                  _countdownTimer?.cancel();
                                  _countdownTimer = null;
                                  Navigator.of(dialogCtx, rootNavigator: true).pop();
                                  setState(() {
                                    _isCountdownActive = false;
                                  });
                                  HapticFeedback.mediumImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle_outline,
                                              color: Colors.white),
                                          SizedBox(width: 8),
                                          Text(
                                            'Emergency SOS alert cancelled. No alarm raised.',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.grey.shade900,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      if (mounted) {
        setState(() {
          _isCountdownActive = false;
        });
      }
    });
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 EMERGENCY SOS BROADCASTED TO ALL NEARBY MESH NODES!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8B0000), // Rich Crimson Background
      appBar: AppBar(
        title: const Text(
          'PANIC SOS BROADCAST',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Glassmorphism Warning Card
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.amberAccent, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'ONE-TAP EMERGENCY SOS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Instantly broadcasts maximum priority emergency packet with GPS location to all nearby mesh phones in range.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.red.shade100, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Glowing Neon Pulse SOS Button
              Center(
                child: ScaleTransition(
                  scale: _hasSent || _isBroadcasting || _isCountdownActive
                      ? const AlwaysStoppedAnimation(1.0)
                      : _pulseAnimation,
                  child: GestureDetector(
                    onTap: _isBroadcasting ? null : _onSosButtonPressed,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _hasSent
                              ? [Colors.green.shade500, Colors.green.shade800]
                              : [Colors.red.shade500, const Color(0xFFB71C1C)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                        boxShadow: [
                          BoxShadow(
                            color: (_hasSent ? Colors.green : Colors.redAccent)
                                .withOpacity(0.8),
                            blurRadius: 35,
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
                                  : (_isBroadcasting
                                      ? 'BROADCASTING...'
                                      : 'TAP SOS'),
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
              ),

              // Bottom Status Info
              Column(
                children: [
                  if (_hasSent) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'SOS Active & Transmitting to Nearby Nodes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Press TAP SOS button above to trigger 10s countdown broadcast.',
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
