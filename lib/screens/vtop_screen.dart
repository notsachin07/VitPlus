import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

// Provider for VTOP fullscreen mode - default to true (always fullscreen)
final vtopFullscreenProvider = StateProvider<bool>((ref) => true);

class VtopScreen extends ConsumerStatefulWidget {
  const VtopScreen({super.key});

  @override
  ConsumerState<VtopScreen> createState() => _VtopScreenState();
}

class _VtopScreenState extends ConsumerState<VtopScreen> {
  final _webviewController = WebviewController();
  final _storage = StorageService();
  
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isAutoLogging = false;
  String _statusMessage = 'Initializing...';
  bool _showControls = false;
  bool _hasError = false;
  bool _autoLoginAttempted = false;
  int _captchaRetryCount = 0;
  static const int _maxCaptchaRetries = 10;
  
  // Captcha solver URL (same as used in vtop_service)
  static const String captchaSolverUrl = 'https://cap.va.synaptic.gg/captcha';
  
  // VTOP URLs
  static const String vtopLogin = 'https://vtop.vitap.ac.in/vtop/open/page';
  static const String vtopContent = 'https://vtop.vitap.ac.in/vtop/content';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      debugPrint('[VTOP] Initializing WebView...');
      await _webviewController.initialize();
      
      // Listen for URL changes
      _webviewController.url.listen((url) {
        if (!mounted) return;
        _onUrlChanged(url);
      });

      // Listen for loading state
      _webviewController.loadingState.listen((state) {
        if (!mounted) return;
        final wasLoading = _isLoading;
        setState(() {
          _isLoading = state == LoadingState.loading;
        });
        
        // When page finishes loading, check if we should auto-login
        if (wasLoading && !_isLoading) {
          _onPageLoaded();
        }
      });

      // Listen for web errors
      _webviewController.onLoadError.listen((errorStatus) {
        if (!mounted) return;
        debugPrint('[VTOP] WebView error: $errorStatus');
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Load the login page
      debugPrint('[VTOP] Loading login page: $vtopLogin');
      await _webviewController.loadUrl(vtopLogin);
      
    } catch (e) {
      debugPrint('[VTOP] WebView initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasError = true;
          _statusMessage = 'Failed to initialize WebView';
        });
      }
    }
  }

  void _onUrlChanged(String url) {
    debugPrint('[VTOP] URL changed: $url');
    final urlLower = url.toLowerCase();
    
    // Check if we reached the dashboard/content page (login successful)
    if (urlLower.contains('/vtop/content') ||
        urlLower.contains('/vtop/initialpage') ||
        urlLower.contains('/vtop/academics') ||
        urlLower.contains('/vtop/examinations') ||
        urlLower.contains('/vtop/studentsrecord')) {
      debugPrint('[VTOP] Successfully logged in! Dashboard detected.');
      setState(() {
        _isAutoLogging = false;
        _hasError = false;
        _captchaRetryCount = 0;
      });
    }
    
    // Reset auto-login flag when on login page (allows retry)
    if (urlLower.contains('/vtop/open/page')) {
      // Only reset if not currently auto-logging
      if (!_isAutoLogging) {
        _autoLoginAttempted = false;
      }
    }
  }

  Future<void> _onPageLoaded() async {
    if (!mounted) return;
    
    // Small delay to ensure page is fully rendered
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Get current URL
    final currentUrl = await _webviewController.executeScript('window.location.href');
    final url = currentUrl?.toString().toLowerCase() ?? '';
    
    debugPrint('[VTOP] Page loaded: $url');
    
    // Check if we're on any login page
    final isLoginPage = url.contains('/vtop/open/page') || url.contains('/vtop/login');
    
    if (isLoginPage && !_autoLoginAttempted) {
      // First check if login form with captcha is already present
      final hasLoginForm = await _checkLoginFormPresent();
      debugPrint('[VTOP] Login form present: $hasLoginForm');
      
      if (hasLoginForm) {
        debugPrint('[VTOP] Login form detected, attempting auto-login...');
        await _attemptAutoLogin();
      } else {
        // Login form not present - try to click VTOP login button first
        debugPrint('[VTOP] Login form not present, looking for VTOP button...');
        final clickedVtop = await _clickVtopLoginButton();
        debugPrint('[VTOP] Clicked VTOP button: $clickedVtop');
        
        if (clickedVtop) {
          // Wait for the login form to load via AJAX
          debugPrint('[VTOP] Waiting for login form to load...');
          await _waitForLoginFormAndLogin();
        }
      }
    }
  }

  /// Wait for login form to appear after clicking VTOP button, then auto-login
  Future<void> _waitForLoginFormAndLogin() async {
    // Poll for login form to appear (AJAX content loading)
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      final hasForm = await _checkLoginFormPresent();
      debugPrint('[VTOP] Checking for form (attempt ${i + 1}): $hasForm');
      
      if (hasForm) {
        debugPrint('[VTOP] Login form appeared, starting auto-login...');
        await _attemptAutoLogin();
        return;
      }
    }
    
    debugPrint('[VTOP] Login form did not appear after waiting');
  }

  /// Try to click the VTOP login button on the initial page
  Future<bool> _clickVtopLoginButton() async {
    try {
      final result = await _webviewController.executeScript('''
        (function() {
          // Look for VTOP login button/link
          var vtopBtn = document.querySelector('a[onclick*="VTOP"]') ||
                       document.querySelector('button[onclick*="VTOP"]') ||
                       document.querySelector('[data-flag="VTOP"]') ||
                       document.querySelector('a[href*="VTOP"]') ||
                       document.querySelector('.btn-primary[onclick]') ||
                       document.querySelector('button.btn-primary');
          
          // Also try finding by text content
          if (!vtopBtn) {
            var allLinks = document.querySelectorAll('a, button');
            for (var i = 0; i < allLinks.length; i++) {
              var text = allLinks[i].textContent || allLinks[i].innerText || '';
              if (text.toLowerCase().includes('vtop') || text.toLowerCase().includes('login')) {
                vtopBtn = allLinks[i];
                break;
              }
            }
          }
          
          if (vtopBtn) {
            console.log('Found VTOP button:', vtopBtn.outerHTML);
            vtopBtn.click();
            return 'clicked';
          }
          
          // Debug: list what's on the page
          var buttons = document.querySelectorAll('button, a.btn, input[type="submit"]');
          var btnList = [];
          for (var i = 0; i < buttons.length && i < 10; i++) {
            btnList.push(buttons[i].outerHTML.substring(0, 100));
          }
          return 'no button found. Buttons: ' + btnList.join(' | ');
        })();
      ''');
      debugPrint('[VTOP] Click VTOP button result: $result');
      return result == 'clicked';
    } catch (e) {
      debugPrint('[VTOP] Error clicking VTOP button: $e');
      return false;
    }
  }

  Future<bool> _checkLoginFormPresent() async {
    try {
      // First get debug info about what's on the page
      final debugInfo = await _webviewController.executeScript('''
        (function() {
          var inputs = document.querySelectorAll('input');
          var inputInfo = [];
          for (var i = 0; i < inputs.length; i++) {
            inputInfo.push(inputs[i].name || inputs[i].id || inputs[i].type);
          }
          var imgs = document.querySelectorAll('img');
          var hasBase64Img = false;
          for (var i = 0; i < imgs.length; i++) {
            if (imgs[i].src && imgs[i].src.includes('base64')) {
              hasBase64Img = true;
              break;
            }
          }
          return 'inputs:[' + inputInfo.join(',') + '] base64img:' + hasBase64Img;
        })();
      ''');
      debugPrint('[VTOP] Page elements: $debugInfo');
      
      final result = await _webviewController.executeScript('''
        (function() {
          // Look for captcha image with multiple selectors
          var captchaImg = document.querySelector('img[src*="base64"]') || 
                          document.getElementById('captchaImg') ||
                          document.querySelector('img.captcha') ||
                          document.querySelector('.form-control.img-fluid');
          
          // Look for username field with multiple selectors
          var usernameField = document.querySelector('input[name="uname"]') || 
                             document.getElementById('uname') ||
                             document.querySelector('input[name="username"]') ||
                             document.querySelector('input[type="text"][id*="user"]') ||
                             document.querySelector('input[placeholder*="user" i]');
          
          // Look for password field as alternative indicator
          var passwordField = document.querySelector('input[type="password"]') ||
                             document.querySelector('input[name="passwd"]');
          
          // Form is present if we have either (captcha + username) or (username + password)
          var hasForm = (captchaImg && usernameField) || (usernameField && passwordField);
          
          return hasForm ? 'true' : 'false';
        })();
      ''');
      return result == 'true';
    } catch (e) {
      debugPrint('[VTOP] Error checking login form: $e');
      return false;
    }
  }

  Future<void> _attemptAutoLogin() async {
    if (!mounted || _isAutoLogging) return;
    
    // Check if we have credentials
    final creds = await _storage.getVtopCredentials();
    if (creds == null || creds['username']?.isEmpty == true || creds['password']?.isEmpty == true) {
      debugPrint('[VTOP] No credentials saved, user must login manually');
      return;
    }
    
    _autoLoginAttempted = true;
    
    setState(() {
      _isAutoLogging = true;
      _statusMessage = 'Auto-logging in...';
    });

    try {
      final username = creds['username']!;
      final password = creds['password']!;
      
      debugPrint('[VTOP] Getting captcha image...');
      
      // Get captcha image from WebView
      final captchaBase64 = await _getCaptchaFromWebView();
      if (captchaBase64 == null || captchaBase64.isEmpty) {
        debugPrint('[VTOP] Could not get captcha image');
        setState(() {
          _isAutoLogging = false;
          _statusMessage = 'Could not get captcha. Please login manually.';
        });
        return;
      }
      
      debugPrint('[VTOP] Got captcha (${captchaBase64.length} chars), solving...');
      setState(() => _statusMessage = 'Solving captcha...');
      
      // Solve captcha
      final captchaSolution = await _solveCaptcha(captchaBase64);
      if (captchaSolution == null) {
        debugPrint('[VTOP] Captcha solving failed, user must login manually');
        setState(() {
          _isAutoLogging = false;
          _statusMessage = 'Captcha solving failed. Please login manually.';
        });
        return;
      }
      
      debugPrint('[VTOP] Captcha solved: $captchaSolution');
      debugPrint('[VTOP] Filling login form...');
      setState(() => _statusMessage = 'Logging in...');
      
      // Fill the form and submit
      await _fillAndSubmitLoginForm(username, password, captchaSolution);
      
      // Wait a moment then check if login was successful
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;
      
      final newUrl = await _webviewController.executeScript('window.location.href');
      debugPrint('[VTOP] After login, URL: $newUrl');
      
      final newUrlStr = newUrl?.toString().toLowerCase() ?? '';
      
      if (!newUrlStr.contains('/vtop/open/page') && !newUrlStr.contains('/vtop/login')) {
        debugPrint('[VTOP] Login successful!');
        setState(() {
          _isAutoLogging = false;
          _captchaRetryCount = 0;
        });
      } else {
        // Check if there's an error message (wrong captcha, etc.)
        final errorMsg = await _webviewController.executeScript('''
          (function() {
            var alert = document.querySelector('.alert-danger, .alert-warning, .error, [class*="error"]');
            if (alert) return alert.textContent || alert.innerText;
            // Also check for any visible error text
            var body = document.body.innerText || '';
            if (body.toLowerCase().includes('invalid') || body.toLowerCase().includes('captcha')) {
              return 'captcha error detected';
            }
            return '';
          })();
        ''');
        
        debugPrint('[VTOP] Error message: $errorMsg');
        
        // If captcha was wrong, retry (up to max retries)
        _captchaRetryCount++;
        if (_captchaRetryCount < _maxCaptchaRetries) {
          debugPrint('[VTOP] Retrying login (attempt ${_captchaRetryCount + 1}/$_maxCaptchaRetries)...');
          _autoLoginAttempted = false;
          setState(() => _isAutoLogging = false);
          
          // Reload the page to get new captcha
          await _webviewController.reload();
        } else {
          debugPrint('[VTOP] Max retries reached, user must login manually');
          setState(() {
            _isAutoLogging = false;
            _captchaRetryCount = 0;
            _statusMessage = 'Max retries reached. Please login manually.';
          });
        }
      }
      
    } catch (e) {
      debugPrint('[VTOP] Auto-login error: $e');
      if (mounted) {
        setState(() {
          _isAutoLogging = false;
          _statusMessage = 'Login error: $e';
        });
      }
    }
  }

  Future<String?> _getCaptchaFromWebView() async {
    try {
      // Try multiple selectors for captcha image
      final result = await _webviewController.executeScript('''
        (function() {
          // Try to find captcha image
          var img = document.querySelector('img[src*="base64"]');
          if (!img) img = document.getElementById('captchaImg');
          if (!img) img = document.querySelector('img.captcha');
          if (!img) img = document.querySelector('img[alt*="captcha" i]');
          if (!img) img = document.querySelector('.form-control.img-fluid');
          
          if (img && img.src && img.src.includes('base64')) {
            // Return just the base64 data part, cleaned
            var src = img.src;
            var base64Index = src.indexOf('base64,');
            if (base64Index !== -1) {
              var base64Data = src.substring(base64Index + 7);
              // Clean up any whitespace or newlines
              base64Data = base64Data.replace(/\\s/g, '');
              return base64Data;
            }
          }
          return '';
        })();
      ''');
      
      if (result != null && result.toString().isNotEmpty && result.toString() != 'null') {
        // Clean the result - remove any quotes or extra characters
        String cleanedResult = result.toString().trim();
        // Remove surrounding quotes if present
        if (cleanedResult.startsWith('"') && cleanedResult.endsWith('"')) {
          cleanedResult = cleanedResult.substring(1, cleanedResult.length - 1);
        }
        if (cleanedResult.startsWith("'") && cleanedResult.endsWith("'")) {
          cleanedResult = cleanedResult.substring(1, cleanedResult.length - 1);
        }
        debugPrint('[VTOP] Captcha base64 first 50 chars: ${cleanedResult.substring(0, cleanedResult.length > 50 ? 50 : cleanedResult.length)}');
        return cleanedResult;
      }
      return null;
    } catch (e) {
      debugPrint('[VTOP] Error getting captcha: $e');
      return null;
    }
  }

  Future<String?> _solveCaptcha(String base64Data) async {
    try {
      final response = await http.post(
        Uri.parse(captchaSolverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imgstring': base64Data}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] != null) {
          return data['result'].toString();
        }
      }
      debugPrint('[VTOP] Captcha API response: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[VTOP] Captcha solver error: $e');
      return null;
    }
  }

  Future<void> _fillAndSubmitLoginForm(String username, String password, String captcha) async {
    // Escape special characters in password for JavaScript
    final escapedPassword = password
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"');
    
    // Fill the login form using JavaScript
    final fillResult = await _webviewController.executeScript('''
      (function() {
        var results = [];
        
        // Find and fill username field
        var unameField = document.querySelector('input[name="uname"]') || document.getElementById('uname');
        if (unameField) {
          unameField.value = '$username';
          unameField.dispatchEvent(new Event('input', { bubbles: true }));
          unameField.dispatchEvent(new Event('change', { bubbles: true }));
          results.push('username:ok');
        } else {
          results.push('username:not found');
        }
        
        // Find and fill password field
        var passField = document.querySelector('input[name="passwd"]') || 
                        document.querySelector('input[type="password"]') ||
                        document.getElementById('passwd');
        if (passField) {
          passField.value = '$escapedPassword';
          passField.dispatchEvent(new Event('input', { bubbles: true }));
          passField.dispatchEvent(new Event('change', { bubbles: true }));
          results.push('password:ok');
        } else {
          results.push('password:not found');
        }
        
        // Find and fill captcha field
        var captchaField = document.querySelector('input[name="captchaCheck"]') ||
                          document.querySelector('input[name="captcha"]') ||
                          document.getElementById('captchaCheck') ||
                          document.querySelector('input[placeholder*="captcha" i]');
        if (captchaField) {
          captchaField.value = '$captcha';
          captchaField.dispatchEvent(new Event('input', { bubbles: true }));
          captchaField.dispatchEvent(new Event('change', { bubbles: true }));
          results.push('captcha:ok');
        } else {
          results.push('captcha:not found');
        }
        
        return results.join(', ');
      })();
    ''');
    
    debugPrint('[VTOP] Form fill result: $fillResult');
    
    // Small delay to ensure form is filled
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Submit the form
    final submitResult = await _webviewController.executeScript('''
      (function() {
        // Try to find and click the submit button
        var submitBtn = document.querySelector('button[type="submit"]') ||
                       document.querySelector('input[type="submit"]') ||
                       document.getElementById('submitBtn') ||
                       document.querySelector('button[id*="login" i]') ||
                       document.querySelector('button.btn-primary') ||
                       document.querySelector('#loginBtn') ||
                       document.querySelector('[onclick*="submit"]');
        
        if (submitBtn) {
          submitBtn.click();
          return 'clicked button';
        } else {
          // Try submitting the form directly
          var form = document.querySelector('form') || document.getElementById('loginForm');
          if (form) {
            form.submit();
            return 'submitted form';
          }
        }
        return 'no submit found';
      })();
    ''');
    
    debugPrint('[VTOP] Submit result: $submitResult');
  }

  void _toggleFullscreen() {
    final isFullscreen = ref.read(vtopFullscreenProvider);
    ref.read(vtopFullscreenProvider.notifier).state = !isFullscreen;
  }

  void _retryAutoLogin() {
    _autoLoginAttempted = false;
    _captchaRetryCount = 0;
    _webviewController.reload();
  }

  @override
  void dispose() {
    _webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: MouseRegion(
        onEnter: (_) => setState(() => _showControls = true),
        onExit: (_) => setState(() => _showControls = false),
        child: Stack(
          children: [
            // WebView (full screen)
            if (_isInitialized)
              Positioned.fill(
                child: Webview(
                  _webviewController,
                  permissionRequested: (url, kind, isUserInitiated) async {
                    return WebviewPermissionDecision.allow;
                  },
                ),
              )
            else if (_hasError)
              _buildErrorState()
            else
              _buildLoadingState(),
            
            // Auto-login overlay
            if (_isAutoLogging)
              _buildAutoLoginOverlay(),
            
            // Floating controls (show on hover)
            if (_showControls && _isInitialized && !_isAutoLogging)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildFloatingControls(),
              ),
              
            // Exit button (always in corner)
            Positioned(
              top: 8,
              right: 8,
              child: _buildExitButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading VTOP...',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initWebView,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoLoginOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_captchaRetryCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Attempt ${_captchaRetryCount + 1}/$_maxCaptchaRetries',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          _buildControlButton(Icons.arrow_back, () => _webviewController.goBack()),
          const SizedBox(width: 8),
          _buildControlButton(Icons.arrow_forward, () => _webviewController.goForward()),
          const SizedBox(width: 8),
          _buildControlButton(
            _isLoading ? Icons.close : Icons.refresh,
            () => _isLoading ? _webviewController.stop() : _webviewController.reload(),
          ),
          const SizedBox(width: 8),
          _buildControlButton(Icons.home, () => _webviewController.loadUrl(vtopContent)),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          const SizedBox(width: 16),
          _buildControlButton(Icons.login, _retryAutoLogin, label: 'Re-login'),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed, {String? label}) {
    return Tooltip(
      message: label ?? '',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return Opacity(
      opacity: _showControls ? 1.0 : 0.3,
      child: Tooltip(
        message: 'Exit VTOP',
        child: InkWell(
          onTap: _toggleFullscreen,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.close,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
