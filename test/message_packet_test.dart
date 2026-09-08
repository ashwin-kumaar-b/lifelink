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
      expect(packet.ttl, equals(3));
    });
  });
}
