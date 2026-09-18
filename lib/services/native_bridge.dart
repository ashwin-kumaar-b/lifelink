import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/message_packet.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.jeevalink/bridge');
  static const EventChannel _eventChannel = EventChannel('com.jeevalink/events');

  Stream<Map<dynamic, dynamic>>? _eventStream;
  final StreamController<Map<dynamic, dynamic>> _webStreamController =
      StreamController<Map<dynamic, dynamic>>.broadcast();

  Stream<Map<dynamic, dynamic>> get eventStream {
    if (kIsWeb) {
      return _webStreamController.stream;
    }
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<dynamic, dynamic>.from(event));
    return _eventStream!;
  }

  void emitSimulatedEvent(Map<String, dynamic> event) {
    if (kIsWeb) {
      _webStreamController.add(event);
    }
  }

  Future<bool> discoverPeers() async {
    if (kIsWeb) {
      // Simulate real web P2P peer discovery for browser testing
      await Future.delayed(const Duration(milliseconds: 300));
      _webStreamController.add({
        'type': 'PEERS_DISCOVERED',
        'peers': [
          {
            'deviceName': 'Pixel 8 Mesh Node',
            'deviceAddress': '3A:8B:9C:12:F4',
            'type': 'WIFI_DIRECT',
          },
          {
            'deviceName': 'Galaxy S24 Responder',
            'deviceAddress': '7F:2E:1B:44:A9',
            'type': 'BLUETOOTH',
          },
        ]
      });
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('discoverPeers');
      return result;
    } catch (e) {
      print('NativeBridge discoverPeers error: $e');
      return false;
    }
  }

  Future<bool> connectPeer(String deviceAddress) async {
    if (kIsWeb) {
      _webStreamController.add({
        'type': 'STATUS_CHANGED',
        'status': 'CONNECTED_CLIENT',
      });
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('connectPeer', {
        'deviceAddress': deviceAddress,
      });
      return result;
    } catch (e) {
      print('NativeBridge connectPeer error: $e');
      return false;
    }
  }

  Future<bool> disconnectPeer() async {
    if (kIsWeb) {
      _webStreamController.add({
        'type': 'STATUS_CHANGED',
        'status': 'DISCONNECTED',
      });
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('disconnectPeer');
      return result;
    } catch (e) {
      print('NativeBridge disconnectPeer error: $e');
      return false;
    }
  }

  Future<bool> sendMessage(MessagePacket packet, {String? targetIp}) async {
    if (kIsWeb) {
      // Simulate receiving packet back from peer for local web testing
      Future.delayed(const Duration(milliseconds: 600), () {
        _webStreamController.add({
          'type': 'MESSAGE_RECEIVED',
          'payload': packet.toJson(),
        });
      });
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('sendMessage', {
        if (targetIp != null) 'targetIp': targetIp,
        'jsonPayload': packet.toJson(),
      });
      return result;
    } catch (e) {
      print('NativeBridge sendMessage error: $e');
      return false;
    }
  }

  Future<bool> startSTT({String language = 'en-US'}) async {
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 2), () {
        _webStreamController.add({
          'type': 'STT_RESULT',
          'text': 'Emergency help needed near sector 4',
        });
      });
      return true;
    }
    try {
      final bool result = await _channel.invokeMethod('startSTT', {
        'language': language,
      });
      return result;
    } catch (e) {
      print('NativeBridge startSTT error: $e');
      return false;
    }
  }

  Future<bool> stopSTT() async {
    if (kIsWeb) return true;
    try {
      final bool result = await _channel.invokeMethod('stopSTT');
      return result;
    } catch (e) {
      print('NativeBridge stopSTT error: $e');
      return false;
    }
  }

  Future<bool> speakTTS(String text, {String language = 'en'}) async {
    if (kIsWeb) return true;
    try {
      final bool result = await _channel.invokeMethod('speakTTS', {
        'text': text,
        'language': language,
      });
      return result;
    } catch (e) {
      print('NativeBridge speakTTS error: $e');
      return false;
    }
  }

  Future<String> getGroupOwnerIp() async {
    if (kIsWeb) return '192.168.49.1';
    try {
      final String ip = await _channel.invokeMethod('getGroupOwnerIp');
      return ip;
    } catch (e) {
      print('NativeBridge getGroupOwnerIp error: $e');
      return '';
    }
  }

  Future<String> getDeviceId() async {
    if (kIsWeb) return 'WEB_DEV_NODE';
    try {
      final String id = await _channel.invokeMethod('getDeviceId');
      return id;
    } catch (e) {
      print('NativeBridge getDeviceId error: $e');
      return 'DEV_UNKNOWN';
    }
  }

  Future<bool> startBackgroundService() async {
    if (kIsWeb) return true;
    try {
      final bool result = await _channel.invokeMethod('startBackgroundService');
      return result;
    } catch (e) {
      print('NativeBridge startBackgroundService error: $e');
      return false;
    }
  }

  Future<bool> stopBackgroundService() async {
    if (kIsWeb) return true;
    try {
      final bool result = await _channel.invokeMethod('stopBackgroundService');
      return result;
    } catch (e) {
      print('NativeBridge stopBackgroundService error: $e');
      return false;
    }
  }

  Future<bool> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return true;
    try {
      final bool result = await _channel.invokeMethod('requestBatteryExemption');
      return result;
    } catch (e) {
      print('NativeBridge requestBatteryOptimizationExemption error: $e');
      return false;
    }
  }
}
