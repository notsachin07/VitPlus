import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wifi_service.dart';
import '../models/wifi_network.dart';
import '../models/connection_status.dart';

final wifiServiceProvider = Provider<WiFiService>((ref) {
  return WiFiService();
});

final connectionStatusProvider = StateNotifierProvider<ConnectionStatusNotifier, ConnectionStatus>((ref) {
  return ConnectionStatusNotifier(ref.read(wifiServiceProvider));
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

  Future<void> connect(String ssid, String username, String password) async {
    state = ConnectionStatus.connecting;
    try {
      final result = await _wifiService.connectToNetwork(ssid, username, password);
      state = result ? ConnectionStatus.connected : ConnectionStatus.failed;
    } catch (e) {
      state = ConnectionStatus.failed;
    }
  }

  Future<void> disconnect() async {
    state = ConnectionStatus.disconnecting;
    await _wifiService.disconnect();
    state = ConnectionStatus.disconnected;
  }

  void updateStatus(ConnectionStatus status) {
    state = status;
  }
}
