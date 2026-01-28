import 'package:flutter/material.dart';

/// Color palette for exam schedule widgets
class ExamColors {
  // Exam type colors
  static const Color fatColor = Color(0xFFD32F2F);       // Red for FAT
  static const Color catColor = Color(0xFFFF9800);       // Orange for CAT
  static const Color midtermColor = Color(0xFF9C27B0);   // Purple for midterm
  static const Color quizColor = Color(0xFF2196F3);      // Blue for quiz
  static const Color labColor = Color(0xFF00BCD4);       // Cyan for lab exam
  static const Color defaultColor = Color(0xFF607D8B);   // Blue Grey for others
  
  // Status colors
  static const Color upcomingText = Color(0xFF1976D2);
  static const Color upcomingBackground = Color(0xFFE3F2FD);
  static const Color upcomingBorder = Color(0xFF64B5F6);
  
  static const Color todayText = Color(0xFFD32F2F);
  static const Color todayBackground = Color(0xFFFFEBEE);
  static const Color todayBorder = Color(0xFFE57373);
  
  static const Color pastText = Color(0xFF757575);
  static const Color pastBackground = Color(0xFFF5F5F5);
  static const Color pastBorder = Color(0xFFBDBDBD);
  
  // Card backgrounds
  static const Color cardBackground = Color(0xFFFAFAFA);
  static const Color darkCardBackground = Color(0xFF2D2D3D);
  
  /// Get exam type color
  static Color getExamTypeColor(String examType) {
    final lower = examType.toLowerCase();
    if (lower.contains('fat') || lower.contains('final')) {
      return fatColor;
    } else if (lower.contains('cat') || lower.contains('continuous')) {
      return catColor;
    } else if (lower.contains('mid') || lower.contains('term')) {
      return midtermColor;
    } else if (lower.contains('quiz')) {
      return quizColor;
    } else if (lower.contains('lab') || lower.contains('practical')) {
      return labColor;
    }
    return defaultColor;
  }
  
  /// Get status colors based on exam date
  static (Color, Color, Color) getStatusColors(DateTime examDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    
    if (examDay.isBefore(today)) {
      return (pastText, pastBackground, pastBorder);
    } else if (examDay.isAtSameMomentAs(today)) {
      return (todayText, todayBackground, todayBorder);
    } else {
      return (upcomingText, upcomingBackground, upcomingBorder);
    }
  }
}
