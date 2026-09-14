import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/message_packet.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _fileName = 'messages_history.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_fileName');
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return file;
  }

  /// Loads all stored messages, automatically pruning any messages older than 24 hours.
  Future<List<MessagePacket>> loadMessages() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      if (contents.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(contents);
      final allMessages = jsonList
          .map((map) => MessagePacket.fromMap(map as Map<String, dynamic>))
          .toList();

      // 24-Hour Auto-Pruning Filter
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final freshMessages = allMessages.where((msg) {
        try {
          final msgTime = DateTime.parse(msg.timestamp);
          return msgTime.isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();

      // If any messages were pruned, save updated fresh list
      if (freshMessages.length != allMessages.length) {
        await _saveList(freshMessages);
      }

      return freshMessages;
    } catch (e) {
      print('LocalStorageService: Error loading messages: $e');
      return [];
    }
  }

  /// Saves a single message to local storage (or updates if already exists).
  Future<void> saveMessage(MessagePacket packet) async {
    final messages = await loadMessages();
    final index = messages.indexWhere((m) => m.id == packet.id);
    if (index >= 0) {
      messages[index] = packet;
    } else {
      messages.add(packet);
    }
    await _saveList(messages);
  }

  /// Restores a list of messages (for Undo deletion support).
  Future<void> saveAll(List<MessagePacket> messages) async {
    await _saveList(messages);
  }

  /// Deletes a specific message manually by ID.
  Future<void> deleteMessage(String messageId) async {
    final messages = await loadMessages();
    messages.removeWhere((m) => m.id == messageId);
    await _saveList(messages);
  }

  /// Clears all stored messages from disk.
  Future<void> clearAll() async {
    final messages = <MessagePacket>[];
    await _saveList(messages);
  }

  Future<void> _saveList(List<MessagePacket> messages) async {
    try {
      final file = await _getFile();
      final jsonList = messages.map((m) => m.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('LocalStorageService: Error saving messages: $e');
    }
  }
}
