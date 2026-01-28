import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../providers/vtop_provider.dart';

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
  bool _isAutoLoggingIn = false;
  String _currentUrl = 'https://vtop.vitap.ac.in';
  String _pageTitle = 'VTOP';
  String _statusMessage = 'Initializing...';
  
  // VTOP URLs
  static const String vtopBase = 'https://vtop.vitap.ac.in';
  static const String vtopContent = 'https://vtop.vitap.ac.in/vtop/content?';
  static const String vtopLogin = 'https://vtop.vitap.ac.in/vtop/open/page';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _webviewController.initialize();
      
      _webviewController.url.listen((url) {
        if (mounted) {
          setState(() {
            _currentUrl = url;
          });
          // Check if we're on the content page (logged in)
          if (url.contains('/vtop/content') || url.contains('/vtop/initialPage') || 
              url.contains('/vtop/academics') || url.contains('/vtop/examinations')) {
            setState(() {
              _isAutoLoggingIn = false;
              _statusMessage = 'Logged in successfully!';
            });
          }
          // Check if we've been redirected to login (session expired)
          if (_isAutoLoggingIn && (url.contains('/vtop/login') || url.contains('/vtop/open/page'))) {
            // Session expired or not valid
          }
        }
      });

      _webviewController.title.listen((title) {
        if (mounted && title.isNotEmpty) {
          setState(() {
            _pageTitle = title;
          });
        }
      });

      _webviewController.loadingState.listen((state) {
        if (mounted) {
          setState(() {
            _isLoading = state == LoadingState.loading;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Try auto-login
      await _tryAutoLogin();
      
    } catch (e) {
      debugPrint('WebView initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _statusMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  Future<void> _tryAutoLogin() async {
    if (!mounted) return;
    setState(() {
      _isAutoLoggingIn = true;
      _statusMessage = 'Checking credentials...';
    });

    try {
      // First check if we have credentials
      final creds = await _storage.getVtopCredentials();
      if (creds == null || creds['username']?.isEmpty == true || creds['password']?.isEmpty == true) {
        if (!mounted) return;
        setState(() {
          _isAutoLoggingIn = false;
          _statusMessage = 'No credentials saved. Please add in Settings.';
        });
        await _webviewController.loadUrl(vtopLogin);
        return;
      }

      // Check if we have a valid session
      final session = await _storage.getVtopSession();
      
      if (session != null && session['cookie'] != null && session['cookie']!.isNotEmpty) {
        if (!mounted) return;
        setState(() => _statusMessage = 'Found saved session, attempting to use...');
        
        // First load the VTOP domain to set cookies properly
        await _webviewController.loadUrl(vtopBase);
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        // Inject cookies into webview
        final cookie = session['cookie']!;
        await _injectCookies(cookie);
        
        // Navigate to VTOP content page
        if (!mounted) return;
        setState(() => _statusMessage = 'Loading VTOP...');
        await _webviewController.loadUrl(vtopContent);
        
        // Wait and check if we're still logged in
        await Future.delayed(const Duration(seconds: 3));
        
        if (!mounted) return;
        
        // If redirected to login, session is invalid, try fresh login
        if (_currentUrl.contains('/vtop/login') || _currentUrl.contains('/vtop/open/page') ||
            _currentUrl.contains('prelogin')) {
          setState(() => _statusMessage = 'Session expired, logging in...');
          await _storage.clearVtopSession();
          await _performFreshLogin();
        }
      } else {
        // No session, do fresh login
        await _performFreshLogin();
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
      if (!mounted) return;
      setState(() {
        _isAutoLoggingIn = false;
        _statusMessage = 'Auto-login failed: $e';
      });
      await _webviewController.loadUrl(vtopLogin);
    }
  }
  
  Future<void> _injectCookies(String cookie) async {
    final cookies = cookie.split('; ');
    for (final c in cookies) {
      if (c.contains('=')) {
        final parts = c.split('=');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          // Set cookie with proper domain
          await _webviewController.executeScript('''
            document.cookie = "$name=$value; path=/; domain=.vitap.ac.in; secure";
          ''');
        }
      }
    }
  }

  Future<void> _performFreshLogin() async {
    if (!mounted) return;
    
    try {
      // Get credentials
      final creds = await _storage.getVtopCredentials();
      if (creds == null || creds['username']?.isEmpty == true) {
        if (!mounted) return;
        setState(() {
          _isAutoLoggingIn = false;
          _statusMessage = 'No credentials saved. Please add in Settings.';
        });
        await _webviewController.loadUrl(vtopLogin);
        return;
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'Logging in (solving captcha)...');

      // Use the provider to login (which handles captcha solving)
      final success = await ref.read(vtopProvider.notifier).login();
      
      if (!mounted) return;
      
      if (success) {
        // Get the new session and inject cookies
        final newSession = await _storage.getVtopSession();
        if (newSession != null && newSession['cookie'] != null) {
          // Load base URL first
          await _webviewController.loadUrl(vtopBase);
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (!mounted) return;
          
          // Inject cookies
          await _injectCookies(newSession['cookie']!);
        }
        
        if (!mounted) return;
        setState(() => _statusMessage = 'Login successful! Loading VTOP...');
        await _webviewController.loadUrl(vtopContent);
      } else {
        if (!mounted) return;
        setState(() {
          _isAutoLoggingIn = false;
          _statusMessage = 'Login failed. Please check credentials.';
        });
        await _webviewController.loadUrl(vtopLogin);
      }
      
      if (!mounted) return;
      setState(() => _isAutoLoggingIn = false);
    } catch (e) {
      debugPrint('Fresh login error: $e');
      if (!mounted) return;
      setState(() {
        _isAutoLoggingIn = false;
        _statusMessage = 'Login error: $e';
      });
      await _webviewController.loadUrl(vtopLogin);
    }
  }

  @override
  void dispose() {
    _webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildNavigationBar(isDark),
          Expanded(
            child: _buildWebViewContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.language,
            size: 28,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pageTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isAutoLoggingIn)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _currentUrl,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (!_isAutoLoggingIn)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _tryAutoLogin,
              tooltip: 'Auto-login',
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildNavButton(
            icon: Icons.arrow_back,
            onPressed: () async {
              await _webviewController.goBack();
            },
            isDark: isDark,
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          _buildNavButton(
            icon: Icons.arrow_forward,
            onPressed: () async {
              await _webviewController.goForward();
            },
            isDark: isDark,
            tooltip: 'Forward',
          ),
          const SizedBox(width: 8),
          _buildNavButton(
            icon: _isLoading ? Icons.close : Icons.refresh,
            onPressed: () async {
              if (_isLoading) {
                await _webviewController.stop();
              } else {
                await _webviewController.reload();
              }
            },
            isDark: isDark,
            tooltip: _isLoading ? 'Stop' : 'Refresh',
          ),
          const SizedBox(width: 8),
          _buildNavButton(
            icon: Icons.home,
            onPressed: () async {
              await _webviewController.loadUrl('https://vtop.vitap.ac.in');
            },
            isDark: isDark,
            tooltip: 'Home',
          ),
          const Spacer(),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _isInitialized ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: _isInitialized
                ? (isDark ? Colors.white70 : Colors.black54)
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewContent(bool isDark) {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading VTOP...',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Webview(
        _webviewController,
        permissionRequested: (url, kind, isUserInitiated) async {
          return WebviewPermissionDecision.allow;
        },
      ),
    );
  }
}
