import 'package:flutter/material.dart';
import '../models/connection_status.dart';
import '../theme/app_theme.dart';

class StatusIndicator extends StatelessWidget {
  final ConnectionStatus status;

  const StatusIndicator({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor()),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading())
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(_getTextColor()),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getDotColor(),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            status.displayText,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _getTextColor(),
            ),
          ),
        ],
      ),
    );
  }

  bool _isLoading() {
    return status == ConnectionStatus.connecting ||
        status == ConnectionStatus.authenticating ||
        status == ConnectionStatus.disconnecting;
  }

  Color _getBackgroundColor() {
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.authenticated:
        return AppTheme.successGreen.withOpacity(0.15);
      case ConnectionStatus.connecting:
      case ConnectionStatus.authenticating:
      case ConnectionStatus.disconnecting:
        return AppTheme.warningOrange.withOpacity(0.15);
      case ConnectionStatus.failed:
      case ConnectionStatus.noInternet:
        return AppTheme.errorRed.withOpacity(0.15);
      case ConnectionStatus.disconnected:
        return Colors.grey.withOpacity(0.15);
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.authenticated:
        return AppTheme.successGreen.withOpacity(0.3);
      case ConnectionStatus.connecting:
      case ConnectionStatus.authenticating:
      case ConnectionStatus.disconnecting:
        return AppTheme.warningOrange.withOpacity(0.3);
      case ConnectionStatus.failed:
      case ConnectionStatus.noInternet:
        return AppTheme.errorRed.withOpacity(0.3);
      case ConnectionStatus.disconnected:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getDotColor() {
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.authenticated:
        return AppTheme.successGreen;
      case ConnectionStatus.connecting:
      case ConnectionStatus.authenticating:
      case ConnectionStatus.disconnecting:
        return AppTheme.warningOrange;
      case ConnectionStatus.failed:
      case ConnectionStatus.noInternet:
        return AppTheme.errorRed;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  Color _getTextColor() {
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.authenticated:
        return AppTheme.successGreen;
      case ConnectionStatus.connecting:
      case ConnectionStatus.authenticating:
      case ConnectionStatus.disconnecting:
        return AppTheme.warningOrange;
      case ConnectionStatus.failed:
      case ConnectionStatus.noInternet:
        return AppTheme.errorRed;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }
}
