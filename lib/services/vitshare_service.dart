import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;

/// Represents an active download with progress tracking
class ActiveDownload {
  final String fileName;
  final String clientIp;
  final int totalBytes;
  int downloadedBytes;
  final DateTime startTime;
  bool isComplete;

  ActiveDownload({
    required this.fileName,
    required this.clientIp,
    required this.totalBytes,
    this.downloadedBytes = 0,
    required this.startTime,
    this.isComplete = false,
  });

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0;
  
  int get bytesPerSecond {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed == 0) return 0;
    return downloadedBytes ~/ elapsed;
  }

  Duration get estimatedTimeRemaining {
    if (bytesPerSecond == 0) return Duration.zero;
    final remainingBytes = totalBytes - downloadedBytes;
    return Duration(seconds: remainingBytes ~/ bytesPerSecond);
  }

  String get formattedProgress {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  String get formattedSpeed {
    return _formatBytes(bytesPerSecond) + '/s';
  }

  String get formattedETA {
    final eta = estimatedTimeRemaining;
    if (eta.inHours > 0) {
      return '${eta.inHours}h ${eta.inMinutes.remainder(60)}m';
    } else if (eta.inMinutes > 0) {
      return '${eta.inMinutes}m ${eta.inSeconds.remainder(60)}s';
    } else {
      return '${eta.inSeconds}s';
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDownloaded => _formatBytes(downloadedBytes);
  String get formattedTotal => _formatBytes(totalBytes);
}

/// Represents a received file
class ReceivedFile {
  final String fileName;
  final String filePath;
  final int fileSize;
  final String senderIp;
  final DateTime receivedAt;

  ReceivedFile({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.senderIp,
    required this.receivedAt,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Represents a file available on a remote VitShare server
class RemoteFile {
  final String name;
  final String path;
  final int size;
  final bool isDirectory;

  RemoteFile({
    required this.name,
    required this.path,
    required this.size,
    required this.isDirectory,
  });

  String get formattedSize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  factory RemoteFile.fromJson(Map<String, dynamic> json) {
    return RemoteFile(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      size: json['size'] ?? 0,
      isDirectory: json['isDir'] ?? false,
    );
  }
}

/// Represents a download in progress from a remote server
class RemoteDownload {
  final String fileName;
  final String serverUrl;
  final int totalBytes;
  int downloadedBytes;
  final DateTime startTime;
  bool isComplete;
  bool isFailed;
  String? error;

  RemoteDownload({
    required this.fileName,
    required this.serverUrl,
    required this.totalBytes,
    this.downloadedBytes = 0,
    required this.startTime,
    this.isComplete = false,
    this.isFailed = false,
    this.error,
  });

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0;

  int get bytesPerSecond {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    if (elapsed == 0) return 0;
    return downloadedBytes ~/ elapsed;
  }

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';

  String get formattedSpeed {
    final bps = bytesPerSecond;
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedDownloaded {
    if (downloadedBytes < 1024) return '$downloadedBytes B';
    if (downloadedBytes < 1024 * 1024) return '${(downloadedBytes / 1024).toStringAsFixed(1)} KB';
    if (downloadedBytes < 1024 * 1024 * 1024) return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(downloadedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedTotal {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class VitShareService {
  HttpServer? _server;
  final List<String> _sharedPaths = [];
  String _password = '';
  int _port = 5000;
  bool _isRunning = false;
  final Set<String> _authenticatedSessions = {};
  
  // Active downloads tracking
  final Map<String, ActiveDownload> _activeDownloads = {};
  final _downloadController = StreamController<Map<String, ActiveDownload>>.broadcast();

  // Received files tracking
  final List<ReceivedFile> _receivedFiles = [];
  final _receivedFilesController = StreamController<List<ReceivedFile>>.broadcast();
  String? _receiveDirectory;

  // Remote downloads tracking
  final Map<String, RemoteDownload> _remoteDownloads = {};
  final _remoteDownloadController = StreamController<Map<String, RemoteDownload>>.broadcast();

  bool get isRunning => _isRunning;
  int get port => _port;
  String get password => _password;
  List<String> get sharedPaths => List.unmodifiable(_sharedPaths);
  Map<String, ActiveDownload> get activeDownloads => Map.unmodifiable(_activeDownloads);
  Stream<Map<String, ActiveDownload>> get downloadStream => _downloadController.stream;
  List<ReceivedFile> get receivedFiles => List.unmodifiable(_receivedFiles);
  Stream<List<ReceivedFile>> get receivedFilesStream => _receivedFilesController.stream;
  String? get receiveDirectory => _receiveDirectory;
  Map<String, RemoteDownload> get remoteDownloads => Map.unmodifiable(_remoteDownloads);
  Stream<Map<String, RemoteDownload>> get remoteDownloadStream => _remoteDownloadController.stream;

  String generatePassword({int length = 4}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void addPath(String path) {
    if (!_sharedPaths.contains(path)) {
      _sharedPaths.add(path);
    }
  }

  void removePath(String path) {
    _sharedPaths.remove(path);
  }

  void clearPaths() {
    _sharedPaths.clear();
  }

  Future<String> getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    return '127.0.0.1';
  }

  Future<bool> start({String? password, int? port}) async {
    if (_isRunning) return false;

    _password = password ?? generatePassword();
    _port = port ?? (5000 + Random().nextInt(5000));

    // Create receive directory
    final appDir = await getApplicationDocumentsDirectory();
    _receiveDirectory = '${appDir.path}\\VitShare_Received';
    final receiveDir = Directory(_receiveDirectory!);
    if (!await receiveDir.exists()) {
      await receiveDir.create(recursive: true);
    }

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;

      _server!.listen(_handleRequest);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
    _authenticatedSessions.clear();
    _activeDownloads.clear();
    _notifyDownloadUpdate();
  }

  void _notifyDownloadUpdate() {
    if (!_downloadController.isClosed) {
      _downloadController.add(Map.from(_activeDownloads));
    }
  }

  void _notifyReceivedFilesUpdate() {
    if (!_receivedFilesController.isClosed) {
      _receivedFilesController.add(List.from(_receivedFiles));
    }
  }

  void clearReceivedFiles() {
    _receivedFiles.clear();
    _notifyReceivedFilesUpdate();
  }

  void removeReceivedFile(String filePath) {
    _receivedFiles.removeWhere((f) => f.filePath == filePath);
    _notifyReceivedFilesUpdate();
  }

  void _notifyRemoteDownloadUpdate() {
    if (!_remoteDownloadController.isClosed) {
      _remoteDownloadController.add(Map.from(_remoteDownloads));
    }
  }

  /// Connect to a remote VitShare server and authenticate
  Future<({bool success, String? sessionCookie, String? error})> connectToRemote(String serverUrl, String password) async {
    try {
      // Normalize URL
      var url = serverUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      // Login to the server
      final loginUrl = Uri.parse('$url/login');
      final response = await http.post(
        loginUrl,
        body: {'password': password},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 302) {
        // Extract session cookie
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null) {
          final sessionMatch = RegExp(r'session=([^;]+)').firstMatch(setCookie);
          if (sessionMatch != null) {
            return (success: true, sessionCookie: sessionMatch.group(1), error: null);
          }
        }
        // Try to get cookie from redirect response
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.contains('session=')) {
          final match = RegExp(r'session=([^;]+)').firstMatch(cookies);
          if (match != null) {
            return (success: true, sessionCookie: match.group(1), error: null);
          }
        }
        return (success: false, sessionCookie: null, error: 'Invalid password');
      } else {
        return (success: false, sessionCookie: null, error: 'Invalid password');
      }
    } catch (e) {
      return (success: false, sessionCookie: null, error: 'Connection failed: ${e.toString()}');
    }
  }

  /// Fetch file list from a remote VitShare server
  Future<({List<RemoteFile> files, String? error})> fetchRemoteFiles(String serverUrl, String sessionCookie, {String path = '/'}) async {
    try {
      var url = serverUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      final apiUrl = Uri.parse('$url/api/files').replace(queryParameters: {'path': path});
      final response = await http.get(
        apiUrl,
        headers: {'Cookie': 'session=$sessionCookie'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['files'] != null) {
          final files = (data['files'] as List)
              .map((f) => RemoteFile.fromJson(f as Map<String, dynamic>))
              .toList();
          return (files: files, error: null);
        }
        return (files: <RemoteFile>[], error: 'Failed to parse file list');
      } else if (response.statusCode == 401) {
        return (files: <RemoteFile>[], error: 'Session expired');
      } else {
        return (files: <RemoteFile>[], error: 'Failed to fetch files');
      }
    } catch (e) {
      return (files: <RemoteFile>[], error: 'Connection error: ${e.toString()}');
    }
  }

  /// Download a file from a remote VitShare server
  Future<void> downloadFromRemote(String serverUrl, String sessionCookie, RemoteFile file) async {
    // Ensure receive directory exists
    if (_receiveDirectory == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _receiveDirectory = '${appDir.path}\\VitShare_Received';
      final receiveDir = Directory(_receiveDirectory!);
      if (!await receiveDir.exists()) {
        await receiveDir.create(recursive: true);
      }
    }

    var url = serverUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final downloadId = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    
    // Create download entry
    _remoteDownloads[downloadId] = RemoteDownload(
      fileName: file.name,
      serverUrl: url,
      totalBytes: file.size,
      startTime: DateTime.now(),
    );
    _notifyRemoteDownloadUpdate();

    try {
      // The server expects /download/{encoded_path}
      final encodedPath = Uri.encodeComponent(file.path);
      final downloadUrl = Uri.parse('$url/download/$encodedPath');

      final client = http.Client();
      final request = http.Request('GET', downloadUrl);
      request.headers['Cookie'] = 'session=$sessionCookie';

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        _remoteDownloads[downloadId]!.isFailed = true;
        _remoteDownloads[downloadId]!.error = 'Download failed: ${streamedResponse.statusCode}';
        _notifyRemoteDownloadUpdate();
        client.close();
        return;
      }

      // Generate unique filename if exists
      var savePath = '$_receiveDirectory\\${file.name}';
      var saveFile = File(savePath);
      var counter = 1;
      while (await saveFile.exists()) {
        final ext = file.name.contains('.') ? '.${file.name.split('.').last}' : '';
        final nameWithoutExt = file.name.contains('.') 
            ? file.name.substring(0, file.name.lastIndexOf('.'))
            : file.name;
        savePath = '$_receiveDirectory\\${nameWithoutExt}_$counter$ext';
        saveFile = File(savePath);
        counter++;
      }

      final sink = saveFile.openWrite();
      
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        _remoteDownloads[downloadId]!.downloadedBytes += chunk.length;
        _notifyRemoteDownloadUpdate();
      }

      await sink.close();
      client.close();

      _remoteDownloads[downloadId]!.isComplete = true;
      _notifyRemoteDownloadUpdate();

      // Add to received files
      final receivedFile = ReceivedFile(
        fileName: saveFile.uri.pathSegments.last,
        filePath: savePath,
        fileSize: _remoteDownloads[downloadId]!.downloadedBytes,
        senderIp: Uri.parse(url).host,
        receivedAt: DateTime.now(),
      );
      _receivedFiles.insert(0, receivedFile);
      _notifyReceivedFilesUpdate();

      // Remove from active downloads after a delay
      Future.delayed(const Duration(seconds: 3), () {
        _remoteDownloads.remove(downloadId);
        _notifyRemoteDownloadUpdate();
      });
    } catch (e) {
      _remoteDownloads[downloadId]!.isFailed = true;
      _remoteDownloads[downloadId]!.error = e.toString();
      _notifyRemoteDownloadUpdate();
    }
  }

  void clearRemoteDownloads() {
    _remoteDownloads.clear();
    _notifyRemoteDownloadUpdate();
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final sessionId = request.cookies
        .where((c) => c.name == 'session')
        .map((c) => c.value)
        .firstOrNull;

    if (path == '/login') {
      await _handleLogin(request);
      return;
    }

    if (path == '/logout') {
      if (sessionId != null) {
        _authenticatedSessions.remove(sessionId);
      }
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set('Location', '/login');
      await request.response.close();
      return;
    }

    if (sessionId == null || !_authenticatedSessions.contains(sessionId)) {
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set('Location', '/login');
      await request.response.close();
      return;
    }

    if (path == '/' || path.isEmpty) {
      await _handleIndex(request);
    } else if (path == '/api/files') {
      await _handleApiFiles(request);
    } else if (path.startsWith('/download/')) {
      await _handleDownload(request);
    } else if (path == '/upload' && request.method == 'POST') {
      await _handleUpload(request);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      await request.response.close();
    }
  }

  Future<void> _handleLogin(HttpRequest request) async {
    if (request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final params = Uri.splitQueryString(body);
      final inputPassword = params['password'] ?? '';

      if (inputPassword == _password) {
        final sessionId = _generateSessionId();
        _authenticatedSessions.add(sessionId);

        request.response.cookies.add(Cookie('session', sessionId)
          ..httpOnly = true
          ..path = '/');
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set('Location', '/');
        await request.response.close();
        return;
      }
    }

    request.response.headers.contentType = ContentType.html;
    request.response.write(_loginPage(request.method == 'POST'));
    await request.response.close();
  }

  Future<void> _handleIndex(HttpRequest request) async {
    final files = await _getFilesList();

    request.response.headers.contentType = ContentType.html;
    request.response.write(_indexPage(files));
    await request.response.close();
  }

  Future<void> _handleApiFiles(HttpRequest request) async {
    final files = await _getFilesList();

    request.response.headers.contentType = ContentType.json;
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.write(json.encode({
      'success': true,
      'files': files,
    }));
    await request.response.close();
  }

  Future<List<Map<String, dynamic>>> _getFilesList() async {
    final files = <Map<String, dynamic>>[];

    for (final sharedPath in _sharedPaths) {
      final entity = FileSystemEntity.typeSync(sharedPath);
      
      if (entity == FileSystemEntityType.file) {
        final file = File(sharedPath);
        files.add({
          'name': file.uri.pathSegments.last,
          'path': sharedPath,
          'size': await file.length(),
          'isDir': false,
        });
      } else if (entity == FileSystemEntityType.directory) {
        final dir = Directory(sharedPath);
        await for (final item in dir.list(recursive: true)) {
          if (item is File) {
            files.add({
              'name': item.path.replaceFirst(sharedPath, '').replaceAll('\\', '/'),
              'path': item.path,
              'size': await item.length(),
              'isDir': false,
            });
          }
        }
      }
    }

    return files;
  }

  Future<void> _handleDownload(HttpRequest request) async {
    final encodedPath = request.uri.path.replaceFirst('/download/', '');
    final filePath = Uri.decodeComponent(encodedPath);

    bool isAllowed = false;
    for (final shared in _sharedPaths) {
      if (filePath.startsWith(shared) || filePath == shared) {
        isAllowed = true;
        break;
      }
    }

    if (!isAllowed) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write('Access Denied');
      await request.response.close();
      return;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File Not Found');
      await request.response.close();
      return;
    }

    final filename = file.uri.pathSegments.last;
    final fileSize = await file.length();
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'Unknown';
    final downloadId = '${clientIp}_${filename}_${DateTime.now().millisecondsSinceEpoch}';

    // Create active download entry
    _activeDownloads[downloadId] = ActiveDownload(
      fileName: filename,
      clientIp: clientIp,
      totalBytes: fileSize,
      startTime: DateTime.now(),
    );
    _notifyDownloadUpdate();

    request.response.headers.set('Content-Disposition', 'attachment; filename="$filename"');
    request.response.headers.contentType = ContentType.binary;
    request.response.headers.contentLength = fileSize;

    try {
      // Stream the file with progress tracking
      final fileStream = file.openRead();
      await for (final chunk in fileStream) {
        request.response.add(chunk);
        
        // Update progress
        if (_activeDownloads.containsKey(downloadId)) {
          _activeDownloads[downloadId]!.downloadedBytes += chunk.length;
          _notifyDownloadUpdate();
        }
      }
      
      // Mark as complete
      if (_activeDownloads.containsKey(downloadId)) {
        _activeDownloads[downloadId]!.isComplete = true;
        _notifyDownloadUpdate();
        
        // Remove after a short delay so user can see completion
        Future.delayed(const Duration(seconds: 2), () {
          _activeDownloads.remove(downloadId);
          _notifyDownloadUpdate();
        });
      }
      
      await request.response.close();
    } catch (e) {
      // Download was interrupted
      _activeDownloads.remove(downloadId);
      _notifyDownloadUpdate();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleUpload(HttpRequest request) async {
    try {
      final contentType = request.headers.contentType;
      if (contentType == null || !contentType.mimeType.contains('multipart/form-data')) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(json.encode({'error': 'Invalid content type'}));
        await request.response.close();
        return;
      }

      final boundary = contentType.parameters['boundary'];
      if (boundary == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(json.encode({'error': 'Missing boundary'}));
        await request.response.close();
        return;
      }

      final clientIp = request.connectionInfo?.remoteAddress.address ?? 'Unknown';
      
      // Parse multipart form data
      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(request).toList();

      for (final part in parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition == null) continue;

        // Extract filename from content-disposition
        final filenameMatch = RegExp(r'filename="([^"]*)"').firstMatch(contentDisposition);
        if (filenameMatch == null) continue;

        var filename = filenameMatch.group(1)!;
        // Sanitize filename
        filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        
        if (filename.isEmpty) continue;

        // Generate unique filename if exists
        var savePath = '$_receiveDirectory\\$filename';
        var file = File(savePath);
        var counter = 1;
        while (await file.exists()) {
          final ext = filename.contains('.') ? '.${filename.split('.').last}' : '';
          final nameWithoutExt = filename.contains('.') 
              ? filename.substring(0, filename.lastIndexOf('.'))
              : filename;
          savePath = '$_receiveDirectory\\${nameWithoutExt}_$counter$ext';
          file = File(savePath);
          counter++;
        }

        // Save file
        final sink = file.openWrite();
        int fileSize = 0;
        await for (final chunk in part) {
          sink.add(chunk);
          fileSize += chunk.length as int;
        }
        await sink.close();

        // Add to received files
        final receivedFile = ReceivedFile(
          fileName: file.uri.pathSegments.last,
          filePath: savePath,
          fileSize: fileSize,
          senderIp: clientIp,
          receivedAt: DateTime.now(),
        );
        _receivedFiles.insert(0, receivedFile);
        _notifyReceivedFilesUpdate();
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode({'success': true, 'message': 'File(s) uploaded successfully'}));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode({'error': 'Upload failed: $e'}));
      await request.response.close();
    }
  }

  String _generateSessionId() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }

  String _loginPage(bool showError) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VitShare - Secure File Sharing</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    :root {
      --primary: #6366f1;
      --primary-hover: #4f46e5;
      --bg-dark: #0f0f23;
      --bg-card: #1a1a2e;
      --bg-input: #16162a;
      --border: #2d2d4a;
      --text: #e2e8f0;
      --text-muted: #94a3b8;
      --error: #ef4444;
      --error-bg: rgba(239, 68, 68, 0.1);
      --glow: rgba(99, 102, 241, 0.4);
    }
    
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--bg-dark);
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 1rem;
      position: relative;
      overflow: hidden;
    }
    
    /* Animated background */
    body::before {
      content: '';
      position: absolute;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: radial-gradient(circle at 30% 30%, rgba(99, 102, 241, 0.08) 0%, transparent 50%),
                  radial-gradient(circle at 70% 70%, rgba(236, 72, 153, 0.08) 0%, transparent 50%);
      animation: bgMove 20s ease-in-out infinite;
    }
    
    @keyframes bgMove {
      0%, 100% { transform: translate(0, 0) rotate(0deg); }
      50% { transform: translate(2%, 2%) rotate(5deg); }
    }
    
    .container {
      position: relative;
      background: var(--bg-card);
      padding: 3rem;
      border-radius: 24px;
      border: 1px solid var(--border);
      width: 100%;
      max-width: 420px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5),
                  0 0 80px -20px var(--glow);
      backdrop-filter: blur(10px);
    }
    
    .logo {
      text-align: center;
      margin-bottom: 2rem;
    }
    
    .logo-icon {
      width: 80px;
      height: 80px;
      background: linear-gradient(135deg, var(--primary), #ec4899);
      border-radius: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 1rem;
      font-size: 2.5rem;
      box-shadow: 0 10px 40px -10px var(--glow);
    }
    
    h1 {
      color: var(--text);
      font-size: 1.75rem;
      font-weight: 700;
      letter-spacing: -0.025em;
    }
    
    .subtitle {
      color: var(--text-muted);
      font-size: 0.95rem;
      margin-top: 0.5rem;
    }
    
    .error {
      background: var(--error-bg);
      color: var(--error);
      padding: 1rem;
      border-radius: 12px;
      margin-bottom: 1.5rem;
      display: flex;
      align-items: center;
      gap: 0.75rem;
      font-size: 0.9rem;
      border: 1px solid rgba(239, 68, 68, 0.2);
    }
    
    .form-group {
      margin-bottom: 1.5rem;
    }
    
    label {
      display: block;
      color: var(--text);
      font-weight: 500;
      margin-bottom: 0.5rem;
      font-size: 0.9rem;
    }
    
    .input-wrapper {
      position: relative;
    }
    
    .input-icon {
      position: absolute;
      left: 1rem;
      top: 50%;
      transform: translateY(-50%);
      font-size: 1.25rem;
      opacity: 0.5;
    }
    
    input {
      width: 100%;
      padding: 1rem 1rem 1rem 3rem;
      border: 2px solid var(--border);
      border-radius: 12px;
      background: var(--bg-input);
      color: var(--text);
      font-size: 1rem;
      font-family: inherit;
      transition: all 0.2s ease;
    }
    
    input:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.1);
    }
    
    input::placeholder {
      color: var(--text-muted);
    }
    
    button {
      width: 100%;
      padding: 1rem;
      background: linear-gradient(135deg, var(--primary), #8b5cf6);
      color: white;
      border: none;
      border-radius: 12px;
      font-size: 1rem;
      font-weight: 600;
      font-family: inherit;
      cursor: pointer;
      transition: all 0.2s ease;
      position: relative;
      overflow: hidden;
    }
    
    button::before {
      content: '';
      position: absolute;
      top: 0;
      left: -100%;
      width: 100%;
      height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
      transition: left 0.5s ease;
    }
    
    button:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 40px -10px var(--glow);
    }
    
    button:hover::before {
      left: 100%;
    }
    
    button:active {
      transform: translateY(0);
    }
    
    .footer {
      text-align: center;
      margin-top: 2rem;
      padding-top: 1.5rem;
      border-top: 1px solid var(--border);
      color: var(--text-muted);
      font-size: 0.85rem;
    }
    
    .footer a {
      color: var(--primary);
      text-decoration: none;
    }
    
    @media (max-width: 480px) {
      .container { padding: 2rem; }
      h1 { font-size: 1.5rem; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">
      <div class="logo-icon">📁</div>
      <h1>VitShare</h1>
      <p class="subtitle">Secure local file sharing</p>
    </div>
    
    ${showError ? '<div class="error"><span>⚠️</span> Incorrect password. Please try again.</div>' : ''}
    
    <form method="POST">
      <div class="form-group">
        <label for="password">Password</label>
        <div class="input-wrapper">
          <span class="input-icon">🔑</span>
          <input type="password" id="password" name="password" placeholder="Enter access password" required autofocus>
        </div>
      </div>
      <button type="submit">
        Unlock Files →
      </button>
    </form>
    
    <div class="footer">
      Powered by <a href="https://github.com/notsachin07/VitPlus" target="_blank">VitPlus</a>
    </div>
  </div>
</body>
</html>
''';
  }

  String _indexPage(List<Map<String, dynamic>> files) {
    final fileItems = files.asMap().entries.map((entry) {
      final index = entry.key;
      final f = entry.value;
      final encodedPath = Uri.encodeComponent(f['path']);
      final size = _formatBytes(f['size']);
      final name = f['name'] as String;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final icon = _getFileIcon(ext);
      final color = _getFileColor(ext);
      
      return '''<div class="file-card" style="animation-delay: ${index * 0.05}s">
        <a href="/download/$encodedPath" class="file-link">
          <div class="file-icon" style="background: $color;">
            <span>$icon</span>
          </div>
          <div class="file-info">
            <span class="file-name">${f['name']}</span>
            <span class="file-meta">
              <span class="file-size">$size</span>
              <span class="file-ext">${ext.toUpperCase()}</span>
            </span>
          </div>
          <div class="download-btn">
            <svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
            </svg>
          </div>
        </a>
      </div>''';
    }).join('\n');

    final totalSize = files.fold<int>(0, (sum, f) => sum + (f['size'] as int));
    final totalSizeFormatted = _formatBytes(totalSize);
    final fileCount = files.length;
    
    final mainContent = files.isNotEmpty 
      ? '''<div class="search-bar">
        <div class="search-wrapper">
          <span class="search-icon">🔍</span>
          <input type="text" class="search-input" id="searchInput" placeholder="Search files..." onkeyup="filterFiles()">
        </div>
      </div>
      
      <div class="files-grid" id="filesGrid">
        $fileItems
      </div>'''
      : '''<div class="empty-state">
        <div class="empty-icon">📭</div>
        <h2>No files shared yet</h2>
        <p>Files added in VitPlus will appear here</p>
      </div>''';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VitShare - Shared Files</title>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    :root {
      --primary: #6366f1;
      --primary-hover: #4f46e5;
      --bg-dark: #0f0f23;
      --bg-card: #1a1a2e;
      --bg-hover: #252542;
      --border: #2d2d4a;
      --text: #e2e8f0;
      --text-muted: #94a3b8;
      --glow: rgba(99, 102, 241, 0.3);
    }
    
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--bg-dark);
      color: var(--text);
      min-height: 100vh;
      position: relative;
    }
    
    body::before, body::after {
      content: '';
      position: fixed;
      border-radius: 50%;
      filter: blur(100px);
      opacity: 0.5;
      z-index: 0;
    }
    
    body::before {
      width: 600px;
      height: 600px;
      background: radial-gradient(circle, rgba(99, 102, 241, 0.15), transparent 70%);
      top: -200px;
      right: -200px;
    }
    
    body::after {
      width: 500px;
      height: 500px;
      background: radial-gradient(circle, rgba(236, 72, 153, 0.1), transparent 70%);
      bottom: -150px;
      left: -150px;
    }
    
    .wrapper {
      position: relative;
      z-index: 1;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    
    header {
      background: rgba(26, 26, 46, 0.8);
      backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border);
      padding: 1.5rem 2rem;
      position: sticky;
      top: 0;
      z-index: 100;
    }
    
    .header-content {
      max-width: 1200px;
      margin: 0 auto;
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 1rem;
    }
    
    .brand {
      display: flex;
      align-items: center;
      gap: 1rem;
    }
    
    .brand-icon {
      width: 48px;
      height: 48px;
      background: linear-gradient(135deg, var(--primary), #ec4899);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.5rem;
    }
    
    .brand-text h1 {
      font-size: 1.5rem;
      font-weight: 700;
      letter-spacing: -0.025em;
    }
    
    .brand-text p {
      color: var(--text-muted);
      font-size: 0.85rem;
    }
    
    .header-stats {
      display: flex;
      gap: 2rem;
    }
    
    .stat {
      text-align: center;
    }
    
    .stat-value {
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--primary);
    }
    
    .stat-label {
      font-size: 0.75rem;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    
    .logout-btn {
      padding: 0.625rem 1.25rem;
      background: transparent;
      border: 1px solid var(--border);
      border-radius: 8px;
      color: var(--text);
      font-size: 0.9rem;
      font-family: inherit;
      cursor: pointer;
      transition: all 0.2s;
      text-decoration: none;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    .logout-btn:hover {
      background: var(--bg-hover);
      border-color: var(--primary);
    }
    
    main {
      flex: 1;
      padding: 2rem;
      max-width: 1200px;
      margin: 0 auto;
      width: 100%;
    }
    
    .search-bar {
      margin-bottom: 2rem;
    }
    
    .search-input {
      width: 100%;
      max-width: 400px;
      padding: 0.875rem 1rem 0.875rem 3rem;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 12px;
      color: var(--text);
      font-size: 0.95rem;
      font-family: inherit;
      transition: all 0.2s;
    }
    
    .search-input:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
    }
    
    .search-wrapper {
      position: relative;
      display: inline-block;
      width: 100%;
      max-width: 400px;
    }
    
    .search-icon {
      position: absolute;
      left: 1rem;
      top: 50%;
      transform: translateY(-50%);
      color: var(--text-muted);
    }
    
    .files-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 1rem;
    }
    
    .file-card {
      animation: fadeInUp 0.4s ease forwards;
      opacity: 0;
    }
    
    @keyframes fadeInUp {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    .file-link {
      display: flex;
      align-items: center;
      gap: 1rem;
      padding: 1.25rem;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 16px;
      text-decoration: none;
      color: var(--text);
      transition: all 0.2s ease;
    }
    
    .file-link:hover {
      background: var(--bg-hover);
      border-color: var(--primary);
      transform: translateY(-2px);
      box-shadow: 0 10px 40px -10px rgba(0, 0, 0, 0.3);
    }
    
    .file-icon {
      width: 52px;
      height: 52px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 1.5rem;
      flex-shrink: 0;
    }
    
    .file-info {
      flex: 1;
      min-width: 0;
    }
    
    .file-name {
      display: block;
      font-weight: 600;
      margin-bottom: 0.375rem;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    
    .file-meta {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      font-size: 0.85rem;
      color: var(--text-muted);
    }
    
    .file-ext {
      padding: 0.125rem 0.5rem;
      background: rgba(99, 102, 241, 0.1);
      border-radius: 4px;
      font-size: 0.7rem;
      font-weight: 600;
      color: var(--primary);
    }
    
    .download-btn {
      width: 40px;
      height: 40px;
      background: rgba(99, 102, 241, 0.1);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--primary);
      transition: all 0.2s;
      flex-shrink: 0;
    }
    
    .file-link:hover .download-btn {
      background: var(--primary);
      color: white;
    }
    
    .empty-state {
      text-align: center;
      padding: 4rem 2rem;
      background: var(--bg-card);
      border-radius: 20px;
      border: 1px dashed var(--border);
    }
    
    .empty-icon {
      width: 100px;
      height: 100px;
      background: rgba(99, 102, 241, 0.1);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 3rem;
      margin: 0 auto 1.5rem;
    }
    
    .empty-state h2 {
      font-size: 1.25rem;
      margin-bottom: 0.5rem;
    }
    
    .empty-state p {
      color: var(--text-muted);
    }
    
    /* Upload Section Styles */
    .upload-section {
      margin-bottom: 2rem;
      padding: 2rem;
      background: var(--bg-card);
      border: 2px dashed var(--border);
      border-radius: 20px;
      text-align: center;
      transition: all 0.3s ease;
      cursor: pointer;
    }
    
    .upload-section:hover, .upload-section.dragover {
      border-color: var(--primary);
      background: rgba(99, 102, 241, 0.05);
    }
    
    .upload-section.dragover {
      transform: scale(1.02);
    }
    
    .upload-icon {
      width: 80px;
      height: 80px;
      background: linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(236, 72, 153, 0.2));
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 2rem;
      margin: 0 auto 1rem;
    }
    
    .upload-section h3 {
      font-size: 1.1rem;
      margin-bottom: 0.5rem;
    }
    
    .upload-section p {
      color: var(--text-muted);
      font-size: 0.9rem;
      margin-bottom: 1rem;
    }
    
    .upload-btn {
      display: inline-block;
      padding: 0.75rem 1.5rem;
      background: linear-gradient(135deg, var(--primary), #8b5cf6);
      color: white;
      border: none;
      border-radius: 10px;
      font-size: 0.95rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    
    .upload-btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 5px 20px rgba(99, 102, 241, 0.3);
    }
    
    #fileInput {
      display: none;
    }
    
    .upload-progress {
      margin-top: 1.5rem;
      display: none;
    }
    
    .upload-progress.active {
      display: block;
    }
    
    .progress-bar-container {
      background: var(--bg-dark);
      border-radius: 10px;
      overflow: hidden;
      height: 8px;
      margin-bottom: 0.75rem;
    }
    
    .progress-bar {
      height: 100%;
      background: linear-gradient(90deg, var(--primary), #ec4899);
      border-radius: 10px;
      transition: width 0.3s ease;
      width: 0%;
    }
    
    .upload-status {
      font-size: 0.85rem;
      color: var(--text-muted);
    }
    
    .upload-success {
      color: #22c55e;
      display: none;
      align-items: center;
      justify-content: center;
      gap: 0.5rem;
      margin-top: 1rem;
      font-weight: 500;
    }
    
    .upload-success.show {
      display: flex;
    }
    
    .section-title {
      font-size: 1rem;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 1rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    footer {
      text-align: center;
      padding: 2rem;
      color: var(--text-muted);
      font-size: 0.85rem;
    }
    
    footer a {
      color: var(--primary);
      text-decoration: none;
    }
    
    @media (max-width: 640px) {
      header { padding: 1rem; }
      main { padding: 1rem; }
      .header-stats { display: none; }
      .files-grid { grid-template-columns: 1fr; }
      .brand-text h1 { font-size: 1.25rem; }
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <header>
      <div class="header-content">
        <div class="brand">
          <div class="brand-icon">📁</div>
          <div class="brand-text">
            <h1>VitShare</h1>
            <p>Secure local file sharing</p>
          </div>
        </div>
        
        <div class="header-stats">
          <div class="stat">
            <div class="stat-value">$fileCount</div>
            <div class="stat-label">Files</div>
          </div>
          <div class="stat">
            <div class="stat-value">$totalSizeFormatted</div>
            <div class="stat-label">Total Size</div>
          </div>
        </div>
        
        <a href="/logout" class="logout-btn">
          <span>🚪</span> Logout
        </a>
      </div>
    </header>
    
    <main>
      <!-- Upload Section -->
      <div class="upload-section" id="uploadArea" onclick="document.getElementById('fileInput').click()">
        <input type="file" id="fileInput" multiple onchange="handleFileSelect(event)">
        <div class="upload-icon">📤</div>
        <h3>Send Files to Device</h3>
        <p>Drag & drop files here or click to browse</p>
        <button class="upload-btn" onclick="event.stopPropagation(); document.getElementById('fileInput').click()">
          Choose Files
        </button>
        <div class="upload-progress" id="uploadProgress">
          <div class="progress-bar-container">
            <div class="progress-bar" id="progressBar"></div>
          </div>
          <div class="upload-status" id="uploadStatus">Uploading...</div>
        </div>
        <div class="upload-success" id="uploadSuccess">
          <span>✓</span> Files sent successfully!
        </div>
      </div>
      
      <div class="section-title">
        <span>📥</span> Available Downloads
      </div>
      
      $mainContent
    </main>
    
    <footer>
      Powered by <a href="https://github.com/notsachin07/VitPlus" target="_blank">VitPlus</a> • Made with ❤️
    </footer>
  </div>
  
  <script>
    const uploadArea = document.getElementById('uploadArea');
    const fileInput = document.getElementById('fileInput');
    const uploadProgress = document.getElementById('uploadProgress');
    const progressBar = document.getElementById('progressBar');
    const uploadStatus = document.getElementById('uploadStatus');
    const uploadSuccess = document.getElementById('uploadSuccess');
    
    // Drag and drop
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      uploadArea.addEventListener(eventName, preventDefaults, false);
    });
    
    function preventDefaults(e) {
      e.preventDefault();
      e.stopPropagation();
    }
    
    ['dragenter', 'dragover'].forEach(eventName => {
      uploadArea.addEventListener(eventName, () => uploadArea.classList.add('dragover'), false);
    });
    
    ['dragleave', 'drop'].forEach(eventName => {
      uploadArea.addEventListener(eventName, () => uploadArea.classList.remove('dragover'), false);
    });
    
    uploadArea.addEventListener('drop', (e) => {
      const files = e.dataTransfer.files;
      if (files.length > 0) {
        uploadFiles(files);
      }
    });
    
    function handleFileSelect(e) {
      const files = e.target.files;
      if (files.length > 0) {
        uploadFiles(files);
      }
    }
    
    function uploadFiles(files) {
      const formData = new FormData();
      for (let i = 0; i < files.length; i++) {
        formData.append('files', files[i]);
      }
      
      uploadProgress.classList.add('active');
      uploadSuccess.classList.remove('show');
      progressBar.style.width = '0%';
      uploadStatus.textContent = 'Uploading ' + files.length + ' file(s)...';
      
      const xhr = new XMLHttpRequest();
      
      xhr.upload.addEventListener('progress', (e) => {
        if (e.lengthComputable) {
          const percent = Math.round((e.loaded / e.total) * 100);
          progressBar.style.width = percent + '%';
          uploadStatus.textContent = 'Uploading... ' + percent + '%';
        }
      });
      
      xhr.addEventListener('load', () => {
        if (xhr.status === 200) {
          uploadProgress.classList.remove('active');
          uploadSuccess.classList.add('show');
          fileInput.value = '';
          setTimeout(() => uploadSuccess.classList.remove('show'), 3000);
        } else {
          uploadStatus.textContent = 'Upload failed. Please try again.';
        }
      });
      
      xhr.addEventListener('error', () => {
        uploadStatus.textContent = 'Upload failed. Please try again.';
      });
      
      xhr.open('POST', '/upload');
      xhr.send(formData);
    }
    
    function filterFiles() {
      const query = document.getElementById('searchInput').value.toLowerCase();
      const cards = document.querySelectorAll('.file-card');
      cards.forEach(card => {
        const name = card.querySelector('.file-name').textContent.toLowerCase();
        card.style.display = name.includes(query) ? 'block' : 'none';
      });
    }
  </script>
</body>
</html>
''';
  }
  
  String _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf': return '📕';
      case 'doc': case 'docx': return '📘';
      case 'xls': case 'xlsx': return '📗';
      case 'ppt': case 'pptx': return '📙';
      case 'txt': case 'md': return '📝';
      case 'zip': case 'rar': case '7z': return '🗜️';
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': case 'svg': return '🖼️';
      case 'mp4': case 'mkv': case 'avi': case 'mov': case 'webm': return '🎬';
      case 'mp3': case 'wav': case 'flac': case 'aac': case 'ogg': return '🎵';
      case 'exe': case 'msi': return '⚙️';
      case 'html': case 'css': case 'js': case 'ts': case 'dart': case 'py': case 'java': return '💻';
      case 'json': case 'xml': case 'yaml': case 'yml': return '📋';
      default: return '📄';
    }
  }
  
  String _getFileColor(String ext) {
    switch (ext) {
      case 'pdf': return 'rgba(239, 68, 68, 0.15)';
      case 'doc': case 'docx': return 'rgba(59, 130, 246, 0.15)';
      case 'xls': case 'xlsx': return 'rgba(34, 197, 94, 0.15)';
      case 'ppt': case 'pptx': return 'rgba(249, 115, 22, 0.15)';
      case 'zip': case 'rar': case '7z': return 'rgba(168, 85, 247, 0.15)';
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'webp': case 'svg': return 'rgba(236, 72, 153, 0.15)';
      case 'mp4': case 'mkv': case 'avi': case 'mov': case 'webm': return 'rgba(139, 92, 246, 0.15)';
      case 'mp3': case 'wav': case 'flac': case 'aac': case 'ogg': return 'rgba(20, 184, 166, 0.15)';
      case 'exe': case 'msi': return 'rgba(107, 114, 128, 0.15)';
      case 'html': case 'css': case 'js': case 'ts': case 'dart': case 'py': case 'java': return 'rgba(99, 102, 241, 0.15)';
      default: return 'rgba(99, 102, 241, 0.1)';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
