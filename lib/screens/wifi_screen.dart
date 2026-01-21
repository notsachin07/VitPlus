import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection_status.dart';
import '../models/wifi_network.dart';
import '../providers/wifi_provider.dart';
import '../services/storage_service.dart';
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

    await ref.read(connectionStatusProvider.notifier).connect(
      _selectedSSID!,
      username,
      password,
    );

    setState(() => _isLoading = false);

    final status = ref.read(connectionStatusProvider);
    if (status == ConnectionStatus.connected || status == ConnectionStatus.authenticated) {
      _showSnackBar('Connected successfully!');
    } else {
      _showSnackBar('Connection failed', isError: true);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await ref.read(connectionStatusProvider.notifier).disconnect();
    setState(() => _isLoading = false);
    _showSnackBar('Disconnected');
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
                                child: Text('Error: $err'),
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
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _connect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successGreen,
                                  ),
                                  child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Connect'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _disconnect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorRed,
                                  ),
                                  child: const Text('Disconnect'),
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
