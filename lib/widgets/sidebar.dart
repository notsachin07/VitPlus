import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isCheckingUpdate = false;

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    
    try {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate();
      
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      
      if (updateInfo.isUpdateAvailable) {
        _showUpdateDialog(updateInfo);
      } else {
        _showUpToDateDialog(updateInfo);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showUpToDateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
            SizedBox(width: 10),
            Text('Up to Date'),
          ],
        ),
        content: Text(
          'You are running the latest version (v${info.currentVersion}).',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (context) => _UpdateDialog(updateInfo: info),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed, size: 28),
            SizedBox(width: 10),
            Text('Update Check Failed'),
          ],
        ),
        content: const Text(
          'Could not check for updates. Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://github.com/notsachin07/VitPlus/releases/latest');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: const Text('Open GitHub'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 220,
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, Color(0xFF00A8FF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.wifi,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'VitPlus',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _NavItem(
            icon: Icons.wifi,
            label: 'WiFi Connect',
            isSelected: widget.selectedIndex == 0,
            onTap: () => widget.onItemSelected(0),
          ),
          _NavItem(
            icon: Icons.folder_shared,
            label: 'VitShare',
            isSelected: widget.selectedIndex == 1,
            onTap: () => widget.onItemSelected(1),
          ),
          _NavItem(
            icon: Icons.settings,
            label: 'Settings',
            isSelected: widget.selectedIndex == 2,
            onTap: () => widget.onItemSelected(2),
          ),
          const Spacer(),
          // Check for Update button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isCheckingUpdate ? null : _checkForUpdate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _isCheckingUpdate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryBlue,
                              ),
                            )
                          : Icon(
                              Icons.system_update,
                              size: 20,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                      const SizedBox(width: 12),
                      Text(
                        _isCheckingUpdate ? 'Checking...' : 'Check for Update',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                  ? AppTheme.darkCard 
                  : AppTheme.lightBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppTheme.accentGold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse('https://github.com/notsachin07/VitPlus');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          'Star my repo on GitHub',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryBlue.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateDialog({required this.updateInfo});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0;

  Future<void> _startUpdate() async {
    if (widget.updateInfo.downloadUrl == null) {
      // No direct download available, open GitHub releases page
      final uri = Uri.parse('https://github.com/notsachin07/VitPlus/releases/latest');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final updateService = UpdateService();
      await updateService.downloadAndApplyUpdate(
        widget.updateInfo.downloadUrl!,
        (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
        installerUrl: widget.updateInfo.installerUrl,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update, color: AppTheme.primaryBlue, size: 28),
          SizedBox(width: 10),
          Text('Update Available'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current version: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'v${widget.updateInfo.currentVersion}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'New version: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'v${widget.updateInfo.latestVersion}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Release Notes:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Markdown(
                data: widget.updateInfo.releaseNotes.isEmpty
                    ? 'No release notes available.'
                    : widget.updateInfo.releaseNotes,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  h2: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  listBullet: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.grey[300],
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(_downloadProgress * 100).toInt()}%'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Downloading update...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: _isDownloading ? null : _startUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: Text(_isDownloading ? 'Updating...' : 'Update Now'),
        ),
      ],
    );
  }
}
