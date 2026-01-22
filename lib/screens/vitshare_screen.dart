import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

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
  final List<ReceivedFile> receivedFiles;
  final String? receiveDirectory;

  VitShareState({
    this.isRunning = false,
    this.serverUrl,
    this.password = '',
    this.sharedPaths = const [],
    this.activeDownloads = const {},
    this.receivedFiles = const [],
    this.receiveDirectory,
  });

  VitShareState copyWith({
    bool? isRunning,
    String? serverUrl,
    String? password,
    List<String>? sharedPaths,
    Map<String, ActiveDownload>? activeDownloads,
    List<ReceivedFile>? receivedFiles,
    String? receiveDirectory,
  }) {
    return VitShareState(
      isRunning: isRunning ?? this.isRunning,
      serverUrl: serverUrl ?? this.serverUrl,
      password: password ?? this.password,
      sharedPaths: sharedPaths ?? this.sharedPaths,
      activeDownloads: activeDownloads ?? this.activeDownloads,
      receivedFiles: receivedFiles ?? this.receivedFiles,
      receiveDirectory: receiveDirectory ?? this.receiveDirectory,
    );
  }
}

class VitShareNotifier extends StateNotifier<VitShareState> {
  VitShareNotifier() : super(VitShareState());

  final VitShareService _service = VitShareService();
  StreamSubscription? _downloadSubscription;
  StreamSubscription? _receivedFilesSubscription;

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

      // Listen to received files updates
      _receivedFilesSubscription = _service.receivedFilesStream.listen((files) {
        state = state.copyWith(receivedFiles: files);
      });

      state = state.copyWith(
        isRunning: true,
        serverUrl: 'http://$ip:${_service.port}',
        password: _service.password,
        activeDownloads: {},
        receivedFiles: _service.receivedFiles,
        receiveDirectory: _service.receiveDirectory,
      );
    }
  }

  Future<void> stopServer() async {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    _receivedFilesSubscription?.cancel();
    _receivedFilesSubscription = null;
    await _service.stop();
    state = state.copyWith(
      isRunning: false,
      serverUrl: null,
      activeDownloads: {},
    );
  }

  Future<void> openReceivedFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final uri = Uri.file(filePath);
      await launchUrl(uri);
    }
  }

  Future<void> openReceiveFolder() async {
    final dir = _service.receiveDirectory;
    if (dir != null) {
      final directory = Directory(dir);
      if (await directory.exists()) {
        final uri = Uri.file(dir);
        await launchUrl(uri);
      }
    }
  }

  void removeReceivedFile(String filePath) {
    _service.removeReceivedFile(filePath);
    state = state.copyWith(receivedFiles: List.from(_service.receivedFiles));
  }

  void clearReceivedFiles() {
    _service.clearReceivedFiles();
    state = state.copyWith(receivedFiles: []);
  }

  // Remote download methods
  Future<({bool success, String? sessionCookie, String? error})> connectToRemote(String url, String password) async {
    return _service.connectToRemote(url, password);
  }

  Future<({List<RemoteFile> files, String? error})> fetchRemoteFiles(String url, String sessionCookie, {String path = '/'}) async {
    return _service.fetchRemoteFiles(url, sessionCookie, path: path);
  }

  Future<void> downloadFromRemote(String url, String sessionCookie, RemoteFile file) async {
    await _service.downloadFromRemote(url, sessionCookie, file);
  }

  Stream<Map<String, RemoteDownload>> get remoteDownloadStream => _service.remoteDownloadStream;

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _receivedFilesSubscription?.cancel();
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

                  // Received files (when present)
                  if (shareState.isRunning && shareState.receivedFiles.isNotEmpty) ...[
                    _buildReceivedFiles(context, shareState, isDark, notifier),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showReceiveFromUrlDialog(context, notifier),
              icon: const Icon(Icons.download),
              label: const Text('Receive from URL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: const BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
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

  Widget _buildReceivedFiles(BuildContext context, VitShareState state, bool isDark, VitShareNotifier notifier) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_done, size: 20, color: AppTheme.accentGold),
              const SizedBox(width: 8),
              Text(
                'Received Files (${state.receivedFiles.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: notifier.openReceiveFolder,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Open Folder'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentGold,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear All Received Files'),
                      content: const Text('This will remove all files from the received list. The files will remain in the folder.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            notifier.clearReceivedFiles();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorRed,
                          ),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: state.receivedFiles
                    .map((file) => _buildReceivedFileItem(file, isDark, notifier))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedFileItem(ReceivedFile file, bool isDark, VitShareNotifier notifier) {
    final timeSince = DateTime.now().difference(file.receivedAt);
    String timeAgo;
    if (timeSince.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (timeSince.inMinutes < 60) {
      timeAgo = '${timeSince.inMinutes}m ago';
    } else if (timeSince.inHours < 24) {
      timeAgo = '${timeSince.inHours}h ago';
    } else {
      timeAgo = '${timeSince.inDays}d ago';
    }

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.insert_drive_file,
              size: 24,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      file.senderIp,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      file.formattedSize,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => notifier.openReceivedFile(file.filePath),
            icon: const Icon(Icons.open_in_new, size: 20),
            tooltip: 'Open file',
            color: AppTheme.primaryBlue,
          ),
          IconButton(
            onPressed: () => notifier.removeReceivedFile(file.filePath),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Remove from list',
            color: AppTheme.errorRed,
          ),
        ],
      ),
    );
  }

  void _showReceiveFromUrlDialog(BuildContext context, VitShareNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => const _ReceiveFromUrlDialog(),
    );
  }
}

class _ReceiveFromUrlDialog extends StatefulWidget {
  const _ReceiveFromUrlDialog();

  @override
  State<_ReceiveFromUrlDialog> createState() => _ReceiveFromUrlDialogState();
}

class _ReceiveFromUrlDialogState extends State<_ReceiveFromUrlDialog> {
  final _urlController = TextEditingController();
  final _webviewController = WebviewController();
  
  bool _isWebviewReady = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();
      
      _webviewController.url.listen((url) {
        // Handle URL changes if needed
      });

      if (mounted) {
        setState(() {
          _isWebviewReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize browser: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _webviewController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    if (_urlController.text.isEmpty) {
      setState(() => _error = 'Please enter a URL');
      return;
    }

    var url = _urlController.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _webviewController.loadUrl(url);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.download, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Receive from VitShare',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Enter VitShare URL (e.g., http://192.168.1.100:5432)',
                            prefixIcon: const Icon(Icons.link, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkCard : Colors.white,
                          ),
                          onSubmitted: (_) => _loadUrl(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isWebviewReady && !_isLoading ? _loadUrl : null,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_forward),
                        label: const Text('Go'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: AppTheme.errorRed.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Webview content
            Expanded(
              child: !_isWebviewReady
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Initializing browser...'),
                      ],
                    ),
                  )
                : Webview(
                    _webviewController,
                    permissionRequested: (url, kind, isUserInitiated) => 
                      WebviewPermissionDecision.allow,
                  ),
            ),

            // Footer with instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter the URL shared by your friend, log in with the password, and download files directly.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
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
