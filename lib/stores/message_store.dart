import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_packet.dart';
import '../services/local_storage_service.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';
import '../services/stt_tts_service.dart';

class MessageStore extends ChangeNotifier {
  static final MessageStore _instance = MessageStore._internal();
  factory MessageStore() => _instance;
  MessageStore._internal() {
    _init();
  }

  final NativeBridge _bridge = NativeBridge();
  final LocalStorageService _storage = LocalStorageService();
  final SttTtsService _sttTts = SttTtsService();
  late final MeshManager _meshManager;

  final List<MessagePacket> _messages = [];
  String _myDeviceId = '';
  StreamSubscription? _eventSubscription;
  bool _isInitialized = false;

  List<MessagePacket> get messages => List.unmodifiable(_messages);
  String get myDeviceId => _myDeviceId;
  bool get isInitialized => _isInitialized;

  Future<void> _init() async {
    _meshManager = MeshManager(_bridge);
    _myDeviceId = await _storage.getDeviceId();
    final storedMessages = await _storage.loadMessages();
    _messages.clear();
    _messages.addAll(storedMessages.reversed);
    _isInitialized = true;
    notifyListeners();

    _eventSubscription = _bridge.eventStream.listen(_handleNativeEvent);
  }

  void _handleNativeEvent(Map<dynamic, dynamic> event) {
    final String type = event['type'] ?? '';
    if (type == 'MESSAGE_RECEIVED') {
      final String rawPayload = event['payload'] ?? '';
      if (rawPayload.isNotEmpty) {
        try {
          final packet = MessagePacket.fromJson(rawPayload, myDeviceId: _myDeviceId);
          _meshManager.processIncomingPacket(
            packet,
            onNewMessage: (newPacket) {
              _messages.removeWhere((m) => m.id == newPacket.id);
              _messages.insert(0, newPacket);
              notifyListeners();

              if (!newPacket.isSelf && newPacket.text.isNotEmpty) {
                _sttTts.speak(
                  newPacket.text,
                  language: newPacket.language,
                );
              }
            },
          );
        } catch (e) {
          debugPrint('MessageStore incoming packet error: $e');
        }
      }
    }
  }

  void addMessage(MessagePacket packet) {
    _messages.removeWhere((m) => m.id == packet.id);
    _messages.insert(0, packet);
    _storage.saveMessage(packet);
    notifyListeners();
  }

  void deleteMessage(String id) {
    _messages.removeWhere((m) => m.id == id);
    _storage.deleteMessage(id);
    notifyListeners();
  }

  void clearAllMessages() {
    _messages.clear();
    _storage.clearAllMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
