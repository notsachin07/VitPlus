import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/vtop_models.dart';

/// VTOP Service - Handles all VTOP API interactions
/// Based on the login flow from vitap-mate reference
class VtopService {
  static const String baseUrl = 'https://vtop.vitap.ac.in';
  static const String captchaSolverUrl = 'https://cap.va.synaptic.gg/captcha';
  
  String? _cookie;
  String? _csrfToken;
  String? _authorizedId;
  bool _isAuthenticated = false;
  String? _currentPage; // Store current page HTML for parsing
  String? _captchaData;
  
  late final http.Client _client;
  
  VtopService() {
    // Create an HttpClient that accepts bad certificates (for VTOP's SSL)
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Only accept bad certificates for VTOP domain
        return host.contains('vtop.vitap.ac.in');
      };
    _client = IOClient(httpClient);
  }
  
  bool get isAuthenticated => _isAuthenticated;
  String? get authorizedId => _authorizedId;
  String? get cookie => _cookie;
  String? get csrfToken => _csrfToken;
  
  /// Set cookie from storage (for auto-login)
  void setCookie(String cookie) {
    _cookie = cookie;
  }
  
  /// Set session data from storage
  void setSession({String? cookie, String? csrfToken, String? authorizedId, bool authenticated = false}) {
    if (cookie != null) _cookie = cookie;
    if (csrfToken != null) _csrfToken = csrfToken;
    if (authorizedId != null) _authorizedId = authorizedId;
    _isAuthenticated = authenticated;
  }
  
  /// Get proper headers for VTOP requests - matching the reference implementation
  Map<String, String> _getVtopHeaders({String? contentType}) {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; U; Linux x86_64; en-US) Gecko/20100101 Firefox/130.5',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-User': '?1',
      'Priority': 'u=0, i',
    };
    if (_cookie != null) {
      headers['Cookie'] = _cookie!;
    }
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    return headers;
  }
  
  /// Login to VTOP - following the exact flow from vitap-mate
  Future<VtopLoginResult> login(String username, String password) async {
    try {
      _isAuthenticated = false;
      _cookie = null;
      _csrfToken = null;
      _authorizedId = null;
      _currentPage = null;
      _captchaData = null;
      
      // Maximum captcha retry attempts (matching reference: MAX_CAP_TRY = 40)
      const maxAttempts = 40;
      
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        // Load login page - on first attempt load initial page, then just reload captcha
        final pageResult = await _loadLoginPage(loadInitial: attempt == 0);
        if (!pageResult.success) {
          if (attempt < maxAttempts - 1) continue;
          return VtopLoginResult(success: false, message: pageResult.message ?? 'Failed to load login page');
        }
        
        // Get captcha data
        if (_captchaData == null || _captchaData!.isEmpty) {
          if (attempt < maxAttempts - 1) continue;
          return VtopLoginResult(success: false, message: 'Captcha not found');
        }
        
        // Solve captcha
        final captchaSolution = await _solveCaptcha(_captchaData!);
        if (captchaSolution == null) {
          continue; // Try again with new captcha
        }
        
        // Perform login
        final loginResult = await _performLogin(username, password, captchaSolution);
        if (loginResult.success) {
          _isAuthenticated = true;
          return loginResult;
        }
        
        // If invalid captcha, retry
        if (loginResult.message.contains('Invalid Captcha')) {
          continue;
        }
        
        // Other errors - return immediately
        return loginResult;
      }
      
      return VtopLoginResult(success: false, message: 'Failed after $maxAttempts attempts');
    } catch (e) {
      return VtopLoginResult(success: false, message: 'Login error: $e');
    }
  }
  
  /// Load initial VTOP page at /vtop/open/page - matching reference implementation
  Future<_PageResult> _loadInitialPage() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/vtop/open/page'),
        headers: _getVtopHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        return _PageResult(success: false, message: 'Server error: ${response.statusCode}');
      }
      
      // Extract cookies
      _updateCookie(response.headers['set-cookie']);
      
      // Store current page
      _currentPage = response.body;
      
      // Extract CSRF token
      if (!_extractCsrfFromCurrentPage()) {
        return _PageResult(success: false, message: 'CSRF token not found in initial page');
      }
      
      return _PageResult(success: true);
    } catch (e) {
      return _PageResult(success: false, message: 'Network error: $e');
    }
  }
  
  /// Load login page with captcha - POST to /vtop/prelogin/setup
  /// Following the exact flow: POST body = "_csrf={csrf}&flag=VTOP"
  Future<_PageResult> _loadLoginPage({bool loadInitial = true}) async {
    try {
      // Step 1: Load initial page if needed
      if (loadInitial) {
        final initialResult = await _loadInitialPage();
        if (!initialResult.success) {
          return initialResult;
        }
      }
      
      if (_csrfToken == null) {
        return _PageResult(success: false, message: 'No CSRF token available');
      }
      
      // Step 2: POST to /vtop/prelogin/setup with csrf and flag
      // Retry up to 20 times until we get a captcha (matching reference: Max_RELOAD_ATTEMPTS = 20)
      const maxReloadAttempts = 20;
      
      for (int i = 0; i < maxReloadAttempts; i++) {
        final response = await _client.post(
          Uri.parse('$baseUrl/vtop/prelogin/setup'),
          headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
          body: '_csrf=$_csrfToken&flag=VTOP',
        ).timeout(const Duration(seconds: 30));
        
        _updateCookie(response.headers['set-cookie']);
        
        if (response.statusCode != 200) {
          return _PageResult(success: false, message: 'Server error: ${response.statusCode}');
        }
        
        // Check if response contains base64 captcha image
        if (response.body.contains('base64,')) {
          _currentPage = response.body;
          
          // Extract captcha data
          if (_extractCaptchaFromCurrentPage()) {
            return _PageResult(success: true, captchaData: _captchaData);
          }
        }
        
        // No captcha found, retry
        print('VtopService: No captcha found, reloading page (attempt ${i + 1}/$maxReloadAttempts)');
      }
      
      return _PageResult(success: false, message: 'Captcha not found after $maxReloadAttempts attempts');
    } catch (e) {
      return _PageResult(success: false, message: 'Network error: $e');
    }
  }
  
  /// Extract CSRF token from current page HTML
  bool _extractCsrfFromCurrentPage() {
    if (_currentPage == null) return false;
    
    // Match input[name='_csrf'] - matching reference selector
    final patterns = [
      RegExp(r'''<input[^>]+name=["']_csrf["'][^>]+value=["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''<input[^>]+value=["']([^"']+)["'][^>]+name=["']_csrf["']''', caseSensitive: false),
      RegExp(r'name="_csrf"\s+content="([^"]+)"'),
      RegExp(r'''name=["']_csrf["'][^>]*value=["']([^"']+)["']'''),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(_currentPage!);
      if (match != null) {
        _csrfToken = match.group(1);
        return true;
      }
    }
    
    return false;
  }
  
  /// Extract captcha data from current page HTML
  /// Looking for img.form-control.img-fluid.bg-light.border-0 with base64 src
  bool _extractCaptchaFromCurrentPage() {
    if (_currentPage == null) return false;
    
    // Match the captcha img tag - class="form-control img-fluid bg-light border-0"
    // Or simply any img with base64 data
    final patterns = [
      RegExp(r'<img[^>]+class="[^"]*form-control[^"]*"[^>]+src="(data:image[^"]+)"'),
      RegExp(r'<img[^>]+src="(data:image/[^;]+;base64,[^"]+)"[^>]*class="[^"]*form-control'),
      RegExp(r'src="(data:image/[^;]+;base64,[^"]+)"'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(_currentPage!);
      if (match != null) {
        final src = match.group(1);
        if (src != null && src.contains('base64,')) {
          _captchaData = src;
          return true;
        }
      }
    }
    
    return false;
  }
  
  /// Solve captcha using external service
  /// Matching reference: POST to https://cap.va.synaptic.gg/captcha with {imgstring: base64url_encoded}
  Future<String?> _solveCaptcha(String captchaData) async {
    try {
      // The reference implementation encodes the entire captcha data URL (including data:image prefix)
      // using URL-safe base64
      final urlSafeEncoded = base64Url.encode(utf8.encode(captchaData));
      
      // Use regular http client for captcha solver (no SSL issues)
      final response = await http.post(
        Uri.parse(captchaSolverUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'imgstring': urlSafeEncoded}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = response.body.trim();
        if (result.isNotEmpty) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('VtopService: Captcha solve error: $e');
      return null;
    }
  }
  
  /// Perform the actual login - POST to /vtop/login
  Future<VtopLoginResult> _performLogin(String username, String password, String captcha) async {
    try {
      if (_csrfToken == null) {
        return VtopLoginResult(success: false, message: 'No CSRF token');
      }
      
      // URL encode username and password
      final encodedUsername = Uri.encodeComponent(username);
      final encodedPassword = Uri.encodeComponent(password);
      
      final response = await _client.post(
        Uri.parse('$baseUrl/vtop/login'),
        headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
        body: '_csrf=$_csrfToken&username=$encodedUsername&password=$encodedPassword&captchaStr=$captcha',
      ).timeout(const Duration(seconds: 30));
      
      _updateCookie(response.headers['set-cookie']);
      
      final responseUrl = response.request?.url.toString() ?? '';
      final responseBody = response.body;
      
      // Check for error in URL or response
      if (responseUrl.contains('error') || responseBody.contains('text-danger')) {
        if (responseBody.contains('Invalid Captcha')) {
          return VtopLoginResult(success: false, message: 'Invalid Captcha');
        }
        if (responseBody.contains('Invalid LoginId/Password') ||
            responseBody.contains('Invalid  Username/Password') ||
            responseBody.contains('Invalid Username/Password')) {
          return VtopLoginResult(success: false, message: 'Invalid credentials');
        }
        return VtopLoginResult(success: false, message: 'Login failed');
      }
      
      // Success - extract new CSRF and authorized ID
      _currentPage = responseBody;
      _extractCsrfFromCurrentPage();
      
      // Extract authorized ID (registration number) from authorizedIDX hidden input
      _authorizedId = _extractAuthorizedId(responseBody) ?? username;
      _isAuthenticated = true;
      _currentPage = null;
      _captchaData = null;
      
      return VtopLoginResult(success: true, message: 'Login successful');
    } catch (e) {
      return VtopLoginResult(success: false, message: 'Login error: $e');
    }
  }
  
  /// Fetch available semesters - matching reference: StudentTimeTable endpoint
  Future<List<Semester>> fetchSemesters() async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/vtop/academics/common/StudentTimeTable'),
        headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
        body: 'verifyMenu=true&authorizedID=$_authorizedId&_csrf=$_csrfToken&nocache=${DateTime.now().millisecondsSinceEpoch}',
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        throw Exception('Session expired');
      }
      
      return _parseSemesters(response.body);
    } catch (e) {
      throw Exception('Error fetching semesters: $e');
    }
  }
  
  /// Fetch timetable for a semester
  Future<TimetableData> fetchTimetable(String semesterId) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/vtop/processViewTimeTable'),
        headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
        body: '_csrf=$_csrfToken&semesterSubId=$semesterId&authorizedID=$_authorizedId',
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        throw Exception('Session expired');
      }
      
      final slots = _parseTimetable(response.body);
      return TimetableData(
        semesterId: semesterId,
        slots: slots,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error fetching timetable: $e');
    }
  }
  
  /// Fetch attendance for a semester
  Future<AttendanceData> fetchAttendance(String semesterId) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/vtop/processViewStudentAttendance'),
        headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
        body: '_csrf=$_csrfToken&semesterSubId=$semesterId&authorizedID=$_authorizedId',
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        throw Exception('Session expired');
      }
      
      final courses = _parseAttendance(response.body);
      return AttendanceData(
        semesterId: semesterId,
        courses: courses,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error fetching attendance: $e');
    }
  }
  
  /// Fetch marks for a semester
  Future<MarksData> fetchMarks(String semesterId) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/vtop/examinations/doStudentMarkView'),
        headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
        body: '_csrf=$_csrfToken&semesterSubId=$semesterId&authorizedID=$_authorizedId',
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        throw Exception('Session expired');
      }
      
      final courses = _parseMarks(response.body);
      return MarksData(
        semesterId: semesterId,
        courses: courses,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error fetching marks: $e');
    }
  }
  
  /// Fetch exam schedule for a semester
  Future<ExamScheduleData> fetchExamSchedule(String semesterId) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/vtop/examinations/doSearchExamScheduleForStudent'),
        headers: _getVtopHeaders(contentType: 'application/x-www-form-urlencoded'),
        body: '_csrf=$_csrfToken&semesterSubId=$semesterId&authorizedID=$_authorizedId',
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        throw Exception('Session expired');
      }
      
      final exams = _parseExamSchedule(response.body);
      return ExamScheduleData(
        semesterId: semesterId,
        exams: exams,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error fetching exam schedule: $e');
    }
  }
  
  /// Logout from VTOP
  void logout() {
    _cookie = null;
    _csrfToken = null;
    _authorizedId = null;
    _isAuthenticated = false;
    _currentPage = null;
    _captchaData = null;
  }
  
  // ==================== Helper Methods ====================
  
  void _updateCookie(String? setCookie) {
    if (setCookie == null) return;
    
    // Parse and accumulate cookies
    final cookies = setCookie.split(',').map((c) {
      final parts = c.split(';');
      return parts.isNotEmpty ? parts[0].trim() : '';
    }).where((c) => c.isNotEmpty).toList();
    
    if (_cookie == null) {
      _cookie = cookies.join('; ');
    } else {
      // Merge cookies - update existing or add new
      final existingMap = <String, String>{};
      for (final c in _cookie!.split('; ')) {
        final parts = c.split('=');
        if (parts.length >= 2) {
          existingMap[parts[0]] = parts.sublist(1).join('=');
        }
      }
      for (final c in cookies) {
        final parts = c.split('=');
        if (parts.length >= 2) {
          existingMap[parts[0]] = parts.sublist(1).join('=');
        }
      }
      _cookie = existingMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
  }
  
  String? _extractAuthorizedId(String html) {
    // Match input[type=hidden][name=authorizedIDX] - matching reference
    final patterns = [
      RegExp(r'''<input[^>]+name=["']authorizedIDX["'][^>]+value=["']([^"']+)["']'''),
      RegExp(r'''<input[^>]+value=["']([^"']+)["'][^>]+name=["']authorizedIDX["']'''),
      RegExp(r'name="authorizedIDX"\s+value="([^"]+)"'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }
  
  // ==================== Parsing Methods ====================
  
  List<Semester> _parseSemesters(String html) {
    final semesters = <Semester>[];
    
    // Parse option tags for semester dropdown
    final pattern = RegExp(r'<option\s+value="([^"]+)"[^>]*>([^<]+)</option>');
    final matches = pattern.allMatches(html);
    
    for (final match in matches) {
      final id = match.group(1)?.trim() ?? '';
      final name = match.group(2)?.trim() ?? '';
      if (id.isNotEmpty && name.isNotEmpty && id != '0') {
        semesters.add(Semester(id: id, name: name));
      }
    }
    
    return semesters;
  }
  
  List<TimetableSlot> _parseTimetable(String html) {
    final slots = <TimetableSlot>[];
    
    // Parse timetable table rows
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    final rows = rowPattern.allMatches(html);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    int dayIndex = 0;
    for (final row in rows) {
      final cells = cellPattern.allMatches(row.group(1) ?? '').toList();
      if (cells.isEmpty) continue;
      
      // Check if first cell is a day
      final firstCell = _stripHtml(cells[0].group(1) ?? '');
      final dayMatch = days.indexWhere((d) => firstCell.contains(d));
      if (dayMatch >= 0) {
        dayIndex = dayMatch;
      }
      
      // Parse slot information from cells
      for (final cell in cells) {
        final content = cell.group(1) ?? '';
        if (content.contains('courseName') || content.contains('slot')) {
          final slotInfo = _parseSlotCell(content, days[dayIndex % days.length]);
          if (slotInfo != null) {
            slots.add(slotInfo);
          }
        }
      }
    }
    
    return slots;
  }
  
  TimetableSlot? _parseSlotCell(String cell, String day) {
    // Extract course info from cell HTML
    final codePattern = RegExp(r'([A-Z]{3}\d{3,4})');
    final codeMatch = codePattern.firstMatch(cell);
    
    if (codeMatch == null) return null;
    
    final text = _stripHtml(cell);
    final lines = text.split(RegExp(r'\s{2,}|\n')).where((l) => l.trim().isNotEmpty).toList();
    
    return TimetableSlot(
      day: day,
      startTime: '',
      endTime: '',
      courseCode: codeMatch.group(1) ?? '',
      courseName: lines.length > 1 ? lines[1] : '',
      venue: lines.length > 2 ? lines[2] : '',
      faculty: lines.length > 3 ? lines[3] : '',
      slotName: lines.isNotEmpty ? lines[0] : '',
    );
  }
  
  List<AttendanceCourse> _parseAttendance(String html) {
    final courses = <AttendanceCourse>[];
    
    // Parse attendance table
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    final rows = rowPattern.allMatches(html).toList();
    
    for (final row in rows) {
      final cells = cellPattern.allMatches(row.group(1) ?? '').toList();
      if (cells.length < 8) continue;
      
      final courseCode = _stripHtml(cells[1].group(1) ?? '').trim();
      if (courseCode.isEmpty || !RegExp(r'[A-Z]{3}\d{3,4}').hasMatch(courseCode)) continue;
      
      try {
        final totalStr = _stripHtml(cells[5].group(1) ?? '').trim();
        final attendedStr = _stripHtml(cells[6].group(1) ?? '').trim();
        final percentStr = _stripHtml(cells[7].group(1) ?? '').trim();
        
        final total = int.tryParse(totalStr) ?? 0;
        final attended = int.tryParse(attendedStr) ?? 0;
        final percent = double.tryParse(percentStr.replaceAll('%', '')) ?? 0.0;
        
        courses.add(AttendanceCourse(
          courseCode: courseCode,
          courseName: _stripHtml(cells[2].group(1) ?? '').trim(),
          courseType: _stripHtml(cells[3].group(1) ?? '').trim(),
          faculty: _stripHtml(cells[4].group(1) ?? '').trim(),
          slot: '',
          totalClasses: total,
          attendedClasses: attended,
          absentClasses: total - attended,
          percentage: percent,
        ));
      } catch (_) {
        continue;
      }
    }
    
    return courses;
  }
  
  List<CourseMarks> _parseMarks(String html) {
    final courses = <CourseMarks>[];
    
    // Parse marks tables
    final tablePattern = RegExp(r'<table[^>]*class="[^"]*table[^"]*"[^>]*>(.*?)</table>', dotAll: true);
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    final tables = tablePattern.allMatches(html);
    
    for (final table in tables) {
      final rows = rowPattern.allMatches(table.group(1) ?? '').toList();
      if (rows.length < 2) continue;
      
      String? currentCourse;
      String? currentCourseName;
      String? currentCourseType;
      List<MarkComponent> components = [];
      
      for (final row in rows) {
        final cells = cellPattern.allMatches(row.group(1) ?? '').toList();
        if (cells.isEmpty) continue;
        
        final firstCell = _stripHtml(cells[0].group(1) ?? '').trim();
        
        // Check if this is a course header row
        if (RegExp(r'[A-Z]{3}\d{3,4}').hasMatch(firstCell)) {
          // Save previous course if exists
          if (currentCourse != null && components.isNotEmpty) {
            courses.add(CourseMarks(
              courseCode: currentCourse,
              courseName: currentCourseName ?? '',
              courseType: currentCourseType ?? '',
              components: components,
              totalWeightedScore: components.fold(0.0, (sum, c) => sum + c.weightedScore),
            ));
          }
          
          currentCourse = firstCell;
          currentCourseName = cells.length > 1 ? _stripHtml(cells[1].group(1) ?? '').trim() : '';
          currentCourseType = cells.length > 2 ? _stripHtml(cells[2].group(1) ?? '').trim() : '';
          components = [];
        } else if (currentCourse != null && cells.length >= 4) {
          // This is a component row
          try {
            final name = firstCell;
            final maxMarks = double.tryParse(_stripHtml(cells[1].group(1) ?? '').trim()) ?? 0.0;
            final scored = double.tryParse(_stripHtml(cells[2].group(1) ?? '').trim()) ?? 0.0;
            final weightage = cells.length > 3 
                ? (double.tryParse(_stripHtml(cells[3].group(1) ?? '').trim()) ?? 0.0) 
                : 0.0;
            final weighted = cells.length > 4 
                ? (double.tryParse(_stripHtml(cells[4].group(1) ?? '').trim()) ?? 0.0) 
                : (maxMarks > 0 ? (scored / maxMarks) * weightage : 0.0);
            
            if (name.isNotEmpty) {
              components.add(MarkComponent(
                name: name,
                maxMarks: maxMarks,
                scoredMarks: scored,
                weightage: weightage,
                weightedScore: weighted,
              ));
            }
          } catch (_) {
            continue;
          }
        }
      }
      
      // Add last course
      if (currentCourse != null && components.isNotEmpty) {
        courses.add(CourseMarks(
          courseCode: currentCourse,
          courseName: currentCourseName ?? '',
          courseType: currentCourseType ?? '',
          components: components,
          totalWeightedScore: components.fold(0.0, (sum, c) => sum + c.weightedScore),
        ));
      }
    }
    
    return courses;
  }
  
  List<ExamSlot> _parseExamSchedule(String html) {
    final exams = <ExamSlot>[];
    
    // Parse exam schedule table
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    final rows = rowPattern.allMatches(html).toList();
    
    for (final row in rows) {
      final cells = cellPattern.allMatches(row.group(1) ?? '').toList();
      if (cells.length < 6) continue;
      
      final courseCode = _stripHtml(cells[0].group(1) ?? '').trim();
      if (!RegExp(r'[A-Z]{3}\d{3,4}').hasMatch(courseCode)) continue;
      
      exams.add(ExamSlot(
        courseCode: courseCode,
        courseName: _stripHtml(cells[1].group(1) ?? '').trim(),
        examType: _stripHtml(cells[2].group(1) ?? '').trim(),
        date: _stripHtml(cells[3].group(1) ?? '').trim(),
        time: _stripHtml(cells[4].group(1) ?? '').trim(),
        venue: cells.length > 5 ? _stripHtml(cells[5].group(1) ?? '').trim() : '',
        seatNo: cells.length > 6 ? _stripHtml(cells[6].group(1) ?? '').trim() : '',
      ));
    }
    
    return exams;
  }
  
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

class VtopLoginResult {
  final bool success;
  final String message;
  
  VtopLoginResult({required this.success, this.message = ''});
}

class _PageResult {
  final bool success;
  final String? message;
  final String? captchaData;
  
  _PageResult({required this.success, this.message, this.captchaData});
}
