import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import '../services/gps_service.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';
import '../services/stt_tts_service.dart';
import '../widgets/app_drawer.dart';
import 'radar_screen.dart';

enum MicState { idle, recording, processing, sent }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NativeBridge _bridge = NativeBridge();
  final SttTtsService _sttTts = SttTtsService();
  final GpsService _gpsService = GpsService();
  late final MeshManager _meshManager;
  final Uuid _uuid = const Uuid();
  final TextEditingController _textController = TextEditingController();

  StreamSubscription? _eventSubscription;

  // App State
  int _currentTabIndex = 0;
  String _selectedLanguage = 'en';
  bool _isEmergencyMode = false;
  MicState _micState = MicState.idle;
  String _currentTranscript = '';

  final List<MessagePacket> _messages = [];

  final Map<String, String> _sttLangCodeMap = {
    'en': 'en-US',
    'hi': 'hi-IN',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'kn': 'kn-IN',
    'ml': 'ml-IN',
    'bn': 'bn-IN',
    'mr': 'mr-IN',
    'gu': 'gu-IN',
    'or': 'or-IN',
  };

  @override
  void initState() {
    super.initState();
    _meshManager = MeshManager(_bridge);
    _listenToNativeEvents();
    _sttTts.initialize();
    _gpsService.initialize();
  }

  void _listenToNativeEvents() {
    _eventSubscription = _bridge.eventStream.listen((event) {
      final String type = event['type'] ?? '';
      switch (type) {
        case 'MESSAGE_RECEIVED':
          final String rawPayload = event['payload'] ?? '';
          if (rawPayload.isNotEmpty) {
            try {
              final packet = MessagePacket.fromJson(rawPayload);
              _meshManager.processIncomingPacket(
                packet,
                onNewMessage: (newPacket) {
                  setState(() {
                    _messages.insert(0, newPacket);
                  });
                  _sttTts.speak(
                    newPacket.text,
                    language: _sttLangCodeMap[newPacket.language] ?? 'en-US',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Incoming ${newPacket.type} [${newPacket.id}]: "${newPacket.text}"',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor:
                          newPacket.isEmergency ? Colors.red : Colors.green,
                    ),
                  );
                },
              );
            } catch (e) {
              print('Failed to parse incoming payload: $e');
            }
          }
          break;
        case 'STT_RESULT':
          final String text = event['text'] ?? '';
          _processDecodedText(text);
          break;
        case 'STT_ERROR':
          final String err = event['error'] ?? 'STT Error';
          setState(() {
            _micState = MicState.idle;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech error: $err')),
          );
          break;
        case 'PEER_CONNECTED':
        case 'PEER_DISCOVERED':
          final String peerName = event['peerName'] ?? 'New Peer';
          print('HomeScreen: Peer connected/discovered [$peerName]. Auto-syncing stored messages...');
          _meshManager.syncStoredPacketsToPeer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ Connected to $peerName. Syncing emergency history...'),
              backgroundColor: Colors.blueAccent,
              duration: const Duration(seconds: 3),
            ),
          );
          break;
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  // --- Offline Hold & Tap Mic Gesture Handlers ---
  void _toggleMicRecording() async {
    if (_micState == MicState.recording) {
      _onMicPressEnd();
    } else if (_micState == MicState.idle) {
      _onMicPressStart();
    }
  }

  void _onMicPressStart() async {
    final ok = await _sttTts.startRecording();
    if (ok) {
      setState(() {
        _micState = MicState.recording;
        _currentTranscript = 'Recording audio wave... Speak now!';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied or unavailable.')),
      );
    }
  }

  void _onMicPressEnd() async {
    if (_micState == MicState.recording) {
      setState(() {
        _micState = MicState.processing;
        _currentTranscript = 'Processing audio wave with Sherpa-ONNX...';
      });

      final String transcribedText = await _sttTts.stopAndTranscribe();
      _processDecodedText(transcribedText);
    }
  }

  void _processDecodedText(String text) {
    if (text.isEmpty) {
      setState(() {
        _micState = MicState.idle;
        _currentTranscript = 'No speech recognized. Tap mic and try speaking again.';
      });
      return;
    }

    final keyword = _sttTts.checkEmergencyKeyword(text);

    setState(() {
      _micState = MicState.idle;
      _currentTranscript = text;
      _textController.text = text;
      if (keyword != null) {
        _isEmergencyMode = true;
      }
    });

    if (keyword != null) {
      _sttTts.speak('Emergency keyword $keyword detected!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚨 EMERGENCY KEYWORD "$keyword" DETECTED! Priority set to High.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _sendMessagePacket() async {
    final String textToSend = _textController.text.trim();
    if (textToSend.isEmpty) {
      setState(() {
        _micState = MicState.idle;
      });
      return;
    }

    // Acquire fresh high-precision satellite GPS location
    await _gpsService.getFreshBestPosition();

    final packet = MessagePacket(
      id: 'MSG-${_uuid.v4().substring(0, 6).toUpperCase()}',
      type: _isEmergencyMode ? 'EMERGENCY' : 'NORMAL',
      language: _selectedLanguage,
      text: textToSend,
      latitude: _gpsService.currentLatitude,
      longitude: _gpsService.currentLongitude,
      ttl: 2,
      timestamp: DateTime.now().toIso8601String(),
      isSelf: true,
    );

    _meshManager.registerSentMessage(packet);
    await _bridge.sendMessage(packet);

    setState(() {
      _micState = MicState.sent;
      _messages.insert(0, packet);
      _textController.clear();
      _currentTranscript = '';
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _micState = MicState.idle;
        });
      }
    });
  }

  void _toggleEmergencyMode(bool enabled) {
    setState(() {
      _isEmergencyMode = enabled;
    });

    if (enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'EMERGENCY MODE ACTIVATED! All outgoing broadcasts are tagged high priority.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getMicColor() {
    switch (_micState) {
      case MicState.idle:
        return Colors.blue.shade700;
      case MicState.recording:
        return Colors.red.shade600;
      case MicState.processing:
        return Colors.orange.shade600;
      case MicState.sent:
        return Colors.green.shade600;
    }
  }

  String _getMicStateText() {
    switch (_micState) {
      case MicState.idle:
        return 'TAP OR HOLD MIC TO SPEAK';
      case MicState.recording:
        return 'RECORDING... (TAP AGAIN TO STOP)';
      case MicState.processing:
        return 'PROCESSING SPEECH TO TEXT...';
      case MicState.sent:
        return 'SENT TO MESH!';
    }
  }

  Widget _buildMainPttView() {
    return Column(
      children: [
        // TOP: Emergency Mode Toggle Switch & Notification Banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _isEmergencyMode ? Colors.red.shade900 : Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isEmergencyMode ? Icons.warning : Icons.shield,
                        color: _isEmergencyMode ? Colors.white : Colors.blue.shade900,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEmergencyMode ? 'EMERGENCY MODE ON' : 'NORMAL MODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _isEmergencyMode ? Colors.white : Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isEmergencyMode,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.red.shade500,
                    onChanged: _toggleEmergencyMode,
                  ),
                ],
              ),
              if (_isEmergencyMode) ...[
                const SizedBox(height: 4),
                const Text(
                  '🚨 Emergency Notification Active: Messages broadcast as Urgent SOS',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ],
          ),
        ),

        // MIDDLE: Push-To-Talk Mic Button + Text Input
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _toggleMicRecording,
                onLongPressStart: (_) => _onMicPressStart(),
                onLongPressEnd: (_) => _onMicPressEnd(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _micState == MicState.recording ? 110 : 90,
                  height: _micState == MicState.recording ? 110 : 90,
                  decoration: BoxDecoration(
                    color: _getMicColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getMicColor().withOpacity(0.4),
                        blurRadius: _micState == MicState.recording ? 20 : 10,
                        spreadRadius: _micState == MicState.recording ? 6 : 2,
                      )
                    ],
                  ),
                  child: Icon(
                    _micState == MicState.sent
                        ? Icons.check
                        : (_micState == MicState.recording ? Icons.mic : Icons.mic_none),
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _getMicStateText(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _getMicColor(),
                ),
              ),
              if (_currentTranscript.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _currentTranscript,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: 'Speech Transcript / Text Message',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: _sendMessagePacket,
                  ),
                ),
              ),
            ],
          ),
        ),

        // BOTTOM: Feed Header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Live Mesh Messages Feed (Sent & Received)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),

        // BOTTOM: Message Feed List
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages sent or received yet.\nHold mic to record or type text.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return Card(
                      color: msg.isEmergency
                          ? Colors.red.shade50
                          : Colors.grey.shade100,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          msg.isEmergency
                              ? Icons.warning_amber
                              : Icons.chat_bubble_outline,
                          color: msg.isEmergency ? Colors.red : Colors.blue,
                        ),
                        title: Text(
                          msg.text,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: msg.isEmergency
                                ? Colors.red.shade900
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Lang: ${msg.language.toUpperCase()} | ID: ${msg.id} | TTL: ${msg.ttl}\nTime: ${msg.timestamp.substring(11, 19)} | GPS: ${msg.latitude}, ${msg.longitude}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                msg.type,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor:
                                  msg.isEmergency ? Colors.red : Colors.blue,
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: const Icon(Icons.volume_up, size: 20),
                              tooltip: 'TTS Playback',
                              onPressed: () {
                                _sttTts.speak(
                                  msg.text,
                                  language: _sttLangCodeMap[msg.language] ?? 'en-US',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTabIndex == 0 ? 'JeevaLink PTT Chat' : 'Nearby Radar Map'),
        centerTitle: true,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _currentTabIndex = _currentTabIndex == 1 ? 0 : 1;
              });
            },
            icon: Icon(
              _currentTabIndex == 1 ? Icons.forum : Icons.radar,
              color: _currentTabIndex == 1 ? Colors.blue : Colors.green,
              size: 20,
            ),
            label: Text(
              _currentTabIndex == 1 ? 'CHAT' : 'RADAR',
              style: TextStyle(
                color: _currentTabIndex == 1 ? Colors.blue : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentTabIndex == 1 ? Colors.blue.shade50 : Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(
              _selectedLanguage.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: Colors.red.shade100,
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        selectedLanguage: _selectedLanguage,
        onLanguageChanged: (newLang) {
          setState(() {
            _selectedLanguage = newLang;
          });
        },
        currentRoute: _currentTabIndex == 0 ? 'home' : 'radar',
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildMainPttView(),
          RadarScreen(
            selectedLanguage: _selectedLanguage,
            messages: _messages,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        selectedItemColor: Colors.red.shade900,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'PTT Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Nearby Radar Map',
          ),
        ],
      ),
    );
  }
}
