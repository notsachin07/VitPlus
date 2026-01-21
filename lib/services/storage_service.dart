import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Directory _configDir;
  late File _configFile;
  late File _credentialsFile;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final appData = await getApplicationSupportDirectory();
    _configDir = Directory('${appData.path}/VitPlus');
    
    if (!await _configDir.exists()) {
      await _configDir.create(recursive: true);
    }

    _configFile = File('${_configDir.path}/config.json');
    _credentialsFile = File('${_configDir.path}/credentials.dat');

    if (!await _configFile.exists()) {
      await _configFile.writeAsString(jsonEncode(_defaultConfig));
    }

    _initialized = true;
  }

  Map<String, dynamic> get _defaultConfig => {
    'dark_mode': true,
    'auto_connect': false,
    'auto_start': false,
    'minimize_to_tray': true,
    'campus_endpoint': 'https://172.18.10.10:1000',
    'hostel_endpoint': 'https://hfw.vitap.ac.in:8090/login.xml',
    'preferred_network': 'auto',
    'vitshare_port': 5000,
    'vitshare_password': '',
  };

  Future<Map<String, dynamic>> getSettings() async {
    await init();
    try {
      final content = await _configFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      for (final key in _defaultConfig.keys) {
        if (!data.containsKey(key)) {
          data[key] = _defaultConfig[key];
        }
      }
      return data;
    } catch (e) {
      return Map<String, dynamic>.from(_defaultConfig);
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await init();
    await _configFile.writeAsString(jsonEncode(settings));
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final settings = await getSettings();
    settings[key] = value;
    await saveSettings(settings);
  }

  Future<void> saveCredentials(String username, String password) async {
    await init();
    final data = jsonEncode({'username': username, 'password': password});
    final encoded = base64Encode(utf8.encode(data));
    await _credentialsFile.writeAsString(encoded);
  }

  Future<Map<String, String>?> getCredentials() async {
    await init();
    if (!await _credentialsFile.exists()) return null;
    
    try {
      final encoded = await _credentialsFile.readAsString();
      final decoded = utf8.decode(base64Decode(encoded));
      final data = jsonDecode(decoded);
      return {
        'username': data['username'] ?? '',
        'password': data['password'] ?? '',
      };
    } catch (e) {
      return null;
    }
  }

  Future<void> clearCredentials() async {
    await init();
    if (await _credentialsFile.exists()) {
      await _credentialsFile.delete();
    }
  }

  String get configPath => _configDir.path;
}
