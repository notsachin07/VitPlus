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
  String? _loginActionUrl; // Store the form action URL for login
  
  late final http.Client _client;
  late final HttpClient _httpClient;
  
  VtopService() {
    // Create an HttpClient that accepts bad certificates (for VTOP's SSL)
    // and follows redirects properly
    _httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Only accept bad certificates for VTOP domain
        return host.contains('vtop.vitap.ac.in');
      }
      ..autoUncompress = true
      ..maxConnectionsPerHost = 5;
    // Don't auto-follow redirects so we can capture cookies from each response
    _httpClient.findProxy = null;
    _client = IOClient(_httpClient);
  }
  
  /// Make a GET request that follows redirects and collects cookies
  Future<_HttpResponse> _doGet(String url) async {
    var currentUrl = url;
    String body = '';
    int statusCode = 0;
    
    for (int redirects = 0; redirects < 10; redirects++) {
      final request = await _httpClient.getUrl(Uri.parse(currentUrl));
      
      // Add headers
      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; U; Linux x86_64; en-US) Gecko/20100101 Firefox/130.5');
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      request.followRedirects = false; // Handle manually to capture cookies
      if (_cookie != null) {
        request.headers.set('Cookie', _cookie!);
      }
      
      final response = await request.close();
      statusCode = response.statusCode;
      
      // Extract cookies
      _extractCookiesFromResponse(response);
      
      // Check for redirect
      if (statusCode == 301 || statusCode == 302 || statusCode == 303 || statusCode == 307 || statusCode == 308) {
        final location = response.headers.value('location');
        if (location != null) {
          // Handle relative URLs
          if (location.startsWith('/')) {
            currentUrl = '$baseUrl$location';
          } else if (!location.startsWith('http')) {
            currentUrl = '$baseUrl/$location';
          } else {
            currentUrl = location;
          }
          // Drain the response body
          await response.drain();
          continue;
        }
      }
      
      // Read body
      body = await response.transform(utf8.decoder).join();
      break;
    }
    
    return _HttpResponse(statusCode: statusCode, body: body);
  }
  
  /// Make a POST request that follows redirects and collects cookies
  Future<_HttpResponse> _doPost(String url, String postBody) async {
    var currentUrl = url;
    String body = '';
    int statusCode = 0;
    bool isPost = true;
    
    for (int redirects = 0; redirects < 10; redirects++) {
      HttpClientRequest request;
      if (isPost) {
        request = await _httpClient.postUrl(Uri.parse(currentUrl));
        request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      } else {
        request = await _httpClient.getUrl(Uri.parse(currentUrl));
      }
      
      // Add headers
      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; U; Linux x86_64; en-US) Gecko/20100101 Firefox/130.5');
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      request.followRedirects = false; // Handle manually to capture cookies
      if (_cookie != null) {
        request.headers.set('Cookie', _cookie!);
      }
      
      if (isPost) {
        request.write(postBody);
      }
      
      final response = await request.close();
      statusCode = response.statusCode;
      
      // Extract cookies
      _extractCookiesFromResponse(response);
      
      // Check for redirect
      if (statusCode == 301 || statusCode == 302 || statusCode == 303 || statusCode == 307 || statusCode == 308) {
        final location = response.headers.value('location');
        if (location != null) {
          // Handle relative URLs
          if (location.startsWith('/')) {
            currentUrl = '$baseUrl$location';
          } else if (!location.startsWith('http')) {
            currentUrl = '$baseUrl/$location';
          } else {
            currentUrl = location;
          }
          // Drain the response body
          await response.drain();
          // After redirect, use GET (except for 307/308)
          if (statusCode == 302 || statusCode == 303) {
            isPost = false;
          }
          continue;
        }
      }
      
      // Read body
      body = await response.transform(utf8.decoder).join();
      break;
    }
    
    return _HttpResponse(statusCode: statusCode, body: body);
  }
  
  void _extractCookiesFromResponse(HttpClientResponse response) {
    // Extract from Set-Cookie header
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      for (final cookieHeader in setCookieHeaders) {
        final cookiePart = cookieHeader.split(';').first.trim();
        if (cookiePart.contains('=')) {
          _updateCookieFromString(cookiePart);
        }
      }
    }
    // Also from response.cookies
    if (response.cookies.isNotEmpty) {
      final cookieStr = response.cookies.map((c) => '${c.name}=${c.value}').join('; ');
      _updateCookieFromString(cookieStr);
    }
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
  
  /// Validate if current session is still active
  /// Based on vitap-mate's fetchIsAuth approach - tries to access a protected page
  Future<bool> validateSession() async {
    if (_cookie == null || _cookie!.isEmpty) return false;
    
    try {
      // Try to access the content page - if we get redirected to login, session is invalid
      final response = await _doGet('$baseUrl/vtop/content');
      
      if (response.statusCode >= 400) return false;
      
      // Check if we got the actual content page or were redirected to login
      final body = response.body.toLowerCase();
      
      // If the page contains login form elements, session is expired
      if (body.contains('id="loginform"') || 
          body.contains('id="loginbutton"') ||
          body.contains('id="captchaimg"') ||
          body.contains('/vtop/prelogin/')) {
        return false;
      }
      
      // If we see dashboard/content elements, session is valid
      if (body.contains('sidebar') ||
          body.contains('dashboard') ||
          body.contains('logout') ||
          body.contains('academics/') ||
          body.contains('studentname')) {
        return true;
      }
      
      // Ambiguous - assume valid if we got 200 OK
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
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
      _loginActionUrl = null;
      
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
      
      return VtopLoginResult(success: false, message: 'Login failed after $maxAttempts captcha attempts. Please try again.');
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('SocketException') || errorMsg.contains('Connection refused')) {
        return VtopLoginResult(success: false, message: 'Network error: Cannot connect to VTOP server');
      } else if (errorMsg.contains('TimeoutException')) {
        return VtopLoginResult(success: false, message: 'Connection timed out. Check your internet connection.');
      } else if (errorMsg.contains('HandshakeException') || errorMsg.contains('certificate')) {
        return VtopLoginResult(success: false, message: 'SSL/Security error. Try again later.');
      }
      return VtopLoginResult(success: false, message: 'Login error: ${e.runtimeType}');
    }
  }
  
  /// Load initial VTOP page at /vtop/open/page - matching reference implementation
  Future<_PageResult> _loadInitialPage() async {
    try {
      // Use our redirect-following GET method
      final response = await _doGet('$baseUrl/vtop/open/page');
      
      // Check for errors
      if (response.statusCode >= 400) {
        return _PageResult(success: false, message: 'Server error: ${response.statusCode}');
      }
      
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
        // Use our redirect-following POST method
        final postBody = '_csrf=$_csrfToken&flag=VTOP';
        final response = await _doPost('$baseUrl/vtop/prelogin/setup', postBody);
        
        if (response.statusCode >= 400) {
          return _PageResult(success: false, message: 'Server error: ${response.statusCode}');
        }
        
        // Check if response contains base64 captcha image
        if (response.body.contains('base64,')) {
          _currentPage = response.body;
          
          // Extract new CSRF token from this page (the form might have a different one)
          _extractCsrfFromCurrentPage();
          
          // Extract form action URL and save it
          _loginActionUrl = _extractFormAction(response.body);
          
          // Extract captcha data
          if (_extractCaptchaFromCurrentPage()) {
            return _PageResult(success: true, captchaData: _captchaData);
          }
        }
      }
      
      return _PageResult(success: false, message: 'Captcha not found after $maxReloadAttempts attempts');
    } catch (e) {
      return _PageResult(success: false, message: 'Network error: $e');
    }
  }
  
  /// Extract form action URL from HTML
  String? _extractFormAction(String html) {
    // Look for form with id="loginForm" or similar, or just any form action
    final patterns = [
      RegExp(r'''<form[^>]+id=["']?login[^"']*["']?[^>]+action=["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''<form[^>]+action=["']([^"']+)["'][^>]+id=["']?login''', caseSensitive: false),
      RegExp(r'''<form[^>]+action=["'](/vtop/[^"']+)["']''', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
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
      return null;
    }
  }
  
  /// Perform the actual login - POST to the login form action URL
  Future<VtopLoginResult> _performLogin(String username, String password, String captcha) async {
    try {
      if (_csrfToken == null) {
        return VtopLoginResult(success: false, message: 'No CSRF token');
      }
      
      // URL encode username and password
      final encodedUsername = Uri.encodeComponent(username);
      final encodedPassword = Uri.encodeComponent(password);
      
      // Determine login URL - use extracted form action or default to /vtop/doLogin
      final loginUrl = _loginActionUrl != null 
          ? (_loginActionUrl!.startsWith('http') ? _loginActionUrl! : '$baseUrl$_loginActionUrl')
          : '$baseUrl/vtop/doLogin';
      
      // Build POST body
      final postBody = '_csrf=$_csrfToken&username=$encodedUsername&password=$encodedPassword&captchaStr=$captcha';
      
      // Use our redirect-following POST method
      final response = await _doPost(loginUrl, postBody);
      
      // First check for success indicators - if we see these, login worked!
      final hasAuthorizedId = response.body.contains('authorizedID') || response.body.contains('authorizedIDX');
      final hasStudentContent = response.body.contains('Student Portal') || 
                                response.body.contains('Welcome') ||
                                response.body.contains('vtop/content') ||
                                response.body.contains('Academics') ||
                                response.body.contains('Time Table');
      
      if (hasAuthorizedId || hasStudentContent) {
        // Success - extract new CSRF and authorized ID
        _currentPage = response.body;
        _extractCsrfFromCurrentPage();
        
        // Extract authorized ID (registration number) from authorizedIDX hidden input
        _authorizedId = _extractAuthorizedId(response.body) ?? username;
        _isAuthenticated = true;
        _currentPage = null;
        _captchaData = null;
        
        return VtopLoginResult(success: true, message: 'Login successful');
      }
      
      // Check for specific error messages
      if (response.body.contains('Invalid Captcha')) {
        return VtopLoginResult(success: false, message: 'Invalid Captcha');
      }
      
      if (response.body.contains('Invalid LoginId/Password') ||
          response.body.contains('Invalid  Username/Password') ||
          response.body.contains('Invalid Username/Password')) {
        return VtopLoginResult(success: false, message: 'Invalid credentials');
      }
      
      // Check if we're still on login page (login didn't work)
      if (response.body.contains('captchaStr') || response.body.contains('captcha')) {
        
        // Try to find any alert/error message
        final alertPattern = RegExp(r'<div[^>]*class="[^"]*alert[^"]*"[^>]*>([^<]+)<', caseSensitive: false);
        final alertMatch = alertPattern.firstMatch(response.body);
        if (alertMatch != null) {
          final alertText = alertMatch.group(1)?.trim() ?? '';
          if (alertText.isNotEmpty) {
            return VtopLoginResult(success: false, message: alertText);
          }
        }
        
        return VtopLoginResult(success: false, message: 'Login failed - captcha may be incorrect');
      }
      
      return VtopLoginResult(success: false, message: 'Login failed - unexpected response');
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
      final body = 'verifyMenu=true&authorizedID=$_authorizedId&_csrf=$_csrfToken&nocache=${DateTime.now().millisecondsSinceEpoch}';
      final response = await _doPost('$baseUrl/vtop/academics/common/StudentTimeTable', body);
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        _isAuthenticated = false;
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
      final body = '_csrf=$_csrfToken&semesterSubId=$semesterId&authorizedID=$_authorizedId';
      final response = await _doPost('$baseUrl/vtop/processViewTimeTable', body);
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        _isAuthenticated = false;
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
      final body = '_csrf=$_csrfToken&semesterSubId=$semesterId&authorizedID=$_authorizedId';
      final response = await _doPost('$baseUrl/vtop/processViewStudentAttendance', body);
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        _isAuthenticated = false;
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
  
  /// Fetch detailed attendance for a specific course
  /// Uses courseId and courseType from the attendance course onclick function
  Future<List<AttendanceDetail>> fetchAttendanceDetail({
    required String semesterId,
    required String courseId,
    required String courseType,
  }) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      // Endpoint from vitap-mate: /vtop/processViewAttendanceDetail
      final body = '_csrf=$_csrfToken'
          '&semesterSubId=$semesterId'
          '&courseId=$courseId'
          '&courseType=$courseType'
          '&authorizedID=$_authorizedId';
      
      final response = await _doPost('$baseUrl/vtop/processViewAttendanceDetail', body);
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        _isAuthenticated = false;
        throw Exception('Session expired');
      }
      
      return _parseAttendanceDetail(response.body);
    } catch (e) {
      throw Exception('Error fetching attendance detail: $e');
    }
  }
  
  /// Fetch marks for a semester - uses multipart form as per reference
  Future<MarksData> fetchMarks(String semesterId) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      // Marks endpoint requires multipart form data
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vtop/examinations/doStudentMarkView'),
      );
      
      // Add headers
      request.headers.addAll({
        'Cookie': _cookie ?? '',
        'User-Agent': 'Mozilla/5.0 (Linux; U; Linux x86_64; en-US) Gecko/20100101 Firefox/130.5',
      });
      
      // Add form fields
      request.fields['authorizedID'] = _authorizedId ?? '';
      request.fields['semesterSubId'] = semesterId;
      request.fields['_csrf'] = _csrfToken ?? '';
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
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
  
  /// Fetch exam schedule for a semester - uses multipart form as per reference
  Future<ExamScheduleData> fetchExamSchedule(String semesterId) async {
    if (!_isAuthenticated) {
      throw Exception('Not authenticated');
    }
    
    try {
      // Exam schedule endpoint requires multipart form data
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/vtop/examinations/doSearchExamScheduleForStudent'),
      );
      
      // Add headers
      request.headers.addAll({
        'Cookie': _cookie ?? '',
        'User-Agent': 'Mozilla/5.0 (Linux; U; Linux x86_64; en-US) Gecko/20100101 Firefox/130.5',
      });
      
      // Add form fields
      request.fields['authorizedID'] = _authorizedId ?? '';
      request.fields['semesterSubId'] = semesterId;
      request.fields['_csrf'] = _csrfToken ?? '';
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200 || response.body.contains('login')) {
        throw Exception('Session expired');
      }
      
      final examGroups = _parseExamSchedule(response.body);
      return ExamScheduleData(
        semesterId: semesterId,
        examGroups: examGroups,
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
  
  void _updateCookieFromString(String cookieStr) {
    if (cookieStr.isEmpty) return;
    
    if (_cookie == null) {
      _cookie = cookieStr;
    } else {
      // Merge cookies
      final existingMap = <String, String>{};
      for (final c in _cookie!.split('; ')) {
        final parts = c.split('=');
        if (parts.length >= 2) {
          existingMap[parts[0]] = parts.sublist(1).join('=');
        }
      }
      for (final c in cookieStr.split('; ')) {
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
    
    // First find the semesterSubId select element - matching reference selector
    // select[name="semesterSubId"] option
    final selectPattern = RegExp(
      r'''<select[^>]*name=["']semesterSubId["'][^>]*>(.*?)</select>''',
      dotAll: true,
      caseSensitive: false,
    );
    
    final selectMatch = selectPattern.firstMatch(html);
    final selectHtml = selectMatch?.group(1) ?? html;
    
    // Parse option tags from the select element
    final optionPattern = RegExp(
      r'''<option\s+value=["']([^"']+)["'][^>]*>([^<]+)</option>''',
      caseSensitive: false,
    );
    final matches = optionPattern.allMatches(selectHtml);
    
    for (final match in matches) {
      final id = match.group(1)?.trim() ?? '';
      var name = match.group(2)?.trim() ?? '';
      
      // Skip empty or default options
      if (id.isEmpty || name.isEmpty || id == '0' || name.toLowerCase().contains('select')) {
        continue;
      }
      
      // Clean up name - remove "- AMR" suffix as per reference
      name = name.replaceAll('- AMR', '').trim();
      
      semesters.add(Semester(id: id, name: name));
    }
    
    return semesters;
  }
  
  /// Normalize day names to full format (Monday, Tuesday, etc.)
  String _normalizeDay(String day) {
    final upper = day.toUpperCase().trim();
    if (upper.startsWith('MON')) return 'Monday';
    if (upper.startsWith('TUE')) return 'Tuesday';
    if (upper.startsWith('WED')) return 'Wednesday';
    if (upper.startsWith('THU')) return 'Thursday';
    if (upper.startsWith('FRI')) return 'Friday';
    if (upper.startsWith('SAT')) return 'Saturday';
    if (upper.startsWith('SUN')) return 'Sunday';
    return day; // Return as-is if not recognized
  }
  
  List<TimetableSlot> _parseTimetable(String html) {
    final slots = <TimetableSlot>[];
    
    final tablePattern = RegExp(r'<table[^>]*>(.*?)</table>', dotAll: true, caseSensitive: false);
    final tbodyPattern = RegExp(r'<tbody[^>]*>(.*?)</tbody>', dotAll: true, caseSensitive: false);
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true, caseSensitive: false);
    
    // Maps to store course info and faculty (keyed by course code)
    final courseNames = <String, String>{};
    final facultyTheory = <String, String>{};
    final facultyLab = <String, String>{};
    
    // Find all tbody elements
    final tbodies = tbodyPattern.allMatches(html).toList();
    
    // STEP 1: Parse course info from first tbody OR from any table with 9+ cell rows
    // Try tbody first
    if (tbodies.isNotEmpty) {
      final firstTbody = tbodies[0].group(1) ?? '';
      _extractCourseInfo(firstTbody, rowPattern, cellPattern, courseNames, facultyTheory, facultyLab);
    }
    
    // Also scan all tables for course info (fallback)
    final tables = tablePattern.allMatches(html).toList();
    for (final t in tables) {
      final content = t.group(1) ?? '';
      _extractCourseInfo(content, rowPattern, cellPattern, courseNames, facultyTheory, facultyLab);
    }
    
    // STEP 2: Parse timetable grid from second tbody
    if (tbodies.length < 2) {
      // Fallback: try to find table with day names
      final tables = tablePattern.allMatches(html).toList();
      for (final t in tables) {
        final content = t.group(0) ?? '';
        if (content.contains('>MON<') || content.contains('>TUE<') || 
            content.contains('>WED<') || content.contains('>THU<') ||
            RegExp(r'<td[^>]*>\s*(MON|TUE|WED|THU|FRI|SAT)\s*</td>', caseSensitive: false).hasMatch(content)) {
          // Found timetable table, process it
          return _parseTimetableFromTable(content, courseNames, facultyTheory, facultyLab);
        }
      }
      return slots;
    }
    
    final timetableTbody = tbodies[1].group(1) ?? '';
    return _parseTimetableFromTable(timetableTbody, courseNames, facultyTheory, facultyLab);
  }
  
  List<TimetableSlot> _parseTimetableFromTable(
    String tableHtml,
    Map<String, String> courseNames,
    Map<String, String> facultyTheory,
    Map<String, String> facultyLab,
  ) {
    final slots = <TimetableSlot>[];
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true, caseSensitive: false);
    
    final allRows = rowPattern.allMatches(tableHtml).map((m) => m.group(1) ?? '').toList();
    
    // Timing storage: serial (column index) -> {start, end}
    final timingsTheory = <String, Map<String, String>>{};
    final timingsLab = <String, Map<String, String>>{};
    
    // Temporary slot storage to assign times after parsing
    final tempSlots = <Map<String, dynamic>>[];
    
    String currentDay = '';
    int countForOffset = 0;
    
    for (final rowContent in allRows) {
      var cells = cellPattern.allMatches(rowContent).map((m) => m.group(1) ?? '').toList();
      
      // Only process rows with more than 6 cells (like vitap-mate)
      if (cells.length <= 6) continue;
      
      // On even offset rows, first cell contains day name or timing label
      if (countForOffset % 2 == 0) {
        final firstCell = _stripHtml(cells[0]).replaceAll('\t', '').replaceAll('\n', '').trim().toUpperCase();
        
        // Check if it's a day name
        final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        if (dayNames.contains(firstCell)) {
          currentDay = _normalizeDay(firstCell);
        }
        
        // Remove first cell (day/label)
        cells = cells.sublist(1);
      }
      
      // Process cells based on countForOffset
      for (int index = 0; index < cells.length; index++) {
        final cellContent = _stripHtml(cells[index]).replaceAll('\t', '').replaceAll('\n', '').trim();
        
        if (countForOffset < 4) {
          // Timing rows
          if (countForOffset == 0) {
            // Theory START times
            timingsTheory[index.toString()] = {'start': cellContent, 'end': ''};
          } else if (countForOffset == 1) {
            // Theory END times
            if (timingsTheory.containsKey(index.toString())) {
              timingsTheory[index.toString()]!['end'] = cellContent;
            }
          } else if (countForOffset == 2) {
            // Lab START times
            timingsLab[index.toString()] = {'start': cellContent, 'end': ''};
          } else if (countForOffset == 3) {
            // Lab END times
            if (timingsLab.containsKey(index.toString())) {
              timingsLab[index.toString()]!['end'] = cellContent;
            }
          }
        } else {
          // Day rows (class slots) - countForOffset > 3
          if (cellContent.isEmpty || index == 0) continue;
          
          // Check for valid slot format: SLOT-CODE-TYPE-ROOM-...
          if (cellContent.length > 5 && cellContent.contains('-')) {
            final parts = cellContent.split('-').where((p) => p.trim().isNotEmpty).toList();
            if (parts.length > 2) {
              // is_lab determined by odd countForOffset
              final isLabRow = countForOffset % 2 != 0;
              
              final slotName = parts[0].trim();
              final code = parts.length > 1 ? parts[1].trim() : '';
              final courseTypeRaw = parts.length > 2 ? parts[2].trim().toUpperCase() : '';
              final room = parts.length > 3 ? parts[3].trim() : '';
              final blockParts = parts.length > 4 ? parts.sublist(4) : <String>[];
              final block = blockParts.take(2).join(' ');
              
              String courseType = courseTypeRaw;
              if (courseTypeRaw == 'ETH' || courseTypeRaw == 'TH') courseType = 'Theory';
              if (courseTypeRaw == 'ELA' || courseTypeRaw == 'LA') courseType = 'Lab';
              
              // Get faculty - try both maps
              String faculty = '';
              if (isLabRow) {
                faculty = facultyLab[code] ?? facultyTheory[code] ?? '';
              } else {
                faculty = facultyTheory[code] ?? facultyLab[code] ?? '';
              }
              
              final fullVenue = block.isNotEmpty ? '$room-$block' : room;
              
              // Store with serial (column index) for time matching later
              tempSlots.add({
                'day': currentDay.isNotEmpty ? currentDay : 'Unknown',
                'slotName': slotName,
                'courseCode': code,
                'courseName': courseNames[code] ?? '',
                'courseType': courseType,
                'venue': fullVenue,
                'block': block,
                'isLab': isLabRow,
                'faculty': faculty,
                'serial': index.toString(),
              });
            }
          }
        }
      }
      
      countForOffset++;
    }
    
    // STEP 3: Match times to slots using serial (like vitap-mate)
    for (int i = 0; i < tempSlots.length; i++) {
      final slotData = tempSlots[i];
      final serial = slotData['serial'] as String;
      final isLab = slotData['isLab'] as bool;
      
      String startTime = '';
      String endTime = '';
      
      // Theory slots use timingsTheory, Lab slots use timingsLab
      if (!isLab && timingsTheory.containsKey(serial)) {
        startTime = timingsTheory[serial]!['start'] ?? '';
        endTime = timingsTheory[serial]!['end'] ?? '';
      }
      if (isLab && timingsLab.containsKey(serial)) {
        startTime = timingsLab[serial]!['start'] ?? '';
        endTime = timingsLab[serial]!['end'] ?? '';
      }
      
      // Fallback: if times not found, try the other timing map
      if (startTime.isEmpty && !isLab && timingsLab.containsKey(serial)) {
        startTime = timingsLab[serial]!['start'] ?? '';
        endTime = timingsLab[serial]!['end'] ?? '';
      }
      if (startTime.isEmpty && isLab && timingsTheory.containsKey(serial)) {
        startTime = timingsTheory[serial]!['start'] ?? '';
        endTime = timingsTheory[serial]!['end'] ?? '';
      }
      
      slots.add(TimetableSlot(
        day: slotData['day'] as String,
        slotName: slotData['slotName'] as String,
        courseCode: slotData['courseCode'] as String,
        courseName: slotData['courseName'] as String,
        courseType: slotData['courseType'] as String,
        venue: slotData['venue'] as String,
        block: slotData['block'] as String,
        startTime: startTime,
        endTime: endTime,
        isLab: isLab,
        faculty: slotData['faculty'] as String,
        serial: i,
      ));
    }
    
    return slots;
  }
  
  /// Helper method to extract course names and faculty from course info tables
  void _extractCourseInfo(
    String content,
    RegExp rowPattern,
    RegExp cellPattern,
    Map<String, String> courseNames,
    Map<String, String> facultyTheory,
    Map<String, String> facultyLab,
  ) {
    final rows = rowPattern.allMatches(content).toList();
    
    for (final row in rows) {
      final rowHtml = row.group(1) ?? '';
      final cells = cellPattern.allMatches(rowHtml).toList();
      
      // Need at least 9 cells for course info table
      if (cells.length < 9) continue;
      
      // Extract all cell text first
      final cellTexts = cells.map((c) => _stripHtml(c.group(1) ?? '').replaceAll('\t', '').replaceAll('\n', '').trim()).toList();
      
      // Try to find course code and name
      // Usually in format: "CODE - Course Name (Theory/Lab)" in one of the first cells
      String? courseCode;
      String? courseName;
      bool isLab = false;
      
      for (int i = 0; i < cells.length && i < 5; i++) {
        final cellText = cellTexts[i];
        
        // Look for cell with CODE-Name format (CODE is like CSE1001, ENG1001, etc.)
        if (cellText.contains('-')) {
          // Try to extract code as first part before dash
          final parts = cellText.split('-');
          if (parts.isNotEmpty) {
            final possibleCode = parts[0].trim();
            // Course codes are typically 7 characters: 3 letters + 4 digits
            if (possibleCode.length >= 6 && possibleCode.length <= 8 && 
                RegExp(r'^[A-Z]+\d+').hasMatch(possibleCode)) {
              courseCode = possibleCode;
              
              // Get the rest as course name
              if (parts.length > 1) {
                var rest = parts.sublist(1).join('-').trim();
                final parenIndex = rest.indexOf('(');
                if (parenIndex > 0) {
                  courseName = rest.substring(0, parenIndex).trim();
                  isLab = rest.toLowerCase().contains('lab') || rest.toLowerCase().contains('ela');
                } else {
                  courseName = rest;
                }
              }
              break;
            }
          }
        }
      }
      
      // If we found course code and name, store them
      if (courseCode != null && courseName != null && courseName.isNotEmpty) {
        if (!courseNames.containsKey(courseCode)) {
          courseNames[courseCode] = courseName;
        }
        
        // Find faculty name - it's typically the cell with a proper name format
        // VTOP faculty cell is usually cells[8] (9th cell, 0-indexed)
        // Faculty names have spaces and are typically all caps or mixed case
        
        // First try cell 8 (most common position)
        String facultyName = '';
        if (cells.length > 8) {
          final text = cellTexts[8];
          // Faculty name validation: not empty, not short codes, not type indicators
          if (text.length >= 5 &&
              !RegExp(r'^\d+$').hasMatch(text) && // Not just numbers
              !['theory', 'lab', 'eth', 'ela', 'th', 'la', 'lo', 'project', 'tutorial'].contains(text.toLowerCase())) {
            facultyName = text;
          }
        }
        
        // If not found in cell 8, search other cells (6-10)
        if (facultyName.isEmpty) {
          for (int i = 6; i < cells.length && i <= 10; i++) {
            if (i == 8) continue; // Already tried
            final text = cellTexts[i];
            // Look for proper name pattern (has space, reasonable length, not a code)
            if (text.length >= 8 && text.contains(' ') &&
                !RegExp(r'^\d').hasMatch(text) && // Doesn't start with number
                !RegExp(r'^[A-Z]{2,6}\d').hasMatch(text)) { // Not a course code
              facultyName = text;
              break;
            }
          }
        }
        
        // Store faculty
        if (facultyName.isNotEmpty) {
          if (isLab) {
            if (!facultyLab.containsKey(courseCode)) facultyLab[courseCode] = facultyName;
          } else {
            if (!facultyTheory.containsKey(courseCode)) facultyTheory[courseCode] = facultyName;
          }
        }
      }
    }
  }
  
  List<AttendanceCourse> _parseAttendance(String html) {
    final courses = <AttendanceCourse>[];
    
    // Parse attendance table - matching vitap-mate parseattn.rs
    // Cell indices (0-indexed):
    // 0: serial, 1: category, 2: courseName, 3: courseCode, 4: faculty
    // 5: classesAttended, 6: totalClasses, 7: attendancePercentage
    // 8: fatCatPercentage (between exams), 9: debarStatus
    // Last cell: contains onclick with courseId and courseType
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    final rows = rowPattern.allMatches(html).toList();
    
    for (final row in rows) {
      final rowHtml = row.group(1) ?? '';
      final cells = cellPattern.allMatches(rowHtml).toList();
      
      // Need at least 8 cells for a valid attendance row
      if (cells.length < 8) continue;
      
      try {
        // Extract cell values following vitap-mate indices
        final serial = _stripHtml(cells[0].group(1) ?? '').trim();
        final category = _stripHtml(cells[1].group(1) ?? '').trim();
        final courseName = _stripHtml(cells[2].group(1) ?? '').trim();
        final courseCode = _stripHtml(cells[3].group(1) ?? '').trim();
        final faculty = _stripHtml(cells[4].group(1) ?? '').trim();
        final attendedStr = _stripHtml(cells[5].group(1) ?? '').trim();
        final totalStr = _stripHtml(cells[6].group(1) ?? '').trim();
        final percentStr = _stripHtml(cells[7].group(1) ?? '').trim();
        
        // FAT/CAT percentage (between exams) - may not exist
        String fatCatPercentage = '-';
        if (cells.length > 8) {
          fatCatPercentage = _stripHtml(cells[8].group(1) ?? '').trim();
          if (fatCatPercentage.isEmpty) fatCatPercentage = '-';
        }
        
        // Debar status
        String debarStatus = '';
        if (cells.length > 9) {
          debarStatus = _stripHtml(cells[9].group(1) ?? '').trim();
        }
        
        // Skip header rows or invalid rows
        if (serial.toLowerCase() == 'sl.no' || serial.toLowerCase() == 'serial') continue;
        
        // Skip if course code doesn't look like a course code
        if (courseCode.isEmpty || !RegExp(r'[A-Z]{2,4}\d{3,4}').hasMatch(courseCode)) {
          continue;
        }
        
        // Extract courseId and courseType from the last cell's onclick
        // Format: onclick="...,'courseId','courseType')"
        String courseId = '';
        String courseType = '';
        final lastCellHtml = cells.last.group(0) ?? '';
        
        // Try multiple onclick patterns
        var onclickMatch = RegExp(r"'([^']+)'\s*,\s*'([^']+)'\s*\)").firstMatch(lastCellHtml);
        if (onclickMatch != null) {
          courseId = onclickMatch.group(1) ?? '';
          courseType = onclickMatch.group(2) ?? '';
        } else {
          // Try another pattern: infocell[2] and infocell[3]
          final splitMatch = RegExp(r',\s*([^,\)]+)\s*,\s*([^,\)]+)\s*\)').firstMatch(lastCellHtml);
          if (splitMatch != null) {
            courseId = splitMatch.group(1)?.replaceAll("'", '').trim() ?? '';
            courseType = splitMatch.group(2)?.replaceAll("'", '').replaceAll(')', '').trim() ?? '';
          }
        }
        
        // If courseType not found from onclick, use category
        if (courseType.isEmpty) {
          courseType = category;
        }
        
        final attended = int.tryParse(attendedStr) ?? 0;
        final total = int.tryParse(totalStr) ?? 0;
        final percent = double.tryParse(percentStr.replaceAll('%', '')) ?? 0.0;
        
        courses.add(AttendanceCourse(
          courseCode: courseCode,
          courseName: courseName,
          courseType: courseType,
          faculty: faculty,
          slot: '',
          totalClasses: total,
          attendedClasses: attended,
          absentClasses: total - attended,
          percentage: percent,
          fatCatPercentage: fatCatPercentage,
          courseId: courseId,
          category: category,
          debarStatus: debarStatus,
        ));
      } catch (_) {
        continue;
      }
    }
    
    return courses;
  }
  
  /// Parse detailed attendance records for a course
  /// Based on vitap-mate: parseattn.rs parse_full_attendance
  /// Columns: serial(0), date(1), slot(2), day_time(3), status(4), remark(5)
  List<AttendanceDetail> _parseAttendanceDetail(String html) {
    final details = <AttendanceDetail>[];
    
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    // Skip first 3 rows as per vitap-mate (headers)
    final rows = rowPattern.allMatches(html).skip(3).toList();
    
    for (final row in rows) {
      final rowHtml = row.group(1) ?? '';
      final cells = cellPattern.allMatches(rowHtml).toList();
      
      // Need at least 5 cells as per vitap-mate (cells.len() > 5 means >= 6)
      if (cells.length < 5) {
        continue;
      }
      
      try {
        final serial = _stripHtml(cells[0].group(1) ?? '').trim();
        final date = _stripHtml(cells[1].group(1) ?? '').trim();
        final slot = _stripHtml(cells[2].group(1) ?? '').trim();
        final dayTime = _stripHtml(cells[3].group(1) ?? '').trim();
        final status = _stripHtml(cells[4].group(1) ?? '').trim();
        final remark = cells.length > 5 ? _stripHtml(cells[5].group(1) ?? '').trim() : '';
        
        // Skip if serial is not numeric (probably header row)
        if (int.tryParse(serial) == null) continue;
        
        details.add(AttendanceDetail(
          serial: serial,
          date: date,
          slot: slot,
          dayTime: dayTime,
          status: status,
          remark: remark,
        ));
      } catch (_) {
        continue;
      }
    }
    
    return details;
  }
  
  List<CourseMarks> _parseMarks(String html) {
    final courses = <CourseMarks>[];
    
    // Parse marks based on vitap-mate reference
    // Rows alternate: course header (tr.tableContent) then marks detail (tr.tableContent with nested tr.tableContent-level1)
    final rowPattern = RegExp(r'<tr[^>]*class="[^"]*tableContent[^"]*"[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    final nestedRowPattern = RegExp(r'<tr[^>]*class="[^"]*tableContent-level1[^"]*"[^>]*>(.*?)</tr>', dotAll: true);
    
    final rows = rowPattern.allMatches(html).toList();
    
    CourseMarks? currentCourse;
    bool expectingMarks = false;
    
    for (final row in rows) {
      final rowHtml = row.group(1) ?? '';
      final cells = cellPattern.allMatches(rowHtml).toList();
      
      if (expectingMarks) {
        // This row contains the marks table
        final nestedRows = nestedRowPattern.allMatches(rowHtml).toList();
        final components = <MarkComponent>[];
        
        for (final nestedRow in nestedRows) {
          final nestedCells = cellPattern.allMatches(nestedRow.group(1) ?? '').toList();
          if (nestedCells.length >= 7) {
            components.add(MarkComponent(
              serial: _stripHtml(nestedCells[0].group(1) ?? '').trim(),
              name: _stripHtml(nestedCells[1].group(1) ?? '').trim(),
              maxMarks: _stripHtml(nestedCells[2].group(1) ?? '').trim(),
              weightage: _stripHtml(nestedCells[3].group(1) ?? '').trim(),
              status: _stripHtml(nestedCells[4].group(1) ?? '').trim(),
              scoredMarks: _stripHtml(nestedCells[5].group(1) ?? '').trim(),
              weightedScore: _stripHtml(nestedCells[6].group(1) ?? '').trim(),
              remark: nestedCells.length > 7 ? _stripHtml(nestedCells[7].group(1) ?? '').trim() : '',
            ));
          }
        }
        
        if (currentCourse != null) {
          courses.add(CourseMarks(
            serial: currentCourse.serial,
            courseCode: currentCourse.courseCode,
            courseName: currentCourse.courseName,
            courseType: currentCourse.courseType,
            faculty: currentCourse.faculty,
            slot: currentCourse.slot,
            components: components,
          ));
        }
        
        expectingMarks = false;
        currentCourse = null;
      } else if (cells.length >= 8) {
        // This is a course header row
        // Cells: serial, ?, courseCode, courseTitle, courseType, ?, faculty, slot
        currentCourse = CourseMarks(
          serial: _stripHtml(cells[0].group(1) ?? '').trim(),
          courseCode: _stripHtml(cells[2].group(1) ?? '').trim(),
          courseName: _stripHtml(cells[3].group(1) ?? '').trim(),
          courseType: _stripHtml(cells[4].group(1) ?? '').trim(),
          faculty: _stripHtml(cells[6].group(1) ?? '').trim(),
          slot: _stripHtml(cells[7].group(1) ?? '').trim(),
          components: [],
        );
        expectingMarks = true;
      }
    }
    
    return courses;
  }
  
  List<ExamTypeGroup> _parseExamSchedule(String html) {
    final examGroups = <ExamTypeGroup>[];
    
    // Parse exam schedule based on vitap-mate reference
    // Structure: rows with < 3 cells are exam type headers, rows with > 12 cells are exam records
    final rowPattern = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
    final cellPattern = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
    
    final rows = rowPattern.allMatches(html).skip(2).toList(); // Skip first 2 header rows
    
    ExamTypeGroup? currentGroup;
    
    for (final row in rows) {
      final cells = cellPattern.allMatches(row.group(1) ?? '').toList();
      
      if (cells.length < 3) {
        // This is an exam type header
        final examType = _stripHtml(cells[0].group(1) ?? '').trim();
        if (examType.isNotEmpty) {
          if (currentGroup != null) {
            examGroups.add(currentGroup);
          }
          currentGroup = ExamTypeGroup(examType: examType, exams: []);
        }
      } else if (cells.length > 12 && currentGroup != null) {
        // This is an exam record
        // Cells: serial, courseCode, courseName, courseType, courseId, slot, examDate, examSession, reportingTime, examTime, venue, seatLocation, seatNo
        final exam = ExamSlot(
          serial: _stripHtml(cells[0].group(1) ?? '').trim(),
          courseCode: _stripHtml(cells[1].group(1) ?? '').trim(),
          courseName: _stripHtml(cells[2].group(1) ?? '').trim(),
          courseType: _stripHtml(cells[3].group(1) ?? '').trim(),
          courseId: _stripHtml(cells[4].group(1) ?? '').trim(),
          slot: _stripHtml(cells[5].group(1) ?? '').trim(),
          examDate: _stripHtml(cells[6].group(1) ?? '').trim(),
          examSession: _stripHtml(cells[7].group(1) ?? '').trim(),
          reportingTime: _stripHtml(cells[8].group(1) ?? '').trim(),
          examTime: _stripHtml(cells[9].group(1) ?? '').trim(),
          venue: _stripHtml(cells[10].group(1) ?? '').trim(),
          seatLocation: _stripHtml(cells[11].group(1) ?? '').trim(),
          seatNo: _stripHtml(cells[12].group(1) ?? '').trim(),
        );
        currentGroup.exams.add(exam);
      }
    }
    
    // Add last group
    if (currentGroup != null) {
      examGroups.add(currentGroup);
    }
    
    return examGroups;
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

/// Simple HTTP response container
class _HttpResponse {
  final int statusCode;
  final String body;
  
  _HttpResponse({required this.statusCode, required this.body});
}
