import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wifi_service.dart';
import '../models/wifi_network.dart';
import '../models/connection_status.dart';

final wifiServiceProvider = Provider<WiFiService>((ref) {
  return WiFiService();
});

final connectionStatusProvider = StateNotifierProvider<ConnectionStatusNotifier, ConnectionStatus>((ref) {
  final notifier = ConnectionStatusNotifier(ref.read(wifiServiceProvider));
  // Check initial connection status
  notifier.checkCurrentStatus();
  return notifier;
});

final availableNetworksProvider = FutureProvider<List<WiFiNetwork>>((ref) async {
  final wifiService = ref.read(wifiServiceProvider);
  return await wifiService.scanNetworks();
});

final currentNetworkProvider = FutureProvider<String?>((ref) async {
  final wifiService = ref.read(wifiServiceProvider);
  return await wifiService.getCurrentSSID();
});

class ConnectionStatusNotifier extends StateNotifier<ConnectionStatus> {
  final WiFiService _wifiService;

  ConnectionStatusNotifier(this._wifiService) : super(ConnectionStatus.disconnected);

  /// Check if already connected to WiFi on app start
  Future<void> checkCurrentStatus() async {
    try {
      final currentSSID = await _wifiService.getCurrentSSID();
      if (currentSSID != null && currentSSID.isNotEmpty) {
        state = ConnectionStatus.connected;
      } else {
        state = ConnectionStatus.disconnected;
      }
    } catch (e) {
      state = ConnectionStatus.disconnected;
    }
  }

  /// Returns ConnectionResult to allow UI to show appropriate message
  Future<ConnectionResult> connect(String ssid, String username, String password) async {
    state = ConnectionStatus.connecting;
    try {
      final result = await _wifiService.connectToNetwork(ssid, username, password);
      switch (result) {
        case ConnectionResult.success:
          state = ConnectionStatus.connected;
          break;
        case ConnectionResult.enterpriseNeedsCredentials:
          state = ConnectionStatus.failed;
          break;
        case ConnectionResult.networkNotFound:
        case ConnectionResult.failed:
          state = ConnectionStatus.failed;
          break;
      }
      return result;
    } catch (e) {
      state = ConnectionStatus.failed;
      return ConnectionResult.failed;
    }
  }

  Future<bool> disconnect() async {
    state = ConnectionStatus.disconnecting;
    final success = await _wifiService.disconnect();
    state = success ? ConnectionStatus.disconnected : ConnectionStatus.failed;
    return success;
  }

  void updateStatus(ConnectionStatus status) {
    state = status;
  }
}
