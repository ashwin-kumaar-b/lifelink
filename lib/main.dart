import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/stt_tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SttTtsService().initialize();
  runApp(const JeevaLinkApp());
}

class JeevaLinkApp extends StatelessWidget {
  const JeevaLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JeevaLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const PermissionWrapper(),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper>
    with WidgetsBindingObserver {
  bool _isGranted = false;
  String _statusText = 'Checking permissions...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    // 1. Check existing statuses first
    final locStatus = await Permission.location.status;
    final micStatus = await Permission.microphone.status;

    if (locStatus.isGranted && micStatus.isGranted) {
      if (mounted) {
        setState(() {
          _isGranted = true;
        });
      }
      return;
    }

    // 2. Request core permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.microphone,
      Permission.notification,
      Permission.nearbyWifiDevices,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    final bool locationOk =
        statuses[Permission.location]?.isGranted ?? locStatus.isGranted;
    final bool micOk =
        statuses[Permission.microphone]?.isGranted ?? micStatus.isGranted;

    final bool essentialOk = locationOk && micOk;

    if (mounted) {
      setState(() {
        _isGranted = essentialOk;
        if (!essentialOk) {
          _statusText =
              'Location & Microphone permissions are required for JeevaLink voice assistant and offline emergency operation.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGranted) {
      return const HomeScreen();
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Permissions Needed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _requestPermissions,
                child: const Text('Grant Permissions'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isGranted = true; // Bypass for testing/demo if needed
                  });
                },
                child: const Text('Continue Anyway'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
