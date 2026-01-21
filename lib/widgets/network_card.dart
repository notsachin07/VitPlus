import 'package:flutter/material.dart';
import '../models/wifi_network.dart';
import '../theme/app_theme.dart';

class NetworkCard extends StatelessWidget {
  final WiFiNetwork network;
  final bool isSelected;
  final bool isConnected;
  final VoidCallback onTap;

  const NetworkCard({
    super.key,
    required this.network,
    required this.isSelected,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue.withOpacity(0.1)
                  : (isDark ? AppTheme.darkBg : AppTheme.lightBg),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryBlue
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                _buildSignalIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              network.ssid,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.successGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Connected',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildLocationBadge(),
                          const SizedBox(width: 8),
                          _buildSecurityBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignalIcon() {
    Color color;
    if (network.signalStrength > 75) {
      color = AppTheme.successGreen;
    } else if (network.signalStrength > 50) {
      color = AppTheme.accentGold;
    } else if (network.signalStrength > 25) {
      color = AppTheme.warningOrange;
    } else {
      color = AppTheme.errorRed;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.wifi,
        color: color,
        size: 22,
      ),
    );
  }

  Widget _buildLocationBadge() {
    String text;
    Color color;

    switch (network.location) {
      case NetworkLocation.campus:
        text = 'Campus';
        color = AppTheme.primaryBlue;
        break;
      case NetworkLocation.hostel:
        text = 'Hostel';
        color = AppTheme.accentGold;
        break;
      case NetworkLocation.enterprise:
        text = 'Enterprise';
        color = Colors.purple;
        break;
      default:
        text = 'Other';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    String text;
    IconData icon;

    if (network.isOpen) {
      text = 'Open';
      icon = Icons.lock_open;
    } else if (network.isEnterprise) {
      text = 'Enterprise';
      icon = Icons.security;
    } else {
      text = 'Secured';
      icon = Icons.lock;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
