import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/native_bridge.dart';

class PeerStore extends ChangeNotifier {
  static final PeerStore _instance = PeerStore._internal();
  factory PeerStore() => _instance;
  PeerStore._internal() {
    _init();
  }

  final NativeBridge _bridge = NativeBridge();
  StreamSubscription? _eventSubscription;

  String _p2pStatus = 'DISCONNECTED';
  String _connectedPeerName = '';
  String _groupOwnerIp = '';
  bool _isGroupOwner = false;
  List<Map<String, dynamic>> _discoveredPeers = [];

  String get p2pStatus => _p2pStatus;
  String get connectedPeerName => _connectedPeerName;
  String get groupOwnerIp => _groupOwnerIp;
  bool get isGroupOwner => _isGroupOwner;
  List<Map<String, dynamic>> get discoveredPeers => List.unmodifiable(_discoveredPeers);

  void _init() {
    _eventSubscription = _bridge.eventStream.listen(_handleNativeEvent);
  }

  void _handleNativeEvent(Map<dynamic, dynamic> event) {
    final String type = event['type'] ?? '';
    switch (type) {
      case 'PEERS_DISCOVERED':
        final rawPeers = event['peers'] as List<dynamic>? ?? [];
        _discoveredPeers = rawPeers.map((p) => Map<String, dynamic>.from(p as Map)).toList();
        notifyListeners();
        break;

      case 'STATUS_CHANGED':
        _p2pStatus = event['status'] ?? 'DISCONNECTED';
        if (event['peerName'] != null) {
          _connectedPeerName = event['peerName'];
        }
        notifyListeners();
        break;

      case 'CONNECTION_INFO':
        _isGroupOwner = event['isGroupOwner'] == true;
        _groupOwnerIp = event['groupOwnerIp'] ?? '';
        notifyListeners();
        break;
    }
  }

  Future<bool> discoverPeers() async {
    return await _bridge.discoverPeers();
  }

  Future<bool> connectPeer(String deviceAddress) async {
    return await _bridge.connectPeer(deviceAddress);
  }

  Future<bool> disconnectPeer() async {
    return await _bridge.disconnectPeer();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
