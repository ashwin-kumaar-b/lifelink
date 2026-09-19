import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_packet.dart';
import '../services/local_storage_service.dart';
import '../services/mesh_manager.dart';
import '../services/native_bridge.dart';
import '../services/stt_tts_service.dart';
import 'emergency_panic_screen.dart';
import 'home_screen.dart';
import 'radar_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String selectedLanguage;

  const MainNavigationScreen({
    super.key,
    this.selectedLanguage = 'en',
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late PageController _pageController;
  int _currentIndex = 1; // Default landing index: 1 (Home Page)
  late String _currentLanguage;

  final NativeBridge _bridge = NativeBridge();
  final LocalStorageService _storage = LocalStorageService();
  final SttTtsService _sttTts = SttTtsService();
  late final MeshManager _meshManager;

  StreamSubscription? _eventSubscription;
  final List<MessagePacket> _messages = [];
  String _myDeviceId = '';

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.selectedLanguage;
    _pageController = PageController(initialPage: _currentIndex);
    _meshManager = MeshManager(_bridge);

    _sttTts.initialize();
    _loadSavedLanguage();
    _initCentralizedMesh();
  }

  Future<void> _initCentralizedMesh() async {
    final devId = await _storage.getDeviceId();
    final storedMessages = await _storage.loadMessages();

    if (mounted) {
      setState(() {
        _myDeviceId = devId;
        _messages.clear();
        _messages.addAll(storedMessages.reversed);
      });
    }

    _eventSubscription = _bridge.eventStream.listen((event) {
      final String type = event['type'] ?? '';
      if (type == 'MESSAGE_RECEIVED') {
        final String rawPayload = event['payload'] ?? '';
        if (rawPayload.isNotEmpty) {
          try {
            final packet = MessagePacket.fromJson(rawPayload, myDeviceId: _myDeviceId);
            _meshManager.processIncomingPacket(
              packet,
              onNewMessage: (newPacket) {
                if (mounted) {
                  setState(() {
                    _messages.removeWhere((m) => m.id == newPacket.id);
                    _messages.insert(0, newPacket);
                  });
                }
                if (!newPacket.isSelf && newPacket.text.isNotEmpty) {
                  _sttTts.speak(
                    newPacket.text,
                    language: newPacket.language,
                  );
                }
              },
            );
          } catch (e) {
            print('MainNavigationScreen incoming packet error: $e');
          }
        }
      }
    });
  }

  Future<void> _loadSavedLanguage() async {
    final saved = await LocalStorageService().getPreferredLanguage();
    if (mounted && saved != _currentLanguage) {
      setState(() {
        _currentLanguage = saved;
      });
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic screen-adaptive colors matching active tab theme
    final Color navBgColor;
    final Color selectedColor;
    final Color unselectedColor;
    final Border borderTop;

    if (_currentIndex == 0) {
      // Tab 0: Emergency SOS (Vibrant Red Theme)
      navBgColor = Colors.red.shade600;
      selectedColor = Colors.white;
      unselectedColor = Colors.white.withOpacity(0.70);
      borderTop = Border(top: BorderSide(color: Colors.red.shade700, width: 1));
    } else if (_currentIndex == 2) {
      // Tab 2: Radar & Nearby (Dark Charcoal Theme)
      navBgColor = const Color(0xFF0A0A0A);
      selectedColor = Colors.greenAccent;
      unselectedColor = Colors.white60;
      borderTop = const Border(top: BorderSide(color: Colors.white12, width: 0.8));
    } else {
      // Tab 1 & 3: Home & Settings (Clean White Theme)
      navBgColor = Colors.white;
      selectedColor = Colors.blue.shade800;
      unselectedColor = Colors.grey.shade600;
      borderTop = Border(top: BorderSide(color: Colors.grey.shade200, width: 1));
    }

    return Scaffold(
      backgroundColor: navBgColor,
      extendBody: false, // Ensures screen content sits cleanly above the navigation bar
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const BouncingScrollPhysics(),
        children: [
          // Tab 0: Emergency SOS Screen
          EmergencyPanicScreen(selectedLanguage: _currentLanguage),

          // Tab 1: Home Page
          HomeScreen(
            selectedLanguage: _currentLanguage,
            messages: _messages,
            onMessageSent: (sentPacket) {
              if (mounted) {
                setState(() {
                  _messages.removeWhere((m) => m.id == sentPacket.id);
                  _messages.insert(0, sentPacket);
                });
              }
            },
            onMessageDeleted: (deletedId) {
              if (mounted) {
                setState(() {
                  _messages.removeWhere((m) => m.id == deletedId);
                });
              }
            },
            onAllMessagesCleared: () {
              if (mounted) {
                setState(() {
                  _messages.clear();
                });
              }
            },
          ),

          // Tab 2: Radar + Nearby Phones Screen
          RadarScreen(
            selectedLanguage: _currentLanguage,
            messages: _messages,
          ),

          // Tab 3: Settings Screen
          SettingsScreen(
            selectedLanguage: _currentLanguage,
            onLanguageChanged: (newLang) {
              setState(() {
                _currentLanguage = newLang;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: navBgColor,
          border: borderTop,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: [
            BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _currentIndex == 0
                      ? Colors.white.withOpacity(0.20)
                      : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sos_rounded,
                  color: _currentIndex == 0 ? Colors.white : Colors.red.shade700,
                ),
              ),
              label: 'Emergency SOS',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.radar_rounded),
              label: 'Radar & Nearby',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
