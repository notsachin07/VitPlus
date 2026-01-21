import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_status.dart';
import '../models/wifi_network.dart';
import '../providers/wifi_provider.dart';
import '../services/storage_service.dart';
import '../services/wifi_service.dart';
import '../theme/app_theme.dart';
import '../widgets/network_card.dart';
import '../widgets/status_indicator.dart';

class WiFiScreen extends ConsumerStatefulWidget {
  const WiFiScreen({super.key});

  @override
  ConsumerState<WiFiScreen> createState() => _WiFiScreenState();
}

class _WiFiScreenState extends ConsumerState<WiFiScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberCredentials = true;
  bool _isLoading = false;
  String? _selectedSSID;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final storage = StorageService();
    await storage.init();
    final creds = await storage.getCredentials();
    if (creds != null) {
      setState(() {
        _usernameController.text = creds['username'] ?? '';
        _passwordController.text = creds['password'] ?? '';
      });
    }
  }

  Future<void> _connect() async {
    if (_selectedSSID == null) {
      _showSnackBar('Please select a network first', isError: true);
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter credentials', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    if (_rememberCredentials) {
      final storage = StorageService();
      await storage.saveCredentials(username, password);
    }

    final result = await ref.read(connectionStatusProvider.notifier).connect(
      _selectedSSID!,
      username,
      password,
    );

    setState(() => _isLoading = false);

    switch (result) {
      case ConnectionResult.success:
        _showSnackBar('Connected successfully!');
        break;
      case ConnectionResult.enterpriseNeedsCredentials:
        _showEnterpriseCredentialsDialog();
        break;
      case ConnectionResult.networkNotFound:
        _showSnackBar('Network not found. Try refreshing.', isError: true);
        break;
      case ConnectionResult.failed:
        _showSnackBar('Connection failed', isError: true);
        break;
    }
  }

  void _showEnterpriseCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_lock, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Manual Setup Required'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This enterprise network requires manual credential setup.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 20),
              Text(
                'Follow these steps:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 12),
              Text('1. Open Windows WiFi settings'),
              SizedBox(height: 6),
              Text('2. If already connected/saved, click "Forget" on this network'),
              SizedBox(height: 6),
              Text('3. Click on the network to connect'),
              SizedBox(height: 6),
              Text('4. When prompted for credentials:'),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.blue),
                        SizedBox(width: 6),
                        Text('Username: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('lowercase, no spaces'),
                      ],
                    ),
                    Text('   Example: 21bce7000', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.blue),
                        SizedBox(width: 6),
                        Text('Password: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('enter exactly as set'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text(
                '💡 Once connected successfully, Windows will remember your credentials for future connections.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Process.run('cmd', ['/c', 'start', 'ms-settings:network-wifi']);
            },
            child: const Text('Open WiFi Settings'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    final success = await ref.read(connectionStatusProvider.notifier).disconnect();
    setState(() => _isLoading = false);
    
    if (success) {
      _showSnackBar('Disconnected successfully');
      // Refresh networks list
      ref.refresh(availableNetworksProvider);
      ref.refresh(currentNetworkProvider);
    } else {
      _showSnackBar('Failed to disconnect', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = ref.watch(connectionStatusProvider);
    final networksAsync = ref.watch(availableNetworksProvider);
    final currentNetwork = ref.watch(currentNetworkProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi,
                size: 32,
                color: isDark ? Colors.white : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 12),
              Text(
                'WiFi Connection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              StatusIndicator(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to VIT-AP campus or hostel WiFi networks',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Available Networks',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => ref.refresh(availableNetworksProvider),
                                icon: const Icon(Icons.refresh, size: 20),
                                tooltip: 'Refresh',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: networksAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (err, _) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_off,
                                        size: 48,
                                        color: isDark ? Colors.white54 : Colors.black38,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Location Services Required',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Windows requires Location Services to be enabled to scan WiFi networks.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await Process.run('cmd', ['/c', 'start', 'ms-settings:privacy-location']);
                                        },
                                        icon: const Icon(Icons.settings),
                                        label: const Text('Open Location Settings'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: () => ref.refresh(availableNetworksProvider),
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              data: (networks) {
                                if (networks.isEmpty) {
                                  return const Center(
                                    child: Text('No networks found'),
                                  );
                                }
                                return ListView.builder(
                                  itemCount: networks.length,
                                  itemBuilder: (context, index) {
                                    final network = networks[index];
                                    final isSelected = _selectedSSID == network.ssid;
                                    final isConnected = currentNetwork.value == network.ssid;

                                    return NetworkCard(
                                      network: network,
                                      isSelected: isSelected,
                                      isConnected: isConnected,
                                      onTap: () {
                                        setState(() {
                                          _selectedSSID = network.ssid;
                                        });
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credentials',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'Registration number',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'WiFi password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword 
                                    ? Icons.visibility_outlined 
                                    : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberCredentials,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberCredentials = value ?? false;
                                  });
                                },
                              ),
                              Text(
                                'Remember credentials',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (_selectedSSID != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark 
                                  ? AppTheme.darkBg 
                                  : AppTheme.lightBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.wifi, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedSSID!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _connect,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _isLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Connect',
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: _isLoading ? null : _disconnect,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.errorRed,
                                      side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Disconnect',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
