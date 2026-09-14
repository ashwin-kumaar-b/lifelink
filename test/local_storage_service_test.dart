import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:jeevalink/models/message_packet.dart';
import 'package:jeevalink/services/local_storage_service.dart';

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
  late LocalStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lifelink_storage_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    storage = LocalStorageService();
    await storage.clearAll();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('LocalStorageService saves and loads messages correctly', () async {
    final packet = MessagePacket(
      id: 'TEST-1',
      type: 'NORMAL',
      language: 'en',
      text: 'Hello Local Storage',
      latitude: 13.0827,
      longitude: 80.2707,
      ttl: 3,
      timestamp: DateTime.now().toIso8601String(),
      isSelf: true,
    );

    await storage.saveMessage(packet);
    final loaded = await storage.loadMessages();

    expect(loaded.length, equals(1));
    expect(loaded.first.id, equals('TEST-1'));
    expect(loaded.first.text, equals('Hello Local Storage'));
  });

  test('LocalStorageService auto-prunes messages older than 24 hours', () async {
    final oldPacket = MessagePacket(
      id: 'OLD-1',
      type: 'NORMAL',
      language: 'en',
      text: 'Yesterday SOS',
      latitude: 13.0,
      longitude: 80.0,
      ttl: 1,
      timestamp: DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
    );

    final freshPacket = MessagePacket(
      id: 'FRESH-1',
      type: 'NORMAL',
      language: 'en',
      text: 'Fresh SOS',
      latitude: 13.0,
      longitude: 80.0,
      ttl: 1,
      timestamp: DateTime.now().toIso8601String(),
    );

    await storage.saveMessage(oldPacket);
    await storage.saveMessage(freshPacket);

    final loaded = await storage.loadMessages();
    expect(loaded.length, equals(1));
    expect(loaded.first.id, equals('FRESH-1'));
  });

  test('LocalStorageService deletes specific message manually and supports clearAll', () async {
    final packet1 = MessagePacket(
      id: 'M-1',
      type: 'NORMAL',
      language: 'en',
      text: 'Message 1',
      latitude: 0,
      longitude: 0,
      ttl: 1,
      timestamp: DateTime.now().toIso8601String(),
    );
    final packet2 = MessagePacket(
      id: 'M-2',
      type: 'NORMAL',
      language: 'en',
      text: 'Message 2',
      latitude: 0,
      longitude: 0,
      ttl: 1,
      timestamp: DateTime.now().toIso8601String(),
    );

    await storage.saveMessage(packet1);
    await storage.saveMessage(packet2);

    await storage.deleteMessage('M-1');
    var loaded = await storage.loadMessages();
    expect(loaded.length, equals(1));
    expect(loaded.first.id, equals('M-2'));

    await storage.clearAll();
    loaded = await storage.loadMessages();
    expect(loaded.isEmpty, isTrue);
  });
}
