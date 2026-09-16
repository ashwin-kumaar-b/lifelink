import 'dart:convert';

class MessagePacket {
  static const String currentAppVersion = 'v2.0-demo';
  static const String headerPrefix = 'JL2DEMO::';

  final String id;
  final String type; // "EMERGENCY" or "NORMAL"
  final String language;
  final String text;
  final double latitude;
  final double longitude;
  final int ttl;
  final String timestamp;
  final String appVersion;
  final bool isSelf;

  MessagePacket({
    required this.id,
    required this.type,
    required this.language,
    required this.text,
    required this.latitude,
    required this.longitude,
    required this.ttl,
    required this.timestamp,
    this.appVersion = currentAppVersion,
    this.isSelf = false,
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
      'appVersion': appVersion,
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
      appVersion: map['appVersion'] ?? 'v1.0-legacy',
    );
  }

  String toJson() => json.encode(toMap());

  /// Encodes message into JL2DEMO:: header container for version locking
  String toDemoEncodedJson() {
    final rawJson = toJson();
    final bytes = utf8.encode(rawJson);
    final base64Str = base64.encode(bytes);
    return '$headerPrefix$base64Str';
  }

  factory MessagePacket.fromJson(String source) {
    if (source.startsWith(headerPrefix)) {
      final base64Str = source.substring(headerPrefix.length).trim();
      final bytes = base64.decode(base64Str);
      final decodedJson = utf8.decode(bytes);
      return MessagePacket.fromMap(json.decode(decodedJson));
    }
    return MessagePacket.fromMap(json.decode(source));
  }
}
