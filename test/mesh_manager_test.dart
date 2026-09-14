import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:jeevalink/models/message_packet.dart';
import 'package:jeevalink/services/mesh_manager.dart';
import 'package:jeevalink/services/native_bridge.dart';

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

class MockNativeBridge extends NativeBridge {
  final List<MessagePacket> sentPackets = [];

  @override
  Future<bool> sendMessage(MessagePacket packet, {String? targetIp}) async {
    sentPackets.add(packet);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshManager Deduplication & Multi-Hop Relay Tests', () {
    late Directory tempDir;
    late MockNativeBridge mockBridge;
    late MeshManager meshManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lifelink_mesh_test_');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
      mockBridge = MockNativeBridge();
      meshManager = MeshManager(mockBridge);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Accepts new message ID and triggers onNewMessage callback', () {
      final packet = MessagePacket(
        id: 'MSG-100',
        type: 'EMERGENCY',
        language: 'en',
        text: 'Flood warning',
        latitude: 13.0827,
        longitude: 80.2707,
        ttl: 5,
        timestamp: '2026-09-07T15:00:00Z',
      );

      bool callbackFired = false;
      final accepted = meshManager.processIncomingPacket(
        packet,
        onNewMessage: (p) {
          callbackFired = true;
          expect(p.id, equals('MSG-100'));
        },
      );

      expect(accepted, isTrue);
      expect(callbackFired, isTrue);
      expect(meshManager.isSeen('MSG-100'), isTrue);
    });

    test('Drops duplicate message ID silently without callback or relaying', () {
      final packet = MessagePacket(
        id: 'MSG-100',
        type: 'EMERGENCY',
        language: 'en',
        text: 'Flood warning',
        latitude: 13.0827,
        longitude: 80.2707,
        ttl: 5,
        timestamp: '2026-09-07T15:00:00Z',
      );

      // Process once
      meshManager.processIncomingPacket(packet, onNewMessage: (_) {});
      mockBridge.sentPackets.clear();

      // Process duplicate
      bool callbackFired = false;
      final accepted = meshManager.processIncomingPacket(
        packet,
        onNewMessage: (_) {
          callbackFired = true;
        },
      );

      expect(accepted, isFalse);
      expect(callbackFired, isFalse);
      expect(mockBridge.sentPackets, isEmpty); // No duplicate forwarding
    });

    test('Decrements TTL by 1 when relaying to mesh peers', () {
      final packet = MessagePacket(
        id: 'MSG-200',
        type: 'NORMAL',
        language: 'hi',
        text: 'Water supply arriving',
        latitude: 13.0,
        longitude: 80.0,
        ttl: 3,
        timestamp: '2026-09-07T15:00:00Z',
      );

      meshManager.processIncomingPacket(packet, onNewMessage: (_) {});

      expect(mockBridge.sentPackets.length, equals(1));
      expect(mockBridge.sentPackets.first.id, equals('MSG-200'));
      expect(mockBridge.sentPackets.first.ttl, equals(2)); // TTL decremented 3 -> 2
    });

    test('Stops relaying when TTL reaches 0', () {
      final packet = MessagePacket(
        id: 'MSG-300',
        type: 'NORMAL',
        language: 'en',
        text: 'Final hop message',
        latitude: 13.0,
        longitude: 80.0,
        ttl: 1, // Will decrement to 0 on arrival
        timestamp: '2026-09-07T15:00:00Z',
      );

      meshManager.processIncomingPacket(packet, onNewMessage: (_) {});

      expect(mockBridge.sentPackets, isEmpty); // TTL 0 -> No re-broadcast
    });
  });
}
