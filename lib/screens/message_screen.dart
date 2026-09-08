import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';

enum MicState { idle, recording, processing, sent }

class MessageScreen extends StatefulWidget {
  final String selectedLanguage;

  const MessageScreen({
    super.key,
    required this.selectedLanguage,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final NativeBridge _bridge = NativeBridge();
  late final MeshManager _meshManager;
  final Uuid _uuid = const Uuid();
  final TextEditingController _textController = TextEditingController();

  StreamSubscription? _eventSubscription;

  MicState _micState = MicState.idle;
  bool _isEmergency = true;
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
                        'Received ${newPacket.type}: "${newPacket.text}"',
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
          // Auto-send after brief processing delay
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
            SnackBar(content: Text('Speech recording error: $err')),
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

  // --- Hold-to-Talk Gesture Handlers ---
  void _onMicPressStart() async {
    setState(() {
      _micState = MicState.recording;
      _currentTranscript = 'Recording... Hold mic button';
    });
    final sttCode = _sttLangCodeMap[widget.selectedLanguage] ?? 'en-US';
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
      type: _isEmergency ? 'EMERGENCY' : 'NORMAL',
      language: widget.selectedLanguage,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push-to-Talk Messaging'),
        centerTitle: true,
        actions: [
          Chip(
            label: Text(
              widget.selectedLanguage.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: Colors.red.shade100,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Emergency Priority Switch Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEmergency ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isEmergency ? Colors.red : Colors.blue,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isEmergency ? Icons.warning : Icons.info,
                        color: _isEmergency ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEmergency ? 'EMERGENCY PRIORITY' : 'NORMAL PRIORITY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isEmergency ? Colors.red.shade900 : Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isEmergency,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setState(() {
                        _isEmergency = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // PTT Mic Button Section (Hold to Record, Release to Send)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 12),
                Text(
                  _getMicStateText(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Manual text entry option
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: 'Or type message manually...',
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

          // Feed Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Message History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),

          // Message History Feed
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nHold mic to record or type text.',
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
                            'Lang: ${msg.language.toUpperCase()} | ID: ${msg.id} | TTL: ${msg.ttl}\nTime: ${msg.timestamp.substring(11, 19)}',
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
      ),
    );
  }
}
