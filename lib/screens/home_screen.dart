import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import '../services/gps_service.dart';
import '../services/local_storage_service.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';
import '../services/stt_tts_service.dart';
import '../utils/gps_calculator.dart';
import '../widgets/app_drawer.dart';

import 'radar_screen.dart';

enum MicState { idle, recording, processing, sent }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final NativeBridge _bridge = NativeBridge();

  final SttTtsService _sttTts = SttTtsService();
  final GpsService _gpsService = GpsService();
  final LocalStorageService _storage = LocalStorageService();
  final AudioPlayer _audioPlayer = AudioPlayer();
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
  String _p2pStatus = 'DISCONNECTED';
  String _connectedPeerName = '';
  String _myDeviceId = '';
  String _myUsername = 'User';
  int _configuredTtl = 3;

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
    _loadUserInfoAndMessages();
    _listenToNativeEvents();
    _sttTts.initialize();
    _gpsService.initialize();
  }

  Future<void> _loadUserInfoAndMessages() async {
    final devId = await _storage.getDeviceId();
    final username = await _storage.getUsername();
    final prefLang = await _storage.getPreferredLanguage();
    final prefTtl = await _storage.getPreferredTtl();
    final hasSelected = await _storage.hasSelectedLanguage();
    final storedMessages = await _storage.loadMessages();

    if (mounted) {
      setState(() {
        _myDeviceId = devId;
        _myUsername = username;
        _selectedLanguage = prefLang;
        _configuredTtl = prefTtl;
        _messages.clear();
        _messages.addAll(storedMessages.reversed);
      });


      if (!hasSelected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLanguageOnboardingDialog();
        });
      }
    }
  }

  void _showLanguageOnboardingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String tempSelected = _selectedLanguage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Column(
                children: [
                  Icon(Icons.translate, color: Colors.red, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Welcome to JeevaLink',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select your primary language for offline speech & translation:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLanguageOptionTile('en', 'English (Default)', Icons.language, tempSelected, (val) {
                    setDialogState(() => tempSelected = val);
                  }),
                  _buildLanguageOptionTile('ta', 'Tamil (தமிழ்)', Icons.record_voice_over, tempSelected, (val) {
                    setDialogState(() => tempSelected = val);
                  }),
                  _buildLanguageOptionTile('hi', 'Hindi (हिंदी)', Icons.record_voice_over, tempSelected, (val) {
                    setDialogState(() => tempSelected = val);
                  }),
                  _buildLanguageOptionTile('te', 'Telugu (తెలుగు)', Icons.record_voice_over, tempSelected, (val) {
                    setDialogState(() => tempSelected = val);
                  }),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await _storage.savePreferredLanguage(tempSelected);
                      if (mounted) {
                        setState(() {
                          _selectedLanguage = tempSelected;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Primary language set to ${tempSelected.toUpperCase()}')),
                        );
                      }
                    },
                    child: const Text('CONFIRM LANGUAGE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOptionTile(String code, String name, IconData icon, String currentSelected, ValueChanged<String> onSelect) {
    final bool isSelected = currentSelected == code;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.red.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.red : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.red : Colors.grey),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.red.shade900 : Colors.black87,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.red) : null,
        onTap: () => onSelect(code),
      ),
    );
  }

  void _listenToNativeEvents() {
    _eventSubscription = _bridge.eventStream.listen((event) {
      final String type = event['type'] ?? '';
      switch (type) {
        case 'MESSAGE_RECEIVED':
          final String rawPayload = event['payload'] ?? '';
          if (rawPayload.isNotEmpty) {
            try {
              final packet = MessagePacket.fromJson(rawPayload, myDeviceId: _myDeviceId);
              _meshManager.processIncomingPacket(
                packet,
                onNewMessage: (newPacket) {
                  setState(() {
                    _messages.removeWhere((m) => m.id == newPacket.id);
                    _messages.insert(0, newPacket);
                  });
                  _sttTts.speak(
                    newPacket.text,
                    language: _sttLangCodeMap[newPacket.language] ?? 'en-US',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Incoming ${newPacket.type} from ${newPacket.senderName}: "${newPacket.text}"',
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
        case 'STATUS_CHANGED':
          final String status = event['status'] ?? '';
          if (mounted) {
            setState(() {
              _p2pStatus = status;
            });
          }
          break;
        case 'PEER_CONNECTED':
        case 'PEER_DISCOVERED':
          final String peerName = event['peerName'] ?? 'New Peer';
          if (mounted) {
            setState(() {
              _p2pStatus = 'CONNECTED';
              _connectedPeerName = peerName;
            });
          }
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
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playWhooshSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('sounds/clear_all_whoosh.wav'),
        position: const Duration(milliseconds: 200),
      );
    } catch (e) {
      print('AudioPlayer whoosh sound error: $e');
    }
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
    final targetLocale = _sttLangCodeMap[_selectedLanguage] ?? 'en-US';
    setState(() {
      _micState = MicState.recording;
      _currentTranscript = 'Listening for ${_selectedLanguage.toUpperCase()}... Speak now!';
    });

    await _sttTts.loadModelForLanguage(_selectedLanguage);

    final recordOk = await _sttTts.startRecording();
    if (!recordOk) {
      final ok = await _bridge.startSTT(language: targetLocale);
      if (!ok && mounted) {
        setState(() {
          _micState = MicState.idle;
          _currentTranscript = 'Microphone permission denied or speech engine unavailable.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied or speech engine unavailable.')),
        );
      }
    }
  }

  void _onMicPressEnd() async {
    if (_micState == MicState.recording) {
      setState(() {
        _micState = MicState.processing;
        _currentTranscript = 'Decoding speech wave with Multilingual Sherpa-ONNX...';
      });

      if (_sttTts.isRecording) {
        final String transcribedText = await _sttTts.stopAndTranscribe();
        if (transcribedText.isNotEmpty) {
          _processDecodedText(transcribedText);
        } else {
          await _bridge.stopSTT();
          if (mounted && _micState == MicState.processing) {
            setState(() {
              _micState = MicState.idle;
            });
          }
        }
      } else {
        await _bridge.stopSTT();
      }
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

    // Trigger background GPS location update (non-blocking)
    _gpsService.getFreshBestPosition();

    final packet = MessagePacket(
      id: 'MSG-${_uuid.v4().substring(0, 6).toUpperCase()}',
      type: _isEmergencyMode ? 'EMERGENCY' : 'NORMAL',
      language: _selectedLanguage,
      text: textToSend,
      latitude: _gpsService.currentLatitude,
      longitude: _gpsService.currentLongitude,
      ttl: _configuredTtl,
      timestamp: DateTime.now().toIso8601String(),

      senderId: _myDeviceId,
      senderName: _myUsername,
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

  void _deleteSingleMessage(MessagePacket msg, int originalIndex) async {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    await _storage.deleteMessage(msg.id);

    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted message "${msg.text}"'),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amber,
            onPressed: () async {
              SystemSound.play(SystemSoundType.click);
              await _storage.saveMessage(msg);
              setState(() {
                _messages.insert(originalIndex.clamp(0, _messages.length), msg);
              });
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showEditUsernameDialog() async {
    final textController = TextEditingController(text: _myUsername);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit Username / Device Name'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This device name will be shown to nearby phones on Radar and in Push Notifications.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Your Username / Device Name',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Devesh, Phone A, Leader',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = textController.text.trim();
                if (newName.isNotEmpty) {
                  await _storage.saveUsername(newName);
                  if (mounted) {
                    setState(() {
                      _myUsername = newName;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Device name updated to "$newName"')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showMessageDetailDialog(MessagePacket msg) {
    final distMeters = GpsCalculator.calculateDistanceMeters(
      _gpsService.currentLatitude,
      _gpsService.currentLongitude,
      msg.latitude,
      msg.longitude,
    );
    final formattedDist = GpsCalculator.formatDistance(distMeters);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Message Details',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 550),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: msg.isEmergency ? Colors.red.shade100 : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        msg.isEmergency ? '🚨 EMERGENCY SOS' : '💬 NORMAL MESH MSG',
                        style: TextStyle(
                          color: msg.isEmergency ? Colors.red.shade900 : Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  msg.isSelf ? 'You (${msg.senderName})' : msg.senderName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  'Sender Node: ${msg.senderId.isNotEmpty ? msg.senderId : msg.id}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: msg.isEmergency ? Colors.red.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: msg.isEmergency ? Colors.red.shade200 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '"${msg.text}"',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: msg.isEmergency ? Colors.red.shade900 : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetadataRow(Icons.access_time_rounded, 'Received Time', DateTime.tryParse(msg.timestamp)?.toLocal().toString().substring(11, 19) ?? msg.timestamp),
                _buildMetadataRow(Icons.location_on_rounded, 'GPS Coordinates', '${msg.latitude.toStringAsFixed(4)}, ${msg.longitude.toStringAsFixed(4)} ($formattedDist away)'),
                _buildMetadataRow(Icons.alt_route_rounded, 'Multi-Hop Propagation', '${msg.ttl} Hops remaining'),
                _buildMetadataRow(Icons.translate_rounded, 'Language Payload', msg.language.toUpperCase()),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: msg.isEmergency ? Colors.red.shade700 : Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _sttTts.speak(msg.text, language: _sttLangCodeMap[msg.language] ?? 'en-US');
                    },
                    icon: const Icon(Icons.volume_up_rounded, size: 20),
                    label: const Text('Read Message Aloud', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetadataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllHistory() {

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear 24h History?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all stored local message logs from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              SystemSound.play(SystemSoundType.click);
              Navigator.pop(ctx);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.vibrate();
              _playWhooshSound();
              await _storage.clearAll();
              setState(() {
                _messages.clear();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All 24h local message history cleared.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );
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

  Widget _buildP2pStatusBar() {
    final bool isConnected = _p2pStatus.contains('CONNECTED') || _p2pStatus.contains('GROUP_OWNER');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isConnected ? Colors.green.shade800 : Colors.orange.shade900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isConnected
                    ? '⚡ P2P MESH ACTIVE (${_connectedPeerName.isNotEmpty ? _connectedPeerName : "Peer Connected"})'
                    : '🔍 Off-Grid P2P: ${_p2pStatus.replaceAll('_', ' ')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              _bridge.discoverPeers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Scanning nearby Wi-Fi Direct P2P nodes...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'RESCAN',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPttView() {
    return Column(
      children: [
        _buildP2pStatusBar(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
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

                // BOTTOM: Feed Header & Clear All Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '24h Local Mesh Feed',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (_messages.isNotEmpty)
                        TextButton.icon(
                          onPressed: _confirmClearAllHistory,
                          icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                          label: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),

                // BOTTOM: Message Feed List
                _messages.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No messages in 24h history.\nHold mic to record or type text.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return Dismissible(
                            key: Key(msg.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'DELETE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.delete_forever, color: Colors.white, size: 24),
                                ],
                              ),
                            ),
                            onDismissed: (_) => _deleteSingleMessage(msg, index),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: msg.isEmergency ? Colors.red.shade300 : Colors.grey.shade200,
                                  width: msg.isEmergency ? 1.5 : 1,
                                ),
                              ),
                              color: msg.isEmergency ? Colors.red.shade50 : Colors.white,
                              child: ListTile(
                                onTap: () => _showMessageDetailDialog(msg),
                                leading: Icon(

                                  msg.isEmergency ? Icons.warning_amber_rounded : Icons.chat_bubble_outline,
                                  color: msg.isEmergency ? Colors.red : Colors.blue,
                                ),
                                title: Text(
                                  msg.text,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: msg.isEmergency ? Colors.red.shade900 : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      'From: ${msg.isSelf ? "You (${msg.senderName})" : msg.senderName} | Lang: ${msg.language.toUpperCase()} | TTL: ${msg.ttl}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    Text(
                                      'Time: ${DateTime.tryParse(msg.timestamp)?.toLocal().toString().substring(11, 19) ?? msg.timestamp} | GPS: ${msg.latitude.toStringAsFixed(4)}, ${msg.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: msg.isEmergency ? Colors.red : Colors.lightBlue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        msg.type,
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up, size: 20, color: Colors.black54),
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
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildMainPttView(),
      ),
    );
  }
}

