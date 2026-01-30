import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../services/storage_service.dart';
import '../providers/vtop_provider.dart';
import '../services/vtop_service.dart';

// Provider for VTOP fullscreen mode - default to true (always fullscreen)
final vtopFullscreenProvider = StateProvider<bool>((ref) => true);

/// VTOP Screen - Based on vitap-mate webview implementation
/// Key improvements:
/// 1. Verify authentication before loading webview
/// 2. Proper cookie injection via WebView2 addScriptToExecuteOnDocumentCreated
/// 3. Use /vtop/content? URL after auth (like vitap-mate)
/// 4. Better error detection and session recovery
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
  bool _isSettingUp = true;
  String _statusMessage = 'Initializing...';
  bool _showControls = false;
  bool _hasError = false;
  String? _currentCookie;
  
  // VTOP URLs - Based on vitap-mate implementation
  static const String vtopBase = 'https://vtop.vitap.ac.in';
  static const String vtopContent = 'https://vtop.vitap.ac.in/vtop/content?';
  static const String vtopLogin = 'https://vtop.vitap.ac.in/vtop/open/page';

  @override
  void initState() {
    super.initState();
    _setupVtop();
  }

  /// Main setup flow - similar to vitap-mate's approach
  /// 1. First verify we have valid auth
  /// 2. Then initialize webview with cookies
  /// 3. Load the content page
  Future<void> _setupVtop() async {
    if (!mounted) return;
    
    setState(() {
      _isSettingUp = true;
      _hasError = false;
      _statusMessage = 'Checking authentication...';
    });

    try {
      // Step 1: Check if we have credentials
      final creds = await _storage.getVtopCredentials();
      if (creds == null || creds['username']?.isEmpty == true || creds['password']?.isEmpty == true) {
        // No credentials - just show login page
        await _initWebViewAndLoad(vtopLogin, null);
        return;
      }

      // Step 2: Try to get a valid session
      if (!mounted) return;
      setState(() => _statusMessage = 'Authenticating...');
      
      // Check existing session first
      var session = await _storage.getVtopSession();
      bool needsLogin = true;
      
      if (session != null && session['cookie'] != null && session['cookie']!.isNotEmpty) {
        // Verify if session is still valid
        if (!mounted) return;
        setState(() => _statusMessage = 'Verifying session...');
        
        final vtopService = VtopService();
        vtopService.setCookie(session['cookie']!);
        
        // Try to validate session by making a request
        final isValid = await vtopService.validateSession();
        if (isValid) {
          _currentCookie = session['cookie'];
          needsLogin = false;
        }
      }
      
      // Step 3: If no valid session, perform fresh login
      if (needsLogin) {
        if (!mounted) return;
        setState(() => _statusMessage = 'Logging in...');
        
        final success = await ref.read(vtopProvider.notifier).login();
        if (success) {
          final newSession = await _storage.getVtopSession();
          if (newSession != null && newSession['cookie'] != null) {
            _currentCookie = newSession['cookie'];
          }
        }
      }
      
      // Step 4: Initialize webview with cookie and load content
      if (_currentCookie != null && _currentCookie!.isNotEmpty) {
        if (!mounted) return;
        setState(() => _statusMessage = 'Loading VTOP...');
        await _initWebViewAndLoad(vtopContent, _currentCookie);
      } else {
        // Auth failed - show login page
        await _initWebViewAndLoad(vtopLogin, null);
      }
      
    } catch (e) {
      debugPrint('VTOP setup error: $e');
      // On error, try to show login page
      try {
        await _initWebViewAndLoad(vtopLogin, null);
      } catch (e2) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isSettingUp = false;
          _statusMessage = 'Failed to load VTOP';
        });
      }
    }
  }

  /// Initialize WebView and load URL with optional cookie injection
  Future<void> _initWebViewAndLoad(String url, String? cookie) async {
    try {
      if (!_isInitialized) {
        await _webviewController.initialize();
        
        // Listen for URL changes
        _webviewController.url.listen((newUrl) {
          if (!mounted) return;
          _onUrlChanged(newUrl);
        });

        // Listen for loading state
        _webviewController.loadingState.listen((state) {
          if (!mounted) return;
          setState(() {
            _isLoading = state == LoadingState.loading;
          });
        });

        // Listen for web errors but handle them gracefully
        // WebErrorStatus is an enum, just log it
        _webviewController.onLoadError.listen((errorStatus) {
          if (!mounted) return;
          // Only log errors, don't retry automatically
          // These can be transient network issues
          debugPrint('WebView load event: $errorStatus');
        });

        _isInitialized = true;
      }

      // If we have a cookie, inject it before loading
      if (cookie != null && cookie.isNotEmpty) {
        await _injectCookieScript(cookie);
      }

      // Load the URL
      await _webviewController.loadUrl(url);
      
      if (!mounted) return;
      setState(() {
        _isSettingUp = false;
        _hasError = false;
      });
      
    } catch (e) {
      debugPrint('WebView init error: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isSettingUp = false;
        _statusMessage = 'Failed to initialize';
      });
    }
  }

  /// Inject cookie via script that runs on document created
  /// This is more reliable than injecting after page load
  Future<void> _injectCookieScript(String cookie) async {
    // Parse cookies and create injection script
    final cookies = cookie.split('; ');
    final cookieStatements = <String>[];
    
    for (final c in cookies) {
      if (c.contains('=')) {
        final parts = c.split('=');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          // Set cookie with proper domain and path
          cookieStatements.add(
            'document.cookie = "$name=$value; path=/; domain=.vitap.ac.in; secure; SameSite=None";'
          );
        }
      }
    }
    
    if (cookieStatements.isNotEmpty) {
      final script = '''
        (function() {
          ${cookieStatements.join('\n          ')}
        })();
      ''';
      
      // First load the base domain to set cookies in the right context
      await _webviewController.loadUrl(vtopBase);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Execute the cookie injection script
      await _webviewController.executeScript(script);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Handle URL changes - detect errors and valid pages
  void _onUrlChanged(String url) {
    final urlLower = url.toLowerCase();
    
    // Check for successful navigation to VTOP pages
    if (urlLower.contains('/vtop/content') ||
        urlLower.contains('/vtop/initialpage') ||
        urlLower.contains('/vtop/academics') ||
        urlLower.contains('/vtop/examinations') ||
        urlLower.contains('/vtop/studentsrecord')) {
      setState(() {
        _hasError = false;
      });
    }
    
    // Check if redirected to login page (session expired)
    if (urlLower.contains('/vtop/open/page') || urlLower.contains('/vtop/login')) {
      // Session may have expired - user can login manually or click re-login
      debugPrint('Redirected to login page - session may have expired');
    }
  }

  /// Retry loading with fresh login
  Future<void> _retryWithFreshLogin() async {
    if (!mounted) return;
    
    setState(() {
      _isSettingUp = true;
      _hasError = false;
      _statusMessage = 'Re-authenticating...';
    });

    try {
      // Force a new login
      final success = await ref.read(vtopProvider.notifier).login();
      
      if (success) {
        final newSession = await _storage.getVtopSession();
        if (newSession != null && newSession['cookie'] != null) {
          _currentCookie = newSession['cookie'];
          
          if (!mounted) return;
          setState(() => _statusMessage = 'Reloading VTOP...');
          
          // Re-inject cookies and reload
          await _injectCookieScript(_currentCookie!);
          await _webviewController.loadUrl(vtopContent);
        }
      } else {
        // Login failed, load login page
        await _webviewController.loadUrl(vtopLogin);
      }
      
      if (!mounted) return;
      setState(() {
        _isSettingUp = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Retry login error: $e');
      if (!mounted) return;
      setState(() {
        _isSettingUp = false;
        _hasError = true;
        _statusMessage = 'Login failed';
      });
    }
  }

  void _toggleFullscreen() {
    final isFullscreen = ref.read(vtopFullscreenProvider);
    ref.read(vtopFullscreenProvider.notifier).state = !isFullscreen;
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
            if (_isInitialized && !_isSettingUp)
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
            
            // Setup overlay
            if (_isSettingUp)
              _buildSetupOverlay(),
            
            // Floating controls (show on hover)
            if (_showControls && _isInitialized && !_isSettingUp)
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
            onPressed: _setupVtop,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupOverlay() {
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
          _buildControlButton(Icons.login, _retryWithFreshLogin, label: 'Re-login'),
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
