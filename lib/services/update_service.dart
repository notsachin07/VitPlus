import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String githubOwner = 'notsachin07';
  static const String githubRepo = 'VitPlus';
  static const String currentVersion = '2.1.1'; // Update this with each release
  
  static String get releasesApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  
  static String get releasesPageUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases/latest';

  /// Check if a newer version is available on GitHub
  Future<UpdateInfo> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(releasesApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final releaseNotes = data['body'] as String? ?? 'No release notes available';
        final downloadUrl = _getWindowsDownloadUrl(data['assets'] as List);
        
        final isUpdateAvailable = _isNewerVersion(latestVersion, currentVersion);
        
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          isUpdateAvailable: isUpdateAvailable,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
        );
      } else if (response.statusCode == 404) {
        // No releases yet
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          isUpdateAvailable: false,
          releaseNotes: '',
          downloadUrl: null,
        );
      } else {
        throw Exception('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to check for updates: $e');
    }
  }

  /// Get the Windows download URL from release assets
  String? _getWindowsDownloadUrl(List assets) {
    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.contains('windows') && (name.endsWith('.zip') || name.endsWith('.exe'))) {
        return asset['browser_download_url'] as String;
      }
    }
    // Fallback: look for any zip file
    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (name.endsWith('.zip')) {
        return asset['browser_download_url'] as String;
      }
    }
    return null;
  }

  /// Compare version strings (e.g., "2.1.0" > "2.0.0")
  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    // Pad with zeros if needed
    while (latestParts.length < 3) latestParts.add(0);
    while (currentParts.length < 3) currentParts.add(0);
    
    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Download and apply update
  Future<void> downloadAndApplyUpdate(
    String downloadUrl,
    Function(double) onProgress,
  ) async {
    try {
      // Get temp directory for download
      final tempDir = await getTemporaryDirectory();
      final downloadPath = '${tempDir.path}\\VitPlus_update.zip';
      
      // Download the update
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);
      
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      final file = File(downloadPath);
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      
      await sink.close();
      
      // Create update script that will:
      // 1. Wait for app to close
      // 2. Extract new files
      // 3. Restart app
      await _createUpdateScript(downloadPath);
      
    } catch (e) {
      throw Exception('Failed to download update: $e');
    }
  }

  /// Create a batch script to apply the update after app closes
  Future<void> _createUpdateScript(String zipPath) async {
    final exePath = Platform.resolvedExecutable;
    final appDir = File(exePath).parent.path;
    final tempDir = await getTemporaryDirectory();
    final scriptPath = '${tempDir.path}\\update_vitplus.bat';
    
    // Use proper Windows path escaping (backslashes)
    final zipPathWin = zipPath.replaceAll('/', '\\');
    final appDirWin = appDir.replaceAll('/', '\\');
    final exePathWin = exePath.replaceAll('/', '\\');
    
    final script = '''
@echo off
echo Updating VitPlus...
echo Please wait...
timeout /t 3 /nobreak > nul

echo Extracting update...
powershell -Command "Expand-Archive -Path '$zipPathWin' -DestinationPath '$appDirWin' -Force"

echo Cleaning up...
if exist "$zipPathWin" del "$zipPathWin"

echo Starting VitPlus...
start "" "$exePathWin"

exit
''';

    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString(script);
    
    // Start the update script and exit current app
    await Process.start(
      'cmd',
      ['/c', scriptPath],
      mode: ProcessStartMode.detached,
    );
    
    // Exit the current app
    exit(0);
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool isUpdateAvailable;
  final String releaseNotes;
  final String? downloadUrl;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.isUpdateAvailable,
    required this.releaseNotes,
    this.downloadUrl,
  });
}
