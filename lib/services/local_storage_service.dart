import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/message_packet.dart';
import 'native_bridge.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _fileName = 'messages_history.json';
  static const String _userConfigFile = 'user_config.json';
  final NativeBridge _bridge = NativeBridge();

  String? _cachedDeviceId;
  String? _cachedUsername;

  Future<File> _getFile(String name) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$name');
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return file;
  }

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    try {
      final nativeId = await _bridge.getDeviceId();
      if (nativeId.isNotEmpty && nativeId != 'DEV_UNKNOWN') {
        _cachedDeviceId = nativeId;
        return nativeId;
      }
    } catch (_) {}

    final configFile = await _getFile(_userConfigFile);
    if (await configFile.exists()) {
      try {
        final Map<String, dynamic> data = json.decode(await configFile.readAsString());
        if (data['deviceId'] != null && (data['deviceId'] as String).isNotEmpty) {
          _cachedDeviceId = data['deviceId'];
          return _cachedDeviceId!;
        }
      } catch (_) {}
    }

    final newId = 'NODE-${const Uuid().v4().substring(0, 6).toUpperCase()}';
    _cachedDeviceId = newId;
    await _updateConfig({'deviceId': newId});
    return newId;
  }

  Future<String> getUsername() async {
    if (_cachedUsername != null && _cachedUsername!.isNotEmpty) {
      return _cachedUsername!;
    }
    final configFile = await _getFile(_userConfigFile);
    if (await configFile.exists()) {
      try {
        final Map<String, dynamic> data = json.decode(await configFile.readAsString());
        if (data['username'] != null && (data['username'] as String).isNotEmpty) {
          _cachedUsername = data['username'];
          return _cachedUsername!;
        }
      } catch (_) {}
    }

    final devId = await getDeviceId();
    final defaultName = 'User-${devId.length >= 4 ? devId.substring(devId.length - 4) : devId}';
    _cachedUsername = defaultName;
    await _updateConfig({'username': defaultName});
    return defaultName;
  }

  Future<void> saveUsername(String username) async {
    final cleanName = username.trim();
    if (cleanName.isEmpty) return;
    _cachedUsername = cleanName;
    await _updateConfig({'username': cleanName});
  }

  Future<bool> hasSelectedLanguage() async {
    final configFile = await _getFile(_userConfigFile);
    if (await configFile.exists()) {
      try {
        final Map<String, dynamic> data = json.decode(await configFile.readAsString());
        return data['hasSelectedLanguage'] == true;
      } catch (_) {}
    }
    return false;
  }

  Future<String> getPreferredLanguage() async {
    final configFile = await _getFile(_userConfigFile);
    if (await configFile.exists()) {
      try {
        final Map<String, dynamic> data = json.decode(await configFile.readAsString());
        if (data['preferredLanguage'] != null && (data['preferredLanguage'] as String).isNotEmpty) {
          return data['preferredLanguage'];
        }
      } catch (_) {}
    }
    return 'en';
  }

  Future<void> savePreferredLanguage(String languageCode) async {
    await _updateConfig({
      'preferredLanguage': languageCode,
      'hasSelectedLanguage': true,
    });
  }

  Future<int> getPreferredTtl() async {
    final configFile = await _getFile(_userConfigFile);
    if (await configFile.exists()) {
      try {
        final Map<String, dynamic> data = json.decode(await configFile.readAsString());
        if (data['preferredTtl'] != null) {
          return (data['preferredTtl'] as num).toInt();
        }
      } catch (_) {}
    }
    return 3; // Default 3 hops
  }

  Future<void> savePreferredTtl(int ttl) async {
    await _updateConfig({
      'preferredTtl': ttl,
    });
  }


  Future<void> _updateConfig(Map<String, dynamic> updates) async {
    try {
      final configFile = await _getFile(_userConfigFile);
      Map<String, dynamic> current = {};
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        if (content.isNotEmpty) {
          current = json.decode(content);
        }
      }
      current.addAll(updates);
      await configFile.writeAsString(json.encode(current));
    } catch (e) {
      print('LocalStorageService config save error: $e');
    }
  }

  /// Loads all stored messages, automatically pruning any messages older than 24 hours.
  Future<List<MessagePacket>> loadMessages() async {
    try {
      final myDevId = await getDeviceId();
      final file = await _getFile(_fileName);
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      if (contents.isEmpty) return [];

      final List<dynamic> jsonList = json.decode(contents);
      final allMessages = jsonList
          .map((map) => MessagePacket.fromMap(map as Map<String, dynamic>, myDeviceId: myDevId))
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
      final file = await _getFile(_fileName);
      final jsonList = messages.map((m) => m.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('LocalStorageService: Error saving messages: $e');
    }
  }
}
