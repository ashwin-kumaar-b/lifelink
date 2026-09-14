import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/stt_tts_service.dart';
import '../services/voice_assistant_service.dart';

class VoiceAssistantSettingsScreen extends StatefulWidget {
  final String selectedLanguage;

  const VoiceAssistantSettingsScreen({
    super.key,
    this.selectedLanguage = 'en',
  });

  @override
  State<VoiceAssistantSettingsScreen> createState() =>
      _VoiceAssistantSettingsScreenState();
}

class _VoiceAssistantSettingsScreenState
    extends State<VoiceAssistantSettingsScreen> {
  final VoiceAssistantService _assistantService = VoiceAssistantService();
  final SttTtsService _sttTts = SttTtsService();

  PermissionStatus _micPermission = PermissionStatus.denied;
  PermissionStatus _notificationPermission = PermissionStatus.denied;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    await _assistantService.checkPermissionsStatus();
    if (mounted) {
      setState(() {
        _micPermission = mic;
        _notificationPermission = notif;
        _overlayGranted = _assistantService.isOverlayGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHotwordOn = _assistantService.isHotwordEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voice Assistance Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade900, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Jeeva Hands-Free Voice Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trigger emergency recording by voice, power button, or home gesture.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: "Hey Jeeva" Hotword Activation
            _buildSectionTitle('1. VOICE WAKE-WORD ("HEY JEEVA")'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: Colors.red.shade700,
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic_outlined,
                            color: Colors.red.shade800),
                      ),
                      title: const Text(
                        'Enable "Hey Jeeva" Wake Word',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: const Text(
                        'Listen in background for "Hey Jeeva" to automatically open and record.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: isHotwordOn,
                      onChanged: (val) async {
                        await _assistantService.setHotwordEnabled(val);
                        setState(() {});
                        if (val && _assistantService.audioFeedback) {
                          _sttTts.speak('Hey Jeeva voice assistant enabled');
                        }
                      },
                    ),
                    if (isHotwordOn) ...[
                      const Divider(),
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Listening active: Say "Hey Jeeva" anytime to trigger recording.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Option 2 & 3: Power Button & Circle-Search Home Bar Gesture
            _buildSectionTitle(
                '2 & 3. POWER BUTTON & CIRCLE-SEARCH HOME BAR SHORTCUTS'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.power_settings_new,
                              color: Colors.blue.shade800),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Digital Assistant Shortcut Integration',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Long-press Power Button or Home Pill (Circle Search gesture) to record.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Quick Setup Instructions:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 6),
                          Text('1. Tap "Set Jeeva as Default Assistant" below.',
                              style: TextStyle(fontSize: 12)),
                          Text(
                              '2. Select "JeevaLink" under Default Digital Assistant app.',
                              style: TextStyle(fontSize: 12)),
                          Text(
                              '3. Now long-pressing Power Button or Home Bar automatically opens & records!',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await _assistantService.openAssistantSettings();
                        },
                        icon: const Icon(Icons.settings_applications),
                        label: const Text(
                          'Set Jeeva as Default Assistant',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Option 4: Home Screen Emergency SOS Widget
            _buildSectionTitle('4. HOME SCREEN EMERGENCY SOS WIDGET'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.widgets,
                              color: Colors.red.shade800),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instant Home Screen SOS Button Widget',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              Text(
                                'Record & transmit emergency signal in background without opening full app.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'How to Add Widget to your Home Screen:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 6),
                          Text('1. Go to your Phone Home Screen and press & hold on an empty space.',
                              style: TextStyle(fontSize: 12)),
                          Text('2. Tap "Widgets" and search for "JeevaLink".',
                              style: TextStyle(fontSize: 12)),
                          Text('3. Drag "Jeeva Emergency SOS Widget" onto your Home Screen.',
                              style: TextStyle(fontSize: 12)),
                          Text('4. Tap the widget anytime to instantly record voice & broadcast P2P SOS signal in the background!',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Assistant Behaviors
            _buildSectionTitle('ASSISTANT LAUNCH BEHAVIOR'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: Colors.red.shade700,
                    secondary: const Icon(Icons.fiber_manual_record,
                        color: Colors.red),
                    title: const Text('Auto-Start Recording on Launch'),
                    subtitle: const Text(
                        'Immediately start mic recording when opened via shortcut'),
                    value: _assistantService.autoStartRecording,
                    onChanged: (val) async {
                      await _assistantService.setAutoStartRecording(val);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeColor: Colors.red.shade700,
                    secondary: const Icon(Icons.volume_up, color: Colors.amber),
                    title: const Text('Voice Feedback & Audio Chime'),
                    subtitle: const Text(
                        'Speak "Listening..." when voice assistant triggers'),
                    value: _assistantService.audioFeedback,
                    onChanged: (val) async {
                      await _assistantService.setAudioFeedback(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Permission Dashboard
            _buildSectionTitle('REQUIRED PERMISSIONS DASHBOARD'),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildPermissionTile(
                      icon: Icons.mic,
                      title: 'Microphone Permission',
                      subtitle: 'Required to record voice and listen for wake word',
                      isGranted: _micPermission.isGranted,
                      onTap: () async {
                        await _assistantService.requestMicPermission();
                        _checkAllPermissions();
                      },
                    ),
                    const Divider(),
                    _buildPermissionTile(
                      icon: Icons.notifications,
                      title: 'Notification Permission',
                      subtitle: 'Required for background wake-word service',
                      isGranted: _notificationPermission.isGranted,
                      onTap: () async {
                        await _assistantService.requestNotificationPermission();
                        _checkAllPermissions();
                      },
                    ),
                    const Divider(),
                    _buildPermissionTile(
                      icon: Icons.layers,
                      title: 'Display Over Other Apps (Overlay)',
                      subtitle:
                          'Required to open app automatically over lock screen or other apps',
                      isGranted: _overlayGranted,
                      onTap: () async {
                        await _assistantService.openOverlaySettings();
                        _checkAllPermissions();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor:
            isGranted ? Colors.green.shade50 : Colors.orange.shade50,
        child: Icon(
          icon,
          color: isGranted ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isGranted ? Colors.green.shade100 : Colors.red.shade700,
          foregroundColor:
              isGranted ? Colors.green.shade900 : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: onTap,
        child: Text(
          isGranted ? 'Granted ✓' : 'Grant Now',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
