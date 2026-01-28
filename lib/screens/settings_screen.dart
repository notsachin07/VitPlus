import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../providers/vtop_provider.dart';
import '../models/vtop_models.dart';
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

  // VTOP credentials controllers
  final _vtopUsernameController = TextEditingController();
  final _vtopPasswordController = TextEditingController();
  bool _obscureVtopPassword = true;
  bool _hasVtopCredentials = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVtopCredentials();
  }

  @override
  void dispose() {
    _vtopUsernameController.dispose();
    _vtopPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadVtopCredentials() async {
    await _storage.init();
    final creds = await _storage.getVtopCredentials();
    if (creds != null && creds['username'] != null) {
      setState(() {
        _vtopUsernameController.text = creds['username'] ?? '';
        _vtopPasswordController.text = creds['password'] ?? '';
        _hasVtopCredentials = creds['username']?.isNotEmpty ?? false;
      });
    }
  }

  Future<void> _saveVtopCredentials() async {
    await _storage.saveVtopCredentials(
      _vtopUsernameController.text,
      _vtopPasswordController.text,
    );
    setState(() {
      _hasVtopCredentials = _vtopUsernameController.text.isNotEmpty;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VTOP credentials saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // Re-initialize VTOP provider with new credentials
    ref.read(vtopProvider.notifier).loadCredentials();
  }

  Future<void> _clearVtopCredentials() async {
    await _storage.clearVtopCredentials();
    setState(() {
      _vtopUsernameController.clear();
      _vtopPasswordController.clear();
      _hasVtopCredentials = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VTOP credentials cleared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    ref.read(vtopProvider.notifier).logout();
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
                _buildVtopSection(isDark),
                const SizedBox(height: 16),
                _buildSection(
                  'About',
                  [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('VitPlus'),
                      subtitle: Text('Version 2.2.0'),
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

  Widget _buildVtopSection(bool isDark) {
    final vtopState = ref.watch(vtopProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'VTOP Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const Spacer(),
                if (vtopState.isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppTheme.successGreen),
                        SizedBox(width: 4),
                        Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_hasVtopCredentials)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info, size: 14, color: AppTheme.warningOrange),
                        SizedBox(width: 4),
                        Text(
                          'Saved',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Username field
            TextField(
              controller: _vtopUsernameController,
              decoration: InputDecoration(
                labelText: 'VTOP Username',
                hintText: 'e.g., 21BCE1234',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // Password field
            TextField(
              controller: _vtopPasswordController,
              obscureText: _obscureVtopPassword,
              decoration: InputDecoration(
                labelText: 'VTOP Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureVtopPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureVtopPassword = !_obscureVtopPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // Semester selector
            _buildSemesterSelector(isDark, vtopState),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveVtopCredentials,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_hasVtopCredentials)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: vtopState.isLoading
                          ? null
                          : () async {
                              await ref.read(vtopProvider.notifier).login();
                            },
                      icon: vtopState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.login, size: 18),
                      label: Text(vtopState.isLoading ? 'Connecting...' : 'Connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_hasVtopCredentials) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _clearVtopCredentials,
                    icon: const Icon(Icons.delete_outline),
                    color: AppTheme.errorRed,
                    tooltip: 'Clear VTOP credentials',
                  ),
                ],
              ],
            ),
            if (vtopState.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vtopState.error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Your VTOP credentials are stored locally and used to fetch your timetable, attendance, marks, and exam schedule.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSemesterSelector(bool isDark, VtopState vtopState) {
    final semesters = vtopState.semesters;
    final selectedSemester = vtopState.selectedSemester;

    if (semesters.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Connect to VTOP to load semesters',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<Semester>(
      value: selectedSemester,
      decoration: InputDecoration(
        labelText: 'Select Semester',
        prefixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        isDense: true,
      ),
      items: semesters.map((semester) {
        return DropdownMenuItem<Semester>(
          value: semester,
          child: Text(
            semester.name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (semester) {
        if (semester != null) {
          ref.read(vtopProvider.notifier).selectSemester(semester);
        }
      },
    );
  }
}
