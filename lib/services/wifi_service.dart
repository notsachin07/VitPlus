import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import '../models/wifi_network.dart';
import 'storage_service.dart';

/// Exception thrown when Windows Location Services are disabled
class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException([this.message = 'Location services are required to scan WiFi networks']);
  
  @override
  String toString() => message;
}

/// Result of a connection attempt
enum ConnectionResult {
  success,
  failed,
  enterpriseNeedsCredentials,
  networkNotFound,
}

class WiFiService {
  static const String shyChar = '\u00ad';

  static const List<String> campusSSIDs = ['VIT2.4G', 'VIT5G'];
  static const List<String> hostelSSIDs = ['MH4-WIFI', 'MH5-WIFI', 'LH1-WIFI'];
  static const List<String> enterpriseSSIDs = ['MH6-WIFI', 'LH3-WIFI'];

  /// Check if location permission error is present in the output
  bool _isLocationPermissionError(String output) {
    return output.contains('location permission') ||
           output.contains('Location services') ||
           output.contains('privacy-location');
  }

  Future<List<WiFiNetwork>> scanNetworks() async {
    try {
      final result = await Process.run(
        'netsh',
        ['wlan', 'show', 'networks', 'mode=bssid'],
        stdoutEncoding: const SystemEncoding(),
      );

      final stdout = result.stdout as String;
      final stderr = result.stderr as String;

      // Check for location permission error
      if (_isLocationPermissionError(stdout) || _isLocationPermissionError(stderr)) {
        throw LocationPermissionException();
      }

      if (result.exitCode != 0) return [];

      return _parseNetworkScan(stdout);
    } on LocationPermissionException {
      rethrow;
    } catch (e) {
      return [];
    }
  }

  List<WiFiNetwork> _parseNetworkScan(String output) {
    final networks = <WiFiNetwork>[];
    final lines = output.split('\n');
    
    String? currentSSID;
    String? currentBSSID;
    int signalStrength = 0;
    String authType = '';

    for (final line in lines) {
      if (line.contains('SSID') && !line.contains('BSSID')) {
        final match = RegExp(r'SSID\s*\d*\s*:\s*(.+)').firstMatch(line);
        if (match != null) {
          currentSSID = match.group(1)?.trim();
        }
      } else if (line.contains('BSSID')) {
        final match = RegExp(r'BSSID\s*\d*\s*:\s*(.+)').firstMatch(line);
        if (match != null) {
          currentBSSID = match.group(1)?.trim();
        }
      } else if (line.toLowerCase().contains('signal')) {
        final match = RegExp(r'(\d+)%').firstMatch(line);
        if (match != null) {
          signalStrength = int.parse(match.group(1)!);
        }
      } else if (line.toLowerCase().contains('authentication')) {
        final match = RegExp(r':\s*(.+)').firstMatch(line);
        if (match != null) {
          authType = match.group(1)?.trim() ?? '';
        }

        if (currentSSID != null && currentSSID.isNotEmpty) {
          networks.add(WiFiNetwork(
            ssid: currentSSID,
            bssid: currentBSSID ?? '',
            signalStrength: signalStrength,
            securityType: WiFiNetwork.parseSecurityType(authType),
            location: WiFiNetwork.detectLocation(currentSSID),
          ));
          currentSSID = null;
          currentBSSID = null;
          signalStrength = 0;
          authType = '';
        }
      }
    }

    final uniqueNetworks = <String, WiFiNetwork>{};
    for (final network in networks) {
      if (!uniqueNetworks.containsKey(network.ssid) ||
          network.signalStrength > uniqueNetworks[network.ssid]!.signalStrength) {
        uniqueNetworks[network.ssid] = network;
      }
    }

    return uniqueNetworks.values.toList();
  }

  Future<String?> getCurrentSSID() async {
    try {
      final result = await Process.run(
        'netsh',
        ['wlan', 'show', 'interfaces'],
        stdoutEncoding: const SystemEncoding(),
      );

      final stdout = result.stdout as String;
      final stderr = result.stderr as String;

      // Check for location permission error
      if (_isLocationPermissionError(stdout) || _isLocationPermissionError(stderr)) {
        throw LocationPermissionException();
      }

      if (result.exitCode != 0) return null;

      final lines = stdout.split('\n');
      
      for (final line in lines) {
        if (line.trim().startsWith('SSID') && !line.contains('BSSID')) {
          final match = RegExp(r'SSID\s*:\s*(.+)').firstMatch(line);
          if (match != null) {
            return match.group(1)?.trim();
          }
        }
      }
      
      return null;
    } on LocationPermissionException {
      rethrow;
    } catch (e) {
      return null;
    }
  }

  Future<ConnectionResult> connectToNetwork(String ssid, String username, String password) async {
    final networks = await scanNetworks();
    final network = networks.firstWhereOrNull((n) => n.ssid == ssid);

    if (network == null) return ConnectionResult.networkNotFound;

    if (network.isEnterprise) {
      // For enterprise networks, just try to connect
      // Windows will use cached credentials if available
      final connected = await _connectEnterpriseSimple(ssid);
      if (connected) {
        return ConnectionResult.success;
      } else {
        // Connection failed - user needs to enter credentials manually
        return ConnectionResult.enterpriseNeedsCredentials;
      }
    } else if (network.isOpen) {
      final connected = await _connectOpen(ssid);
      if (connected) {
        await Future.delayed(const Duration(seconds: 2));
        final portalSuccess = await _loginCaptivePortal(network.location, username, password);
        return portalSuccess ? ConnectionResult.success : ConnectionResult.failed;
      }
      return ConnectionResult.failed;
    } else {
      final connected = await _connectWPA(ssid, password);
      return connected ? ConnectionResult.success : ConnectionResult.failed;
    }
  }

  /// Simple enterprise connection - just try to connect
  /// Windows will use cached credentials if available
  Future<bool> _connectEnterpriseSimple(String ssid) async {
    try {
      // Just try to connect - Windows will use cached credentials if available
      final result = await Process.run(
        'netsh',
        ['wlan', 'connect', 'name=$ssid'],
      );

      if (result.exitCode != 0) {
        // Profile might not exist, try to add a basic one first
        final profileXml = '''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$ssid</name>
  <SSIDConfig>
    <SSID>
      <name>$ssid</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>WPA2</authentication>
        <encryption>AES</encryption>
        <useOneX>true</useOneX>
      </authEncryption>
    </security>
  </MSM>
</WLANProfile>''';

        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/wifi_profile_$ssid.xml');
        await tempFile.writeAsString(profileXml);

        await Process.run(
          'netsh',
          ['wlan', 'add', 'profile', 'filename=${tempFile.path}'],
        );

        await tempFile.delete();

        // Try connecting again
        await Process.run(
          'netsh',
          ['wlan', 'connect', 'name=$ssid'],
        );
      }

      // Wait for connection to establish
      await Future.delayed(const Duration(seconds: 4));

      // Check if connected to the network
      final currentSSID = await getCurrentSSID();
      if (currentSSID != ssid) {
        return false;
      }

      // Check if we have internet access
      final hasInternet = await checkInternet();
      return hasInternet;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _connectOpen(String ssid) async {
    final profileXml = '''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$ssid</name>
  <SSIDConfig>
    <SSID>
      <name>$ssid</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>open</authentication>
        <encryption>none</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
    </security>
  </MSM>
</WLANProfile>''';

    return await _addProfileAndConnect(ssid, profileXml);
  }

  Future<bool> _connectWPA(String ssid, String password) async {
    final profileXml = '''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$ssid</name>
  <SSIDConfig>
    <SSID>
      <name>$ssid</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>WPA2PSK</authentication>
        <encryption>AES</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
      <sharedKey>
        <keyType>passPhrase</keyType>
        <protected>false</protected>
        <keyMaterial>$password</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>''';

    return await _addProfileAndConnect(ssid, profileXml);
  }

  Future<bool> _addProfileAndConnect(String ssid, String profileXml) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/wifi_profile_$ssid.xml');
      await tempFile.writeAsString(profileXml);

      var result = await Process.run(
        'netsh',
        ['wlan', 'add', 'profile', 'filename=${tempFile.path}'],
      );

      await tempFile.delete();

      if (result.exitCode != 0) return false;

      result = await Process.run(
        'netsh',
        ['wlan', 'connect', 'name=$ssid'],
      );

      if (result.exitCode != 0) return false;

      await Future.delayed(const Duration(seconds: 3));

      final currentSSID = await getCurrentSSID();
      return currentSSID == ssid;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _loginCaptivePortal(NetworkLocation location, String username, String password) async {
    final storage = StorageService();
    await storage.init();
    final settings = await storage.getSettings();

    if (location == NetworkLocation.campus) {
      return await _loginCampus(settings['campus_endpoint'] ?? 'https://172.18.10.10:1000', username, password);
    } else if (location == NetworkLocation.hostel) {
      return await _loginHostel(settings['hostel_endpoint'] ?? 'https://hfw.vitap.ac.in:8090/login.xml', username, password);
    }

    return false;
  }

  Future<bool> _loginCampus(String endpoint, String username, String password) async {
    try {
      HttpOverrides.global = MyHttpOverrides();
      
      final client = http.Client();
      
      final magicResponse = await client.get(
        Uri.parse('$endpoint/login?'),
      ).timeout(const Duration(seconds: 10));

      final magicMatch = RegExp(r'name="magic" value="([^"]+)"')
          .firstMatch(magicResponse.body);
      
      if (magicMatch == null) {
        client.close();
        return false;
      }
      
      final magic = magicMatch.group(1)!;

      var response = await client.post(
        Uri.parse('$endpoint/login?'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: '4Tredir=$endpoint/login?&magic=$magic&username=$username&password=$password',
      ).timeout(const Duration(seconds: 10));

      if (response.body.contains('keepalive')) {
        client.close();
        return true;
      }

      if (response.body.contains('concurrent')) {
        final variantUsername = _addShyToDigits(username);
        
        final newMagicResponse = await client.get(Uri.parse('$endpoint/login?'));
        final newMagicMatch = RegExp(r'name="magic" value="([^"]+)"')
            .firstMatch(newMagicResponse.body);
        
        if (newMagicMatch == null) {
          client.close();
          return false;
        }

        response = await client.post(
          Uri.parse('$endpoint/login?'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: '4Tredir=$endpoint/login?&magic=${newMagicMatch.group(1)!}&username=$variantUsername&password=$password',
        ).timeout(const Duration(seconds: 10));

        client.close();
        return response.body.contains('keepalive');
      }

      client.close();
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _loginHostel(String endpoint, String username, String password) async {
    try {
      HttpOverrides.global = MyHttpOverrides();
      
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final payload = 'mode=191&username=$username&password=$password&a=$epoch&producttype=2';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: payload,
      ).timeout(const Duration(seconds: 10));

      return RegExp(r'Y.+}').hasMatch(response.body);
    } catch (e) {
      return false;
    }
  }

  String _addShyToDigits(String username) {
    final buffer = StringBuffer();
    for (final char in username.split('')) {
      buffer.write(char);
      if (RegExp(r'\d').hasMatch(char)) {
        buffer.write(shyChar);
      }
    }
    return buffer.toString();
  }

  Future<bool> disconnect() async {
    try {
      final result = await Process.run('netsh', ['wlan', 'disconnect']);
      if (result.exitCode != 0) return false;
      
      // Wait a moment for disconnection to complete
      await Future.delayed(const Duration(seconds: 1));
      
      // Verify disconnection
      final currentSSID = await getCurrentSSID();
      return currentSSID == null || currentSSID.isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkInternet() async {
    try {
      final result = await http.get(
        Uri.parse('http://connectivitycheck.gstatic.com/generate_204'),
      ).timeout(const Duration(seconds: 5));
      return result.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<void> autoConnect(StorageService storage) async {
    final credentials = await storage.getCredentials();
    if (credentials == null) return;

    final networks = await scanNetworks();
    
    for (final preferredSSID in [...enterpriseSSIDs, ...campusSSIDs, ...hostelSSIDs]) {
      final network = networks.firstWhereOrNull((n) => n.ssid == preferredSSID);
      if (network != null) {
        await connectToNetwork(
          network.ssid,
          credentials['username']!,
          credentials['password']!,
        );
        break;
      }
    }
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
