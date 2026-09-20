import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:jeevalink/models/message_packet.dart';
import 'package:jeevalink/services/native_bridge.dart';
import 'package:jeevalink/services/speech_model_registry.dart';
import 'package:jeevalink/stores/message_store.dart';
import 'package:jeevalink/stores/peer_store.dart';
import 'package:jeevalink/stores/settings_store.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('target_arch_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  });

  group('Target Architecture Tests', () {
    test('NativeBridge singleton creates single broadcast controller stream', () async {
      final bridge1 = NativeBridge();
      final bridge2 = NativeBridge();

      expect(identical(bridge1, bridge2), isTrue);

      bool received = false;
      bridge2.eventStream.listen((event) {
        if (event['type'] == 'TEST_EVENT') received = true;
      });

      bridge1.emitSimulatedEvent({'type': 'TEST_EVENT'});
      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, isTrue);
    });

    test('SpeechModelRegistry provides correct configurations per language', () {
      final enConfig = SpeechModelRegistry.getConfig('en');
      expect(enConfig.tokensFileName, equals('tokens.txt'));

      final hiConfig = SpeechModelRegistry.getConfig('hi');
      expect(hiConfig.tokensFileName, equals('hindi_tokens.txt'));

      final teConfig = SpeechModelRegistry.getConfig('te');
      expect(teConfig.tokensFileName, equals('telugu_tokens.txt'));

      final taConfig = SpeechModelRegistry.getConfig('ta');
      expect(taConfig.tokensFileName, equals('tamil_tokens.txt'));
    });

    test('SettingsStore updates language and notifies listeners', () async {
      final settings = SettingsStore();
      await Future.delayed(const Duration(milliseconds: 50));
      String? updatedLang;

      settings.addListener(() {
        updatedLang = settings.selectedLanguage;
      });

      await settings.setLanguage('hi');
      expect(settings.selectedLanguage, equals('hi'));
      expect(updatedLang, equals('hi'));
    });

    test('PeerStore handles simulated STATUS_CHANGED event', () async {
      final bridge = NativeBridge();
      final peerStore = PeerStore();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(peerStore.p2pStatus, equals('DISCONNECTED'));

      bridge.emitSimulatedEvent({
        'type': 'STATUS_CHANGED',
        'status': 'CONNECTED_CLIENT',
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(peerStore.p2pStatus, equals('CONNECTED_CLIENT'));
    });

    test('MessageStore handles simulated incoming message packet', () async {
      final bridge = NativeBridge();
      final messageStore = MessageStore();
      await Future.delayed(const Duration(milliseconds: 100));

      final packet = MessagePacket(
        id: 'TEST_PKT_999',
        type: 'NORMAL',
        language: 'en',
        text: 'Test emergency message',
        latitude: 13.0827,
        longitude: 80.2707,
        ttl: 3,
        timestamp: DateTime.now().toIso8601String(),
        senderId: 'PEER_ABC',
        senderName: 'Responder Node',
      );

      bridge.emitSimulatedEvent({
        'type': 'MESSAGE_RECEIVED',
        'payload': packet.toJson(),
      });

      await Future.delayed(const Duration(milliseconds: 100));
      final found = messageStore.messages.where((m) => m.id == 'TEST_PKT_999');
      expect(found.length, equals(1));
    });
  });
}
