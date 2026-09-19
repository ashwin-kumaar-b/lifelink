import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import '../services/gps_service.dart';
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
  final GpsService _gpsService = GpsService();
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
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
              backgroundColor: const Color(0xFFB91C1C), // Solid Vibrant Rich Red (NO Glassmorphism)
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white30, width: 1.5),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER: Minimalist Title & Countdown Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.amberAccent, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Emergency SOS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),

                        // COUNTDOWN BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${_secondsRemaining}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // BODY: Simple, direct message (No unnecessary words)
                    const Text(
                      'Broadcasting emergency alert with your location to nearby devices.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // DISPATCH PROGRESS STATUS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amberAccent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Dispatching in $_secondsRemaining seconds...',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // CLICKABLE CANCEL BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7F1D1D),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.white30, width: 1),
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text(
                          'CANCEL ALERT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
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
                            const SnackBar(
                              content: Text('Emergency SOS cancelled.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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

    final pos = await _gpsService.getFreshBestPosition();
    final double lat = pos?.latitude ?? _gpsService.currentLatitude;
    final double lon = pos?.longitude ?? _gpsService.currentLongitude;

    final packet = MessagePacket(
      id: 'SOS-${_uuid.v4().substring(0, 6).toUpperCase()}',
      type: 'EMERGENCY',
      language: widget.selectedLanguage,
      text: _broadcastText,
      latitude: lat,
      longitude: lon,
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
                  '🚨 Emergency SOS broadcasted to nearby devices!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDC2626), // Vibrant Emergency Crimson Red Background
      appBar: AppBar(
        title: const Text(
          'Emergency SOS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFDC2626),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header Info Card (Vibrant rich crimson card, no hard edges)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'ONE-TAP EMERGENCY SOS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Broadcast high-priority distress alert with your live GPS location to all nearby mesh phones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade50,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Glowing Minimalist SOS Action Button (Smooth Pulsing Circle)
              Center(
                child: ScaleTransition(
                  scale: _hasSent || _isBroadcasting || _isCountdownActive
                      ? const AlwaysStoppedAnimation(1.0)
                      : _pulseAnimation,
                  child: GestureDetector(
                    onTap: _isBroadcasting ? null : _onSosButtonPressed,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _hasSent
                              ? [Colors.green.shade600, Colors.green.shade900]
                              : [const Color(0xFF7F1D1D), const Color(0xFF450A0A)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 6,
                          )
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasSent
                                  ? Icons.check_circle_outline
                                  : (_isBroadcasting
                                      ? Icons.sensors
                                      : Icons.touch_app_outlined),
                              color: Colors.white,
                              size: 56,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _hasSent
                                  ? 'SOS SENT'
                                  : (_isBroadcasting
                                      ? 'BROADCASTING...'
                                      : 'TAP FOR SOS'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Status Info Pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasSent ? Icons.wifi_tethering : Icons.info_outline,
                      color: _hasSent ? Colors.greenAccent : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasSent
                            ? 'SOS Active & Transmitting to Nearby Nodes'
                            : 'Tap button above to trigger 10s countdown broadcast',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _hasSent ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
