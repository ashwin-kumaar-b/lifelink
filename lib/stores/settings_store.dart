import 'package:flutter/foundation.dart';
import '../services/local_storage_service.dart';

enum SttModelStatus { unloaded, loading, ready, error }

class SettingsStore extends ChangeNotifier {
  static final SettingsStore _instance = SettingsStore._internal();
  factory SettingsStore() => _instance;
  SettingsStore._internal() {
    _init();
  }

  final LocalStorageService _storage = LocalStorageService();

  String _selectedLanguage = 'en';
  String _username = 'User';
  int _configuredTtl = 3;
  SttModelStatus _sttModelStatus = SttModelStatus.unloaded;
  String _sttErrorMessage = '';

  String get selectedLanguage => _selectedLanguage;
  String get username => _username;
  int get configuredTtl => _configuredTtl;
  SttModelStatus get sttModelStatus => _sttModelStatus;
  String get sttErrorMessage => _sttErrorMessage;

  Future<void> _init() async {
    _selectedLanguage = await _storage.getPreferredLanguage();
    _username = await _storage.getUsername();
    _configuredTtl = await _storage.getPreferredTtl();
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (_selectedLanguage == langCode) return;
    _selectedLanguage = langCode;
    await _storage.savePreferredLanguage(langCode);
    notifyListeners();
  }

  Future<void> setUsername(String name) async {
    _username = name;
    await _storage.saveUsername(name);
    notifyListeners();
  }

  Future<void> setTtl(int ttl) async {
    _configuredTtl = ttl;
    await _storage.savePreferredTtl(ttl);
    notifyListeners();
  }

  void setSttModelStatus(SttModelStatus status, {String errorMessage = ''}) {
    _sttModelStatus = status;
    _sttErrorMessage = errorMessage;
    notifyListeners();
  }
}
