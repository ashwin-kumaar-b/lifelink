import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/main_navigation_screen.dart';
import 'services/local_storage_service.dart';
import 'services/native_bridge.dart';
import 'services/stt_tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedLang = await LocalStorageService().getPreferredLanguage();
  await SttTtsService().initialize(language: savedLang);
  runApp(JeevaLinkApp(initialLanguage: savedLang));
}

class JeevaLinkApp extends StatelessWidget {
  final String initialLanguage;

  const JeevaLinkApp({
    super.key,
    this.initialLanguage = 'en',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JeevaLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: PermissionWrapper(initialLanguage: initialLanguage),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  final String initialLanguage;

  const PermissionWrapper({
    super.key,
    this.initialLanguage = 'en',
  });

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _isGranted = false;
  String _statusText = 'Checking permissions...';
  final NativeBridge _bridge = NativeBridge();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.microphone,
      Permission.notification,
      Permission.nearbyWifiDevices,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool allOk = true;
    statuses.forEach((permission, status) {
      if (status.isDenied || status.isPermanentlyDenied) {
        allOk = false;
      }
    });

    if (allOk) {
      await _bridge.startBackgroundService();
      await _bridge.requestBatteryOptimizationExemption();
    }

    setState(() {
      _isGranted = allOk;
      if (!allOk) {
        _statusText =
            'Wi-Fi Direct, Bluetooth, Location, Microphone & Notification permissions are required for JeevaLink offline operation.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGranted) {
      return MainNavigationScreen(selectedLanguage: widget.initialLanguage);
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
