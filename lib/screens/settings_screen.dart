import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final StorageService _storage = StorageService();
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _storage.init();
    final settings = await _storage.getSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await _storage.updateSetting(key, value);
    setState(() {
      _settings[key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeNotifier = ref.read(themeModeProvider.notifier);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                size: 32,
                color: isDark ? Colors.white : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 12),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure app preferences and behavior',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                _buildSection(
                  'Appearance',
                  [
                    _buildSwitchTile(
                      'Dark Mode',
                      'Use dark theme for the app',
                      Icons.dark_mode_outlined,
                      _settings['dark_mode'] ?? true,
                      (value) {
                        _updateSetting('dark_mode', value);
                        themeNotifier.toggleTheme();
                      },
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'Behavior',
                  [
                    _buildSwitchTile(
                      'Auto Connect',
                      'Automatically connect to WiFi on startup',
                      Icons.wifi,
                      _settings['auto_connect'] ?? false,
                      (value) => _updateSetting('auto_connect', value),
                    ),
                    _buildSwitchTile(
                      'Minimize to Tray',
                      'Keep running in system tray when closed',
                      Icons.minimize,
                      _settings['minimize_to_tray'] ?? true,
                      (value) => _updateSetting('minimize_to_tray', value),
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'Network Endpoints',
                  [
                    _buildTextFieldTile(
                      'Campus Endpoint',
                      _settings['campus_endpoint'] ?? '',
                      Icons.business,
                      (value) => _updateSetting('campus_endpoint', value),
                      isDark,
                    ),
                    _buildTextFieldTile(
                      'Hostel Endpoint',
                      _settings['hostel_endpoint'] ?? '',
                      Icons.home,
                      (value) => _updateSetting('hostel_endpoint', value),
                      isDark,
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'Data',
                  [
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.errorRed,
                      ),
                      title: const Text('Clear Saved Credentials'),
                      subtitle: const Text('Remove stored username and password'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          await _storage.clearCredentials();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Credentials cleared'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                        ),
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                  isDark,
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'About',
                  [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('VitPlus'),
                      subtitle: Text('Version 2.0.0'),
                    ),
                  ],
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextFieldTile(
    String label,
    String value,
    IconData icon,
    Function(String) onChanged,
    bool isDark,
  ) {
    final controller = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
              ),
              onSubmitted: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
