enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  authenticating,
  authenticated,
  disconnecting,
  failed,
  noInternet,
}

extension ConnectionStatusExtension on ConnectionStatus {
  String get displayText {
    switch (this) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.authenticating:
        return 'Authenticating...';
      case ConnectionStatus.authenticated:
        return 'Authenticated ✓';
      case ConnectionStatus.disconnecting:
        return 'Disconnecting...';
      case ConnectionStatus.failed:
        return 'Connection Failed';
      case ConnectionStatus.noInternet:
        return 'No Internet';
    }
  }

  String get icon {
    switch (this) {
      case ConnectionStatus.disconnected:
        return '⚪';
      case ConnectionStatus.connecting:
      case ConnectionStatus.authenticating:
      case ConnectionStatus.disconnecting:
        return '🟡';
      case ConnectionStatus.connected:
      case ConnectionStatus.authenticated:
        return '🟢';
      case ConnectionStatus.failed:
      case ConnectionStatus.noInternet:
        return '🔴';
    }
  }
}
