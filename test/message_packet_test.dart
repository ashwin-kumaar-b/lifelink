import 'package:flutter_test/flutter_test.dart';
import 'package:jeevalink/models/message_packet.dart';

void main() {
  group('MessagePacket Tests', () {
    test('MessagePacket serializes to JSON correctly', () {
      final packet = MessagePacket(
        id: 'MSG001',
        type: 'EMERGENCY',
        language: 'en',
        text: 'Fire near building',
        latitude: 13.0827,
        longitude: 80.2707,
        ttl: 5,
        timestamp: '2026-09-07T14:00:00Z',
      );

      final jsonStr = packet.toJson();
      expect(jsonStr.contains('"id":"MSG001"'), isTrue);
      expect(jsonStr.contains('"type":"EMERGENCY"'), isTrue);
      expect(jsonStr.contains('"text":"Fire near building"'), isTrue);
    });

    test('MessagePacket deserializes from JSON correctly', () {
      const jsonStr = '''
      {
        "id": "MSG002",
        "type": "NORMAL",
        "language": "hi",
        "text": "Need water supply",
        "latitude": 13.1000,
        "longitude": 80.2500,
        "ttl": 3,
        "timestamp": "2026-09-07T14:05:00Z"
      }
      ''';

      final packet = MessagePacket.fromJson(jsonStr);
      expect(packet.id, equals('MSG002'));
      expect(packet.type, equals('NORMAL'));
      expect(packet.isEmergency, isFalse);
      expect(packet.language, equals('hi'));
      expect(packet.text, equals('Need water supply'));
      expect(packet.latitude, equals(13.1000));
      expect(packet.longitude, equals(80.2500));
    });

    test('MessagePacket encodes and decodes with JL2DEMO:: version lock header', () {
      final packet = MessagePacket(
        id: 'MSG003',
        type: 'EMERGENCY',
        language: 'en',
        text: 'SOS Demo Lock Test',
        latitude: 13.0,
        longitude: 80.0,
        ttl: 1,
        timestamp: '2026-09-16T10:00:00Z',
      );

      final encoded = packet.toDemoEncodedJson();
      expect(encoded.startsWith('JL2DEMO::'), isTrue);

      final decodedPacket = MessagePacket.fromJson(encoded);
      expect(decodedPacket.id, equals('MSG003'));
      expect(decodedPacket.text, equals('SOS Demo Lock Test'));
      expect(decodedPacket.appVersion, equals('v2.0-demo'));
    });
  });
}
