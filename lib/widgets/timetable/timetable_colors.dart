import 'package:flutter/material.dart';

/// Color scheme for timetable UI elements, inspired by vitap-mate
class TimetableColors {
  // Card backgrounds
  static const Color freeTimeBackground = Color(0xFFFFE8CD);
  static const Color lectureBackground = Color(0xFFC6E7FF);
  static const Color labBackground = Color(0xFFD4F6FF);

  // Status borders
  static const Color ongoingBorder = Color(0xFF4CAF50);
  static const Color completedBorder = Color(0xFF9E9E9E);
  static const Color upcomingBorder = Color(0xFF2196F3);
  static const Color nextClassBorder = Color(0xFFFF9800);
  static const Color notTodayBorder = Color(0xFF5619B7);

  // Status backgrounds
  static const Color ongoingBackground = Color(0xFFE8F5E8);
  static const Color completedBackground = Color(0xFFF5F5F5);
  static const Color upcomingBackground = Color(0xFFE3F2FD);
  static const Color nextClassBackground = Color(0xFFFFF3E0);
  static const Color notTodayBackground = Color(0xFFE3F2FD);

  // Status text colors
  static const Color ongoingText = Color(0xFF2E7D32);
  static const Color completedText = Color(0xFF616161);
  static const Color upcomingText = Color(0xFF1976D2);
  static const Color nextClassText = Color(0xFFE65100);
  static const Color notTodayText = Color(0xFF6319D2);

  // General
  static const Color cardShadow = Color(0x1A000000);
  static const Color statusShadow = Color(0x0D000000);
  static const Color freeTimeIcon = Color(0xFFE65100);
  static const Color lectureIcon = Color(0xFF1565C0);
  static const Color labIcon = Color(0xFF0277BD);
  static const Color chipBackground = Color(0xFFE8F4FD);
  static const Color labChipBackground = Color(0xFFE1F5FE);

  // Dark mode variants
  static const Color darkCardBackground = Color(0xFF1E1E1E);
  static const Color darkChipBackground = Color(0xFF2D2D2D);
}
