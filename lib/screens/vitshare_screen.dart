import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/vitshare_service.dart';
import '../theme/app_theme.dart';

final vitShareProvider = StateNotifierProvider<VitShareNotifier, VitShareState>((ref) {
  return VitShareNotifier();
});

class VitShareState {
  final bool isRunning;
  final String? serverUrl;
  final String password;
  final List<String> sharedPaths;
  final Map<String, ActiveDownload> activeDownloads;

  VitShareState({
    this.isRunning = false,
    this.serverUrl,
    this.password = '',
    this.sharedPaths = const [],
    this.activeDownloads = const {},
  });

  VitShareState copyWith({
    bool? isRunning,
    String? serverUrl,
    String? password,
    List<String>? sharedPaths,
    Map<String, ActiveDownload>? activeDownloads,
  }) {
    return VitShareState(
      isRunning: isRunning ?? this.isRunning,
      serverUrl: serverUrl ?? this.serverUrl,
      password: password ?? this.password,
      sharedPaths: sharedPaths ?? this.sharedPaths,
      activeDownloads: activeDownloads ?? this.activeDownloads,
    );
  }
}

class VitShareNotifier extends StateNotifier<VitShareState> {
  VitShareNotifier() : super(VitShareState());

  final VitShareService _service = VitShareService();
  StreamSubscription? _downloadSubscription;

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
      // Listen to download updates
      _downloadSubscription = _service.downloadStream.listen((downloads) {
        state = state.copyWith(activeDownloads: downloads);
      });

      state = state.copyWith(
        isRunning: true,
        serverUrl: 'http://$ip:${_service.port}',
        password: _service.password,
        activeDownloads: {},
      );
    }
  }

  Future<void> stopServer() async {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await _service.stop();
    state = state.copyWith(
      isRunning: false,
      serverUrl: null,
      activeDownloads: {},
    );
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
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
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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

                  // Server info (when running)
                  if (shareState.isRunning) ...[
                    _buildServerInfo(context, shareState, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Active downloads (when present)
                  if (shareState.isRunning && shareState.activeDownloads.isNotEmpty) ...[
                    _buildActiveDownloads(context, shareState, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Shared items card with fixed height
                  SizedBox(
                    height: 300,
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
          ),

          // Buttons - fixed at bottom
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

  Widget _buildActiveDownloads(BuildContext context, VitShareState state, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                'Active Downloads (${state.activeDownloads.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: state.activeDownloads.values
                    .map((download) => _buildDownloadItem(download, isDark))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadItem(ActiveDownload download, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                download.isComplete ? Icons.check_circle : Icons.file_download,
                size: 18,
                color: download.isComplete ? AppTheme.successGreen : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  download.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: download.isComplete 
                    ? AppTheme.successGreen.withOpacity(0.2)
                    : AppTheme.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  download.isComplete ? 'Complete' : download.formattedProgress,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: download.isComplete ? AppTheme.successGreen : AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: download.progress,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              color: download.isComplete ? AppTheme.successGreen : AppTheme.primaryBlue,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              const SizedBox(width: 4),
              Text(
                download.clientIp,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              if (!download.isComplete) ...[
                Icon(
                  Icons.speed,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  download.formattedSpeed,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  'ETA: ${download.formattedETA}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
              if (download.isComplete)
                Text(
                  '${download.formattedDownloaded} transferred',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
            ],
          ),
          if (!download.isComplete) ...[
            const SizedBox(height: 4),
            Text(
              '${download.formattedDownloaded} / ${download.formattedTotal}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
