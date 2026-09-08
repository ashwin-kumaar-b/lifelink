import 'dart:async';
import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import 'emergency_panic_screen.dart';
import 'message_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final NativeBridge _bridge = NativeBridge();
  StreamSubscription? _eventSubscription;

  String _connectionStatus = 'INITIALIZING';
  bool _isGroupOwner = false;
  String _groupOwnerIp = '';
  List<Map<String, String>> _discoveredPeers = [];

  String _selectedLanguage = 'en';

  final Map<String, String> _languages = {
    'en': 'English',
    'hi': 'Hindi (हिंदी)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'bn': 'Bengali (বাংলা)',
    'mr': 'Marathi (मराठी)',
    'gu': 'Gujarati (ગુજરાતી)',
    'or': 'Odia (ଓଡ଼ିଆ)',
  };

  @override
  void initState() {
    super.initState();
    _listenToEvents();
    _bridge.discoverPeers();
  }

  void _listenToEvents() {
    _eventSubscription = _bridge.eventStream.listen((event) {
      final String type = event['type'] ?? '';
      switch (type) {
        case 'STATUS_CHANGED':
          setState(() {
            _connectionStatus = event['status'] ?? 'DISCONNECTED';
          });
          break;
        case 'CONNECTION_INFO':
          setState(() {
            _isGroupOwner = event['isGroupOwner'] ?? false;
            _groupOwnerIp = event['groupOwnerIp'] ?? '';
          });
          break;
        case 'PEERS_DISCOVERED':
          final rawPeers = event['peers'] as List<dynamic>?;
          if (rawPeers != null) {
            setState(() {
              _discoveredPeers = rawPeers
                  .map((p) => Map<String, String>.from(p as Map))
                  .toList();
            });
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Color _getStatusColor() {
    if (_connectionStatus.contains('CONNECTED') ||
        _connectionStatus.contains('ENABLED')) {
      return Colors.green;
    }
    if (_connectionStatus.contains('CONNECTING') ||
        _connectionStatus.contains('DISCOVERING')) {
      return Colors.orange;
    }
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JeevaLink — Offline P2P'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.warning_amber, color: Colors.red),
            tooltip: 'Panic Button',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmergencyPanicScreen(
                    selectedLanguage: _selectedLanguage,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Connection Status Indicator Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: _getStatusColor().withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _getStatusColor().withOpacity(0.2),
                      child: Icon(
                        _connectionStatus.contains('CONNECTED')
                            ? Icons.wifi_tethering
                            : Icons.radar,
                        color: _getStatusColor(),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connection Status',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _connectionStatus.replaceAll('_', ' '),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    if (_isGroupOwner) ...[
                      const SizedBox(height: 6),
                      Chip(
                        label: Text('Group Owner (${_groupOwnerIp.isEmpty ? "192.168.49.1" : _groupOwnerIp})'),
                        backgroundColor: Colors.green.shade100,
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        _bridge.discoverPeers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scanning for nearby mesh phones...')),
                        );
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Scan for Nearby Phones'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Language Selector Section
            const Text(
              'Select Preferred Language',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Used for offline Speech-to-Text & Text-to-Speech playback',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _languages.entries.map((entry) {
                final isSelected = _selectedLanguage == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  selectedColor: Colors.red.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.red.shade900 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedLanguage = entry.key;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // 3. Navigation Buttons
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MessageScreen(
                      selectedLanguage: _selectedLanguage,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.message),
              label: const Text('Open Push-to-Talk Messaging'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyPanicScreen(
                      selectedLanguage: _selectedLanguage,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.warning, color: Colors.white),
              label: const Text('EMERGENCY PANIC BROADCAST'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            // Discovered Peers List
            if (_discoveredPeers.isNotEmpty) ...[
              const Text(
                'Discovered Mesh Nodes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ..._discoveredPeers.map(
                (peer) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(peer['deviceName'] ?? 'Unknown Device'),
                    subtitle: Text(peer['deviceAddress'] ?? ''),
                    trailing: const Chip(
                      label: Text('Auto-Mesh Node', style: TextStyle(fontSize: 10)),
                      backgroundColor: Colors.lightGreenAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
