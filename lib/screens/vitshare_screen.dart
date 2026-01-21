import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/vitshare_service.dart';
import '../services/wifi_service.dart';
import '../theme/app_theme.dart';

final vitShareProvider = StateNotifierProvider<VitShareNotifier, VitShareState>((ref) {
  return VitShareNotifier();
});

class VitShareState {
  final bool isRunning;
  final String? serverUrl;
  final String password;
  final List<String> sharedPaths;

  VitShareState({
    this.isRunning = false,
    this.serverUrl,
    this.password = '',
    this.sharedPaths = const [],
  });

  VitShareState copyWith({
    bool? isRunning,
    String? serverUrl,
    String? password,
    List<String>? sharedPaths,
  }) {
    return VitShareState(
      isRunning: isRunning ?? this.isRunning,
      serverUrl: serverUrl ?? this.serverUrl,
      password: password ?? this.password,
      sharedPaths: sharedPaths ?? this.sharedPaths,
    );
  }
}

class VitShareNotifier extends StateNotifier<VitShareState> {
  VitShareNotifier() : super(VitShareState());

  final VitShareService _service = VitShareService();

  Future<void> addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();

      for (final path in paths) {
        _service.addPath(path);
      }

      state = state.copyWith(sharedPaths: List.from(_service.sharedPaths));
    }
  }

  Future<void> addFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      _service.addPath(result);
      state = state.copyWith(sharedPaths: List.from(_service.sharedPaths));
    }
  }

  void removePath(String path) {
    _service.removePath(path);
    state = state.copyWith(sharedPaths: List.from(_service.sharedPaths));
  }

  Future<void> startServer() async {
    final ip = await _service.getLocalIP();
    final success = await _service.start();

    if (success) {
      state = state.copyWith(
        isRunning: true,
        serverUrl: 'http://$ip:${_service.port}',
        password: _service.password,
      );
    }
  }

  Future<void> stopServer() async {
    await _service.stop();
    state = state.copyWith(
      isRunning: false,
      serverUrl: null,
    );
  }
}

class VitShareScreen extends ConsumerWidget {
  const VitShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shareState = ref.watch(vitShareProvider);
    final notifier = ref.read(vitShareProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_shared,
                size: 32,
                color: isDark ? Colors.white : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 12),
              Text(
                'VitShare',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shareState.isRunning 
                    ? AppTheme.successGreen.withOpacity(0.2)
                    : (isDark ? AppTheme.darkCard : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: shareState.isRunning 
                      ? AppTheme.successGreen 
                      : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shareState.isRunning 
                          ? AppTheme.successGreen 
                          : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      shareState.isRunning ? 'Server Running' : 'Server Stopped',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: shareState.isRunning 
                          ? AppTheme.successGreen 
                          : (isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share files with devices on the same WiFi network',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          if (shareState.isRunning) ...[
            _buildServerInfo(context, shareState, isDark),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Shared Items',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: notifier.addFiles,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Files'),
                              ),
                              TextButton.icon(
                                onPressed: notifier.addFolder,
                                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                                label: const Text('Add Folder'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: shareState.sharedPaths.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.folder_open,
                                          size: 64,
                                          color: isDark ? Colors.white24 : Colors.black12,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No files or folders shared yet',
                                          style: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add files or folders to start sharing',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white24 : Colors.black26,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: shareState.sharedPaths.length,
                                    itemBuilder: (context, index) {
                                      final path = shareState.sharedPaths[index];
                                      final isDir = FileSystemEntity.typeSync(path) == 
                                          FileSystemEntityType.directory;

                                      return ListTile(
                                        leading: Icon(
                                          isDir ? Icons.folder : Icons.insert_drive_file,
                                          color: isDir 
                                            ? AppTheme.accentGold 
                                            : AppTheme.primaryBlue,
                                        ),
                                        title: Text(
                                          path.split(Platform.pathSeparator).last,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          path,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: () => notifier.removePath(path),
                                          tooltip: 'Remove',
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: shareState.isRunning ? null : notifier.startServer,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Sharing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: shareState.isRunning ? notifier.stopServer : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Sharing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerInfo(BuildContext context, VitShareState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📡 Share these details with your friends:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoBox(
                  'URL',
                  state.serverUrl ?? '',
                  Icons.link,
                  context,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoBox(
                  'Password',
                  state.password,
                  Icons.lock_outline,
                  context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ Both devices must be on the same WiFi network',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, IconData icon, BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copied to clipboard'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy, size: 16),
          ],
        ),
      ),
    );
  }
}
