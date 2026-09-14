import 'package:flutter/material.dart';
import '../screens/emergency_panic_screen.dart';
import '../screens/home_screen.dart';
import '../screens/radar_screen.dart';
import '../screens/voice_assistant_settings_screen.dart';

class AppDrawer extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.currentRoute,
  });

  static final Map<String, String> languages = {
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
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Colors.red.shade900,
              ),
              accountName: const Text(
                'JeevaLink P2P Mesh',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: const Text('Offline Emergency Relay'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.wifi_tethering, color: Colors.red, size: 36),
              ),
            ),

            // Navigation Items
            ListTile(
              leading: const Icon(Icons.forum, color: Colors.blue),
              title: const Text('Push-to-Talk Dashboard'),
              selected: currentRoute == 'home',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != 'home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.radar, color: Colors.green),
              title: const Text('Nearby Users Radar'),
              selected: currentRoute == 'radar',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != 'radar') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RadarScreen(selectedLanguage: selectedLanguage),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text('Emergency Panic SOS'),
              selected: currentRoute == 'panic',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != 'panic') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmergencyPanicScreen(selectedLanguage: selectedLanguage),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: Colors.orange),
              title: const Text('Voice Assistant Settings'),
              selected: currentRoute == 'voice_settings',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != 'voice_settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VoiceAssistantSettingsScreen(selectedLanguage: selectedLanguage),
                    ),
                  );
                }
              },
            ),

            const Divider(),

            // Language Selection Dropdown Section in Sidebar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT LANGUAGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      fillColor: Colors.grey.shade50,
                      filled: true,
                    ),
                    items: languages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        onLanguageChanged(val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
