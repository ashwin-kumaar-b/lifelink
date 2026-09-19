import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/model_downloader_service.dart';
import '../services/native_bridge.dart';
import '../services/stt_tts_service.dart';

class SettingsScreen extends StatefulWidget {
  final String selectedLanguage;
  final Function(String)? onLanguageChanged;

  const SettingsScreen({
    super.key,
    this.selectedLanguage = 'en',
    this.onLanguageChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalStorageService _storage = LocalStorageService();

  late String _currentLanguage;
  String _currentUsername = 'User';
  String _myDeviceId = 'NODE-UNKNOWN';
  int _currentTtl = 3;
  int _storedMessageCount = 0;
  bool _isPruning = false;

  final Map<String, String> _languages = {
    'en': 'English',
    'te': 'తెలుగు (Telugu)',
    'ta': 'தமிழ் (Tamil)',
    'hi': 'हिन्दी (Hindi)',
  };

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.selectedLanguage;
    _loadUserDataAndStats();
  }

  Future<void> _loadUserDataAndStats() async {
    final devId = await _storage.getDeviceId();
    final username = await _storage.getUsername();
    final prefLang = await _storage.getPreferredLanguage();
    final prefTtl = await _storage.getPreferredTtl();
    final messages = await _storage.loadMessages();

    if (mounted) {
      setState(() {
        _myDeviceId = devId;
        _currentUsername = username;
        _currentLanguage = prefLang;
        _currentTtl = prefTtl;
        _storedMessageCount = messages.length;
      });
    }
  }

  void _showEditNameSheet() {
    final controller = TextEditingController(text: _currentUsername);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Display Name',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'This name is attached to your outgoing emergency & text broadcasts.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Username / Display Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      await _storage.saveUsername(newName);
                      if (mounted) {
                        setState(() {
                          _currentUsername = newName;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Display name updated to "$newName"')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Choose your language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              ..._languages.entries.map((entry) {
                final isSelected = entry.key == _currentLanguage;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  selected: isSelected,
                  selectedTileColor: Colors.green.shade50,
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? Colors.green : Colors.grey.shade200,
                    child: Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.green.shade900 : Colors.black87,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (entry.key == _currentLanguage) return;

                    await Future.delayed(const Duration(milliseconds: 250));

                    final downloader = ModelDownloaderService();
                    final bool isDownloaded = await downloader.isModelDownloaded(entry.key);

                    if (entry.key == 'en' || isDownloaded) {
                      _switchLanguageWithLoading(entry.key, entry.value);
                    } else {
                      _downloadLanguageFromSettings(entry.key);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchLanguageWithLoading(String langKey, String langName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            child: Row(
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.green,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activating $langName...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Loading speech model into RAM...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Frame delay to allow Flutter to paint the dialog before native C++ model loading
    await Future.delayed(const Duration(milliseconds: 50));

    final bool success = await SttTtsService().loadModelForLanguage(langKey);
    await _storage.savePreferredLanguage(langKey);

    if (mounted) {
      setState(() {
        _currentLanguage = langKey;
      });
      widget.onLanguageChanged?.call(langKey);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Activated $langName Speech Engine!'
                : 'Failed to initialize $langName. Defaulted to English.',
          ),
          backgroundColor: success ? Colors.green.shade800 : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _downloadLanguageFromSettings(String lang) async {
    final downloader = ModelDownloaderService();
    final langName = _languages[lang] ?? lang.toUpperCase();
    double progress = 0.0;
    String statusText = 'Starting download...';
    bool isDownloading = true;
    bool isActivating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (downloadCtx) {
        return StatefulBuilder(
          builder: (context, setProgressState) {
            if (isDownloading && progress == 0.0 && !isActivating) {
              downloader.downloadLanguageModel(
                lang,
                onProgress: (rx, total, pct) {
                  if (downloadCtx.mounted) {
                    setProgressState(() {
                      progress = pct;
                      final rxMb = (rx / (1024 * 1024)).toStringAsFixed(1);
                      final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
                      statusText = 'Downloading $langName: $rxMb MB / $totalMb MB (${(pct * 100).toStringAsFixed(0)}%)';
                    });
                  }
                },
              ).then((success) async {
                isDownloading = false;
                if (success) {
                  if (downloadCtx.mounted) {
                    setProgressState(() {
                      isActivating = true;
                      statusText = 'Activating $langName Speech Engine...';
                    });
                  }
                  await Future.delayed(const Duration(milliseconds: 50));
                  await SttTtsService().loadModelForLanguage(lang);
                  await _storage.savePreferredLanguage(lang);

                  if (mounted) {
                    setState(() {
                      _currentLanguage = lang;
                    });
                    widget.onLanguageChanged?.call(lang);
                    if (downloadCtx.mounted) Navigator.pop(downloadCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloaded & activated $langName Speech Engine!'),
                        backgroundColor: Colors.green.shade800,
                      ),
                    );
                  }
                } else {
                  if (downloadCtx.mounted) {
                    setProgressState(() {
                      statusText = 'Download failed. Check connection or retry.';
                    });
                  }
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    isActivating ? Icons.memory : Icons.cloud_download,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isActivating ? 'Activating $langName Engine' : 'Downloading $langName Model',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: isActivating ? null : (progress > 0 ? progress : null),
                    backgroundColor: Colors.grey.shade800,
                    color: Colors.greenAccent,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                if (!isActivating)
                  TextButton(
                    onPressed: () {
                      if (downloadCtx.mounted) Navigator.pop(downloadCtx);
                    },
                    child: const Text('CANCEL', style: TextStyle(color: Colors.orangeAccent)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTtlConfigSheet() {
    int tempTtl = _currentTtl;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Multi-Hop Relay TTL',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$tempTtl HOPS',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Adjust max propagation hops across intermediate phones in the off-grid mesh.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Slider(
                  value: tempTtl.toDouble(),
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  activeColor: Colors.amber.shade700,
                  inactiveColor: Colors.amber.shade100,
                  label: '$tempTtl hops',
                  onChanged: (val) {
                    setSheetState(() {
                      tempTtl = val.toInt();
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _currentTtl = tempTtl;
                      });
                      _storage.savePreferredTtl(tempTtl);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Multi-Hop TTL updated to $tempTtl hops.')),
                      );
                    },
                    child: const Text('Save TTL Setting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransportsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Off-Grid Transports & Protocols',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.wifi_tethering, color: Colors.blue),
                ),
                title: const Text('Wi-Fi Direct P2P Sockets', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const String.fromEnvironment('SUB', defaultValue: 'Multicast Lock Active (Port 8888)') != ''
                    ? const Text('Multicast Lock Active (Port 8888)')
                    : const Text('Multicast Lock Active (Port 8888)'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.bluetooth, color: Colors.purple),
                ),
                title: const Text('Bluetooth RFCOMM Fallback', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Insecure RFCOMM Sockets Active'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _manualPruneStorage() async {
    setState(() {
      _isPruning = true;
    });

    final countBefore = _storedMessageCount;
    await _storage.loadMessages();
    final freshMessages = await _storage.loadMessages();

    if (mounted) {
      setState(() {
        _storedMessageCount = freshMessages.length;
        _isPruning = false;
      });
      final pruned = countBefore - _storedMessageCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pruned > 0
                ? 'Pruned $pruned messages older than 24 hours.'
                : 'Storage clean. All messages under 24h old.',
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Top Main Title
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Profile Header Section (Username & Node ID)
            InkWell(
              onTap: _showEditNameSheet,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUsername,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_myDeviceId • P2P Mesh Member',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Settings List Tiles with Vibrant Squircle Icon Badges
            _buildSettingsItem(
              icon: Icons.person_outline_rounded,
              iconBgColor: Colors.blue.shade500,
              title: 'Account Profile',
              subtitle: _currentUsername,
              onTap: _showEditNameSheet,
            ),
            _buildDivider(),

            _buildSettingsItem(
              icon: Icons.translate_rounded,
              iconBgColor: Colors.green.shade500,
              title: 'Choose your language',
              subtitle: _languages[_currentLanguage] ?? 'English',
              onTap: _showLanguagePickerSheet,
            ),
            _buildDivider(),

            _buildSettingsItem(
              icon: Icons.alt_route_rounded,
              iconBgColor: Colors.amber.shade700,
              title: 'Multi-Hop Relay TTL',
              subtitle: '$_currentTtl Hops (Max propagation)',
              onTap: _showTtlConfigSheet,
            ),
            _buildDivider(),

            _buildSettingsItem(
              icon: Icons.cleaning_services_rounded,
              iconBgColor: Colors.purple.shade500,
              title: 'Storage & Privacy (24h Auto-Prune)',
              subtitle: '$_storedMessageCount messages stored',
              isLoading: _isPruning,
              onTap: _manualPruneStorage,
            ),
            _buildDivider(),

            _buildSettingsItem(
              icon: Icons.wifi_tethering_rounded,
              iconBgColor: Colors.teal.shade500,
              title: 'Off-Grid Transports',
              subtitle: 'Wi-Fi Direct TCP (8888) & Bluetooth RFCOMM',
              onTap: _showTransportsSheet,
            ),
            _buildDivider(),

            _buildSettingsItem(
              icon: Icons.battery_saver_rounded,
              iconBgColor: Colors.indigo.shade500,
              title: 'Background Mesh Execution',
              subtitle: 'Screen-Off Listening Active • Request Battery Saver Exemption',
              onTap: () async {
                final bridge = NativeBridge();
                await bridge.startBackgroundService();
                await bridge.requestBatteryOptimizationExemption();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚡ JeevaLink Foreground Service & Battery Exemption active.'),
                      backgroundColor: Colors.indigo,
                    ),
                  );
                }
              },
            ),
            _buildDivider(),

            const SizedBox(height: 32),

            // Centered App Version Footer
            Center(
              child: Column(
                children: [
                  Text(
                    'App Version 2.0-demo RELEASE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'JL2DEMO:: Version Lock Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            // Vibrant Squircle Icon Container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 58.0),
      child: Divider(
        height: 1,
        thickness: 0.8,
        color: Colors.grey.shade200,
      ),
    );
  }
}
