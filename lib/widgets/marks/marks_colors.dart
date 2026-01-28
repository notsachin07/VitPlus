import 'package:flutter/material.dart';

/// Color palette for marks widgets
class MarksColors {
  // Score-based status colors
  static const Color excellentText = Color(0xFF2E7D32);
  static const Color excellentBackground = Color(0xFFE8F5E8);
  static const Color excellentBorder = Color(0xFF81C784);
  
  static const Color goodText = Color(0xFF1976D2);
  static const Color goodBackground = Color(0xFFE3F2FD);
  static const Color goodBorder = Color(0xFF64B5F6);
  
  static const Color averageText = Color(0xFFE65100);
  static const Color averageBackground = Color(0xFFFFF3E0);
  static const Color averageBorder = Color(0xFFFFB74D);
  
  static const Color lowText = Color(0xFFD32F2F);
  static const Color lowBackground = Color(0xFFFFEBEE);
  static const Color lowBorder = Color(0xFFE57373);
  
  // Card backgrounds for course types
  static const Color theoryCardBackground = Color(0xFFE8EAF6);  // Indigo light
  static const Color theoryCardSecondary = Color(0xFFD1D9FF);
  static const Color labCardBackground = Color(0xFFE0F7FA);     // Cyan light
  static const Color labCardSecondary = Color(0xFFB2EBF2);
  
  // Dark mode card backgrounds
  static const Color darkTheoryCardBackground = Color(0xFF1A237E);
  static const Color darkLabCardBackground = Color(0xFF006064);
  static const Color darkCardBackground = Color(0xFF1E1E2E);
  
  // Component type colors
  static const Color catColor = Color(0xFF5C6BC0);      // Indigo
  static const Color fatColor = Color(0xFFAB47BC);      // Purple
  static const Color quizColor = Color(0xFF26A69A);     // Teal
  static const Color assignmentColor = Color(0xFFFF7043); // Deep Orange
  static const Color labColor = Color(0xFF42A5F5);      // Blue
  static const Color projectColor = Color(0xFFEC407A);  // Pink
  static const Color defaultColor = Color(0xFF78909C); // Blue Grey
  
  /// Get status colors based on score percentage
  static (Color, Color, Color) getStatusColors(double percentage) {
    if (percentage >= 80) {
      return (excellentText, excellentBackground, excellentBorder);
    } else if (percentage >= 60) {
      return (goodText, goodBackground, goodBorder);
    } else if (percentage >= 40) {
      return (averageText, averageBackground, averageBorder);
    } else {
      return (lowText, lowBackground, lowBorder);
    }
  }
  
  /// Get color for a component type
  static Color getComponentColor(String componentName) {
    final lower = componentName.toLowerCase();
    if (lower.contains('cat') || lower.contains('continuous')) {
      return catColor;
    } else if (lower.contains('fat') || lower.contains('final')) {
      return fatColor;
    } else if (lower.contains('quiz')) {
      return quizColor;
    } else if (lower.contains('assignment') || lower.contains('da')) {
      return assignmentColor;
    } else if (lower.contains('lab') || lower.contains('practical')) {
      return labColor;
    } else if (lower.contains('project')) {
      return projectColor;
    }
    return defaultColor;
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
