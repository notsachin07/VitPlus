import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/vtop_models.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Directory _configDir;
  late File _configFile;
  late File _credentialsFile;
  late File _vtopCredentialsFile;
  late File _vtopDataFile;
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
    _vtopCredentialsFile = File('${_configDir.path}/vtop_credentials.dat');
    _vtopDataFile = File('${_configDir.path}/vtop_data.json');

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

  // ==================== VTOP Credentials ====================

  Future<void> saveVtopCredentials(String username, String password) async {
    await init();
    final data = jsonEncode({'username': username, 'password': password});
    final encoded = base64Encode(utf8.encode(data));
    await _vtopCredentialsFile.writeAsString(encoded);
  }

  Future<Map<String, String>?> getVtopCredentials() async {
    await init();
    if (!await _vtopCredentialsFile.exists()) return null;
    
    try {
      final encoded = await _vtopCredentialsFile.readAsString();
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

  Future<void> clearVtopCredentials() async {
    await init();
    if (await _vtopCredentialsFile.exists()) {
      await _vtopCredentialsFile.delete();
    }
  }

  // ==================== VTOP Session (Cookie) Storage ====================

  Future<void> saveVtopSession({
    required String cookie,
    String? csrfToken,
    String? authorizedId,
  }) async {
    await init();
    final data = await getVtopData() ?? {};
    data['session'] = {
      'cookie': cookie,
      'csrfToken': csrfToken,
      'authorizedId': authorizedId,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await _vtopDataFile.writeAsString(jsonEncode(data));
  }

  Future<Map<String, String?>?> getVtopSession() async {
    await init();
    final data = await getVtopData();
    if (data == null || data['session'] == null) return null;
    
    final session = data['session'] as Map<String, dynamic>;
    
    // Check if session is still valid (within 30 minutes)
    final savedAt = DateTime.tryParse(session['savedAt'] ?? '');
    if (savedAt != null) {
      final age = DateTime.now().difference(savedAt);
      if (age.inMinutes > 30) {
        // Session expired
        return null;
      }
    }
    
    return {
      'cookie': session['cookie'] as String?,
      'csrfToken': session['csrfToken'] as String?,
      'authorizedId': session['authorizedId'] as String?,
    };
  }

  Future<void> clearVtopSession() async {
    await init();
    final data = await getVtopData();
    if (data != null) {
      data.remove('session');
      await _vtopDataFile.writeAsString(jsonEncode(data));
    }
  }

  // ==================== VTOP Data Storage ====================

  Future<void> saveVtopData({
    List<Semester>? semesters,
    String? selectedSemesterId,
    TimetableData? timetable,
    AttendanceData? attendance,
    MarksData? marks,
    ExamScheduleData? examSchedule,
  }) async {
    await init();
    
    Map<String, dynamic> existingData = {};
    if (await _vtopDataFile.exists()) {
      try {
        final content = await _vtopDataFile.readAsString();
        existingData = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {}
    }
    
    if (semesters != null) {
      existingData['semesters'] = semesters.map((s) => s.toMap()).toList();
    }
    if (selectedSemesterId != null) {
      existingData['selectedSemesterId'] = selectedSemesterId;
    }
    if (timetable != null) {
      existingData['timetable'] = timetable.toMap();
    }
    if (attendance != null) {
      existingData['attendance'] = attendance.toMap();
    }
    if (marks != null) {
      existingData['marks'] = marks.toMap();
    }
    if (examSchedule != null) {
      existingData['examSchedule'] = examSchedule.toMap();
    }
    
    await _vtopDataFile.writeAsString(jsonEncode(existingData));
  }

  Future<Map<String, dynamic>?> getVtopData() async {
    await init();
    if (!await _vtopDataFile.exists()) return null;
    
    try {
      final content = await _vtopDataFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<List<Semester>> getSavedSemesters() async {
    final data = await getVtopData();
    if (data == null || data['semesters'] == null) return [];
    
    return (data['semesters'] as List)
        .map((s) => Semester.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  Future<String?> getSelectedSemesterId() async {
    final data = await getVtopData();
    return data?['selectedSemesterId'] as String?;
  }

  Future<TimetableData?> getSavedTimetable() async {
    final data = await getVtopData();
    if (data == null || data['timetable'] == null) return null;
    
    return TimetableData.fromMap(data['timetable'] as Map<String, dynamic>);
  }

  Future<AttendanceData?> getSavedAttendance() async {
    final data = await getVtopData();
    if (data == null || data['attendance'] == null) return null;
    
    return AttendanceData.fromMap(data['attendance'] as Map<String, dynamic>);
  }

  Future<MarksData?> getSavedMarks() async {
    final data = await getVtopData();
    if (data == null || data['marks'] == null) return null;
    
    return MarksData.fromMap(data['marks'] as Map<String, dynamic>);
  }

  Future<ExamScheduleData?> getSavedExamSchedule() async {
    final data = await getVtopData();
    if (data == null || data['examSchedule'] == null) return null;
    
    return ExamScheduleData.fromMap(data['examSchedule'] as Map<String, dynamic>);
  }

  Future<void> clearVtopData() async {
    await init();
    if (await _vtopDataFile.exists()) {
      await _vtopDataFile.delete();
    }
  }

  String get configPath => _configDir.path;
}
