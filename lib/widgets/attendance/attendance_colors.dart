import 'package:flutter/material.dart';

/// Color palette for attendance widgets, inspired by vitap-mate
class AttendanceColors {
  // Percentage-based status colors
  static const Color excellentText = Color(0xFF2E7D32);
  static const Color excellentBackground = Color(0xFFE8F5E8);
  static const Color excellentBorder = Color(0xFF81C784);
  
  static const Color goodText = Color(0xFF1976D2);
  static const Color goodBackground = Color(0xFFE3F2FD);
  static const Color goodBorder = Color(0xFF64B5F6);
  
  static const Color warningText = Color(0xFFE65100);
  static const Color warningBackground = Color(0xFFFFF3E0);
  static const Color warningBorder = Color(0xFFFFB74D);
  
  static const Color criticalText = Color(0xFFD32F2F);
  static const Color criticalBackground = Color(0xFFFFEBEE);
  static const Color criticalBorder = Color(0xFFE57373);
  
  // Card backgrounds for course types
  static const Color theoryCardBackground = Color(0xFFC6E7FF);
  static const Color theoryCardSecondary = Color(0xFFB3DDFF);
  static const Color labCardBackground = Color(0xFFD4F6FF);
  static const Color labCardSecondary = Color(0xFFC1F2FF);
  
  // Dark mode card backgrounds
  static const Color darkTheoryCardBackground = Color(0xFF1E3A5F);
  static const Color darkLabCardBackground = Color(0xFF1E4D5F);
  static const Color darkCardBackground = Color(0xFF1E1E2E);
  
  // Icon colors
  static const Color theoryIcon = Color(0xFF2196F3);
  static const Color labIcon = Color(0xFF00BCD4);
  
  // Stat colors
  static const Color presentColor = Color(0xFF4CAF50);
  static const Color absentColor = Color(0xFFF44336);
  static const Color totalColor = Color(0xFF2196F3);
  
  /// Get status colors based on percentage
  static (Color, Color, Color) getStatusColors(double percentage) {
    if (percentage >= 75) {
      return (excellentText, excellentBackground, excellentBorder);
    } else if (percentage >= 70) {
      return (goodText, goodBackground, goodBorder);
    } else if (percentage >= 60) {
      return (warningText, warningBackground, warningBorder);
    } else {
      return (criticalText, criticalBackground, criticalBorder);
    }
  }
  
  /// Get card gradient colors based on course type
  static List<Color> getCardGradient(bool isLab, bool isDark) {
    if (isDark) {
      return isLab 
          ? [darkLabCardBackground, darkLabCardBackground.withOpacity(0.8)]
          : [darkTheoryCardBackground, darkTheoryCardBackground.withOpacity(0.8)];
    }
    return isLab 
        ? [labCardBackground, labCardSecondary]
        : [theoryCardBackground, theoryCardSecondary];
  }
}
