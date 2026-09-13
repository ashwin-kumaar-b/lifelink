import 'dart:collection';
import '../models/message_packet.dart';
import 'native_bridge.dart';

class MeshManager {
  final NativeBridge _bridge;
  final LinkedHashSet<String> _seenMessageIds = LinkedHashSet<String>();
  final List<MessagePacket> _storedMessageBuffer = <MessagePacket>[];
  static const int maxCacheSize = 1000;
  static const int maxStoredBuffer = 100;

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

    // Save to store-and-forward buffer for syncing with future newly connected peers
    _storePacket(packet);

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
        isSelf: false,
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
    _storePacket(packet);
  }

  void _storePacket(MessagePacket packet) {
    // Avoid duplicate storage in buffer
    _storedMessageBuffer.removeWhere((p) => p.id == packet.id);
    _storedMessageBuffer.insert(0, packet);
    if (_storedMessageBuffer.length > maxStoredBuffer) {
      _storedMessageBuffer.removeLast();
    }
  }

  /// Automatically syncs all stored historical messages when a new device connects/enters range
  Future<void> syncStoredPacketsToPeer() async {
    if (_storedMessageBuffer.isEmpty) return;

    print('MeshManager: New peer connected! Auto-syncing ${_storedMessageBuffer.length} stored packets...');
    for (var packet in _storedMessageBuffer) {
      if (packet.ttl > 0) {
        // Send stored packet to the newly connected peer
        await _bridge.sendMessage(packet);
        await Future.delayed(const Duration(milliseconds: 200)); // Brief delay between burst packets
      }
    }
  }

  bool isSeen(String messageId) => _seenMessageIds.contains(messageId);
}

