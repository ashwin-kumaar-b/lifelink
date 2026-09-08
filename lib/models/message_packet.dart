import 'dart:convert';

class MessagePacket {
  final String id;
  final String type; // "EMERGENCY" or "NORMAL"
  final String language;
  final String text;
  final double latitude;
  final double longitude;
  final int ttl;
  final String timestamp;

  MessagePacket({
    required this.id,
    required this.type,
    required this.language,
    required this.text,
    required this.latitude,
    required this.longitude,
    required this.ttl,
    required this.timestamp,
  });

  bool get isEmergency => type == 'EMERGENCY';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'language': language,
      'text': text,
      'latitude': latitude,
      'longitude': longitude,
      'ttl': ttl,
      'timestamp': timestamp,
    };
  }

  factory MessagePacket.fromMap(Map<String, dynamic> map) {
    return MessagePacket(
      id: map['id'] ?? '',
      type: map['type'] ?? 'NORMAL',
      language: map['language'] ?? 'en',
      text: map['text'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      ttl: (map['ttl'] as num?)?.toInt() ?? 5,
      timestamp: map['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }

  String toJson() => json.encode(toMap());

  factory MessagePacket.fromJson(String source) =>
      MessagePacket.fromMap(json.decode(source));
}
