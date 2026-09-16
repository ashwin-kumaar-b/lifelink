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
  final String senderId;
  final String senderName;
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
    this.senderId = '',
    this.senderName = 'Peer Node',
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
      'senderId': senderId,
      'senderName': senderName,
    };
  }

  factory MessagePacket.fromMap(Map<String, dynamic> map, {String? myDeviceId}) {
    final sId = map['senderId'] as String? ?? '';
    final isOwn = (myDeviceId != null && myDeviceId.isNotEmpty && sId == myDeviceId);
    final rawName = map['senderName'] as String? ?? '';
    return MessagePacket(
      id: map['id'] ?? '',
      type: map['type'] ?? 'NORMAL',
      language: map['language'] ?? 'en',
      text: map['text'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      ttl: (map['ttl'] as num?)?.toInt() ?? 5,
      timestamp: map['timestamp'] ?? DateTime.now().toIso8601String(),
      senderId: sId,
      senderName: rawName.trim().isNotEmpty ? rawName.trim() : 'Peer Node',
      isSelf: isOwn || (map['isSelf'] == true),
    );
  }

  String toJson() => json.encode(toMap());

  factory MessagePacket.fromJson(String source, {String? myDeviceId}) =>
      MessagePacket.fromMap(json.decode(source) as Map<String, dynamic>, myDeviceId: myDeviceId);
}
