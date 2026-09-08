import 'dart:collection';
import '../models/message_packet.dart';
import 'native_bridge.dart';

class MeshManager {
  final NativeBridge _bridge;
  final LinkedHashSet<String> _seenMessageIds = LinkedHashSet<String>();
  static const int maxCacheSize = 1000;

  MeshManager(this._bridge);

  /// Returns true if the packet is NEW (not seen before) and should be processed by the app.
  /// Returns false if the packet was ALREADY SEEN (duplicate dropped).
  bool processIncomingPacket(
    MessagePacket packet, {
    required Function(MessagePacket) onNewMessage,
  }) {
    if (_seenMessageIds.contains(packet.id)) {
      print('MeshManager: Duplicate message ID detected [${packet.id}]. Dropping packet silently.');
      return false;
    }

    // Add to seen cache (prune if exceeds max capacity)
    _seenMessageIds.add(packet.id);
    if (_seenMessageIds.length > maxCacheSize) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }

    // Notify application to display & speak message
    onNewMessage(packet);

    // Multi-Hop Store-and-Forward / Auto-Relay Logic
    final int remainingTtl = packet.ttl - 1;
    if (remainingTtl > 0) {
      print('MeshManager: Relaying message [${packet.id}] to nearby mesh peers. New TTL: $remainingTtl');
      final relayedPacket = MessagePacket(
        id: packet.id,
        type: packet.type,
        language: packet.language,
        text: packet.text,
        latitude: packet.latitude,
        longitude: packet.longitude,
        ttl: remainingTtl,
        timestamp: packet.timestamp,
      );

      // Re-broadcast relayed packet to nearby devices
      _bridge.sendMessage(relayedPacket);
    } else {
      print('MeshManager: TTL expired (0) for message [${packet.id}]. Stopping relay.');
    }

    return true;
  }

  void registerSentMessage(MessagePacket packet) {
    _seenMessageIds.add(packet.id);
    if (_seenMessageIds.length > maxCacheSize) {
      _seenMessageIds.remove(_seenMessageIds.first);
    }
  }

  bool isSeen(String messageId) => _seenMessageIds.contains(messageId);
}
