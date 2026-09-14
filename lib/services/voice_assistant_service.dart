import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'native_bridge.dart';

class VoiceAssistantService extends ChangeNotifier {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final NativeBridge _bridge = NativeBridge();

  bool _isHotwordEnabled = true;
  bool _autoStartRecording = true;
  bool _audioFeedback = true;
  bool _isOverlayGranted = false;
  bool _isHotwordServiceRunning = false;

  bool get isHotwordEnabled => _isHotwordEnabled;
  bool get autoStartRecording => _autoStartRecording;
  bool get audioFeedback => _audioFeedback;
  bool get isOverlayGranted => _isOverlayGranted;
  bool get isHotwordServiceRunning => _isHotwordServiceRunning;

  final StreamController<String> _assistantTriggerController = StreamController<String>.broadcast();
  Stream<String> get onAssistantTriggered => _assistantTriggerController.stream;

  Future<void> initialize() async {
    await checkPermissionsStatus();
    if (_isHotwordEnabled) {
      await startHotwordService();
    }
  }

  Future<void> checkPermissionsStatus() async {
    _isOverlayGranted = await _bridge.isOverlayGranted();
    notifyListeners();
  }

  void notifyTrigger(String triggerType) {
    _assistantTriggerController.add(triggerType);
  }

  Future<void> setHotwordEnabled(bool enabled) async {
    _isHotwordEnabled = enabled;
    if (enabled) {
      await startHotwordService();
    } else {
      await stopHotwordService();
    }
    notifyListeners();
  }

  Future<void> setAutoStartRecording(bool enabled) async {
    _autoStartRecording = enabled;
    notifyListeners();
  }

  Future<void> setAudioFeedback(bool enabled) async {
    _audioFeedback = enabled;
    notifyListeners();
  }

  Future<bool> startHotwordService() async {
    final success = await _bridge.startHotwordService();
    _isHotwordServiceRunning = success;
    notifyListeners();
    return success;
  }

  Future<bool> stopHotwordService() async {
    final success = await _bridge.stopHotwordService();
    _isHotwordServiceRunning = !success;
    notifyListeners();
    return success;
  }

  Future<bool> openAssistantSettings() async {
    return await _bridge.openAssistantSettings();
  }

  Future<bool> openOverlaySettings() async {
    final res = await _bridge.openOverlaySettings();
    await Future.delayed(const Duration(seconds: 1));
    await checkPermissionsStatus();
    return res;
  }

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    notifyListeners();
    return status.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    notifyListeners();
    return status.isGranted;
  }
}
