enum NetworkType { open, wpa2Personal, wpa2Enterprise, wpa3Enterprise, unknown }

enum NetworkLocation { campus, hostel, enterprise, unknown }

class WiFiNetwork {
  final String ssid;
  final String bssid;
  final int signalStrength;
  final NetworkType securityType;
  final NetworkLocation location;
  final bool isConnected;

  WiFiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
    required this.securityType,
    required this.location,
    this.isConnected = false,
  });

  static NetworkLocation detectLocation(String ssid) {
    final lowerSSID = ssid.toLowerCase();
    
    if (lowerSSID.contains('vit2.4g') || lowerSSID.contains('vit5g')) {
      return NetworkLocation.campus;
    }
    
    if (lowerSSID.contains('mh6') || 
        lowerSSID.contains('mh-6') ||
        lowerSSID.contains('lh-3') ||
        lowerSSID.contains('lh3')) {
      return NetworkLocation.campus;
    }
    
    if (lowerSSID.contains('mh4') || 
        lowerSSID.contains('mh-4') ||
        lowerSSID.contains('lh-1') ||
        lowerSSID.contains('lh1') ||
        lowerSSID.contains('mh-2') ||
        lowerSSID.contains('mh2') ||
        lowerSSID.contains('mh-5') ||
        lowerSSID.contains('mh5')) {
      return NetworkLocation.hostel;
    }

    if (lowerSSID.contains('mh6-wifi') || lowerSSID.contains('vit-enterprise')) {
      return NetworkLocation.enterprise;
    }
    
    return NetworkLocation.unknown;
  }

  static NetworkType parseSecurityType(String authType) {
    final lower = authType.toLowerCase();
    
    if (lower.contains('open')) {
      return NetworkType.open;
    }
    if (lower.contains('wpa3') && lower.contains('enterprise')) {
      return NetworkType.wpa3Enterprise;
    }
    if (lower.contains('wpa2') && lower.contains('enterprise')) {
      return NetworkType.wpa2Enterprise;
    }
    if (lower.contains('wpa2') || lower.contains('wpa')) {
      return NetworkType.wpa2Personal;
    }
    
    return NetworkType.unknown;
  }

  bool get isEnterprise => 
      securityType == NetworkType.wpa2Enterprise || 
      securityType == NetworkType.wpa3Enterprise;

  bool get isOpen => securityType == NetworkType.open;

  String get signalIcon {
    if (signalStrength > 75) return '📶';
    if (signalStrength > 50) return '📶';
    if (signalStrength > 25) return '📶';
    return '📶';
  }

  String get securityIcon {
    if (isOpen) return '🔓';
    return '🔒';
  }
}
