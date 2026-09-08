import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';
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
                  _bridge.speakTTS(
                    newPacket.text,
                    language: newPacket.language,
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
          setState(() {
            _micState = MicState.processing;
            _currentTranscript = text;
            _textController.text = text;
          });
          Future.delayed(const Duration(milliseconds: 400), () {
            _sendMessagePacket();
          });
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
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onMicPressStart() async {
    setState(() {
      _micState = MicState.recording;
      _currentTranscript = 'Recording speech... Hold mic button';
    });
    final sttCode = _sttLangCodeMap[_selectedLanguage] ?? 'en-US';
    await _bridge.startSTT(language: sttCode);
  }

  void _onMicPressEnd() async {
    if (_micState == MicState.recording) {
      setState(() {
        _micState = MicState.processing;
        _currentTranscript = 'Processing speech to text...';
      });
      await _bridge.stopSTT();
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

    final packet = MessagePacket(
      id: 'MSG-${_uuid.v4().substring(0, 6).toUpperCase()}',
      type: _isEmergencyMode ? 'EMERGENCY' : 'NORMAL',
      language: _selectedLanguage,
      text: textToSend,
      latitude: 13.0827,
      longitude: 80.2707,
      ttl: 5,
      timestamp: DateTime.now().toIso8601String(),
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
        return 'HOLD MIC TO SPEAK';
      case MicState.recording:
        return 'RECORDING... (RELEASE TO SEND)';
      case MicState.processing:
        return 'PROCESSING STT...';
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
                                _bridge.speakTTS(msg.text,
                                    language: msg.language);
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
