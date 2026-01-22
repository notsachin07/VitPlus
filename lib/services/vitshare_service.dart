import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

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

  bool get isRunning => _isRunning;
  int get port => _port;
  String get password => _password;
  List<String> get sharedPaths => List.unmodifiable(_sharedPaths);
  Map<String, ActiveDownload> get activeDownloads => Map.unmodifiable(_activeDownloads);
  Stream<Map<String, ActiveDownload>> get downloadStream => _downloadController.stream;

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
    } else if (path.startsWith('/download/')) {
      await _handleDownload(request);
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

    request.response.headers.contentType = ContentType.html;
    request.response.write(_indexPage(files));
    await request.response.close();
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

  String _generateSessionId() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }

  String _loginPage(bool showError) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VitShare - Login</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0D1117 0%, #161B22 100%);
      color: #E6EDF3;
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .container {
      background: #21262D;
      padding: 2.5rem;
      border-radius: 12px;
      border: 1px solid #30363D;
      width: 100%;
      max-width: 400px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.3);
    }
    h1 { text-align: center; margin-bottom: 0.5rem; font-size: 1.8rem; }
    .subtitle { text-align: center; color: #8B949E; margin-bottom: 2rem; }
    .error { background: #f8514926; color: #f85149; padding: 0.75rem; border-radius: 6px; margin-bottom: 1rem; text-align: center; }
    label { display: block; margin-bottom: 0.5rem; font-weight: 500; }
    input {
      width: 100%;
      padding: 0.75rem;
      border: 1px solid #30363D;
      border-radius: 6px;
      background: #0D1117;
      color: #E6EDF3;
      font-size: 1rem;
      margin-bottom: 1.5rem;
    }
    input:focus { outline: none; border-color: #0066CC; }
    button {
      width: 100%;
      padding: 0.875rem;
      background: #0066CC;
      color: white;
      border: none;
      border-radius: 6px;
      font-size: 1rem;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.2s;
    }
    button:hover { background: #0052a3; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🔐 VitShare</h1>
    <p class="subtitle">Enter password to access shared files</p>
    ${showError ? '<div class="error">❌ Incorrect password</div>' : ''}
    <form method="POST">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" required autofocus>
      <button type="submit">Login</button>
    </form>
  </div>
</body>
</html>
''';
  }

  String _indexPage(List<Map<String, dynamic>> files) {
    final fileItems = files.map((f) {
      final encodedPath = Uri.encodeComponent(f['path']);
      final size = _formatBytes(f['size']);
      return '''<li>
        <a href="/download/$encodedPath">
          <span class="icon">📄</span>
          <span class="name">${f['name']}</span>
          <span class="size">$size</span>
        </a>
      </li>''';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VitShare - Files</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #0D1117 0%, #161B22 100%);
      color: #E6EDF3;
      min-height: 100vh;
      padding: 2rem;
    }
    .container { max-width: 900px; margin: 0 auto; }
    header { text-align: center; margin-bottom: 2rem; }
    h1 { font-size: 2rem; margin-bottom: 0.5rem; }
    .subtitle { color: #8B949E; }
    .files {
      background: #21262D;
      border-radius: 12px;
      border: 1px solid #30363D;
      overflow: hidden;
    }
    ul { list-style: none; }
    li { border-bottom: 1px solid #30363D; }
    li:last-child { border-bottom: none; }
    a {
      display: flex;
      align-items: center;
      padding: 1rem 1.25rem;
      color: #E6EDF3;
      text-decoration: none;
      transition: background 0.2s;
    }
    a:hover { background: #30363D; }
    .icon { font-size: 1.25rem; margin-right: 0.75rem; }
    .name { flex: 1; word-break: break-all; }
    .size { color: #8B949E; font-size: 0.875rem; margin-left: 1rem; }
    .empty { padding: 3rem; text-align: center; color: #8B949E; }
    .logout { text-align: center; margin-top: 2rem; }
    .logout a {
      display: inline-block;
      padding: 0.75rem 1.5rem;
      background: #21262D;
      border: 1px solid #30363D;
      border-radius: 6px;
      color: #E6EDF3;
      text-decoration: none;
    }
    .logout a:hover { background: #30363D; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📁 VitShare</h1>
      <p class="subtitle">Shared files on this network</p>
    </header>
    <div class="files">
      ${files.isEmpty ? '<div class="empty">No files shared yet</div>' : '<ul>$fileItems</ul>'}
    </div>
    <div class="logout">
      <a href="/logout">Logout</a>
    </div>
  </div>
</body>
</html>
''';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
