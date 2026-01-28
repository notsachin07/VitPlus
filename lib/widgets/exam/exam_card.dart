import 'package:flutter/material.dart';
import '../../models/vtop_models.dart';
import 'exam_colors.dart';

/// A beautifully designed exam card widget inspired by vitap-mate
class ExamCard extends StatelessWidget {
  final ExamSlot exam;
  final String examType;
  
  const ExamCard({
    super.key,
    required this.exam,
    required this.examType,
  });
  
  DateTime? _parseDate(String dateStr) {
    try {
      // Try common date formats
      final formats = [
        RegExp(r'(\d{2})/(\d{2})/(\d{4})'), // DD/MM/YYYY
        RegExp(r'(\d{2})-(\d{2})-(\d{4})'), // DD-MM-YYYY
        RegExp(r'(\d{4})-(\d{2})-(\d{2})'), // YYYY-MM-DD
      ];
      
      for (final format in formats) {
        final match = format.firstMatch(dateStr);
        if (match != null) {
          if (dateStr.contains('/') || dateStr.contains('-') && !dateStr.startsWith('20')) {
            // DD/MM/YYYY or DD-MM-YYYY
            return DateTime(
              int.parse(match.group(3)!),
              int.parse(match.group(2)!),
              int.parse(match.group(1)!),
            );
          } else {
            // YYYY-MM-DD
            return DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }
  
  bool get _isUpcoming {
    final date = _parseDate(exam.examDate);
    if (date == null) return false;
    return date.isAfter(DateTime.now().subtract(const Duration(days: 1)));
  }
  
  bool get _isToday {
    final date = _parseDate(exam.examDate);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  bool get _isPast {
    final date = _parseDate(exam.examDate);
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examTypeColor = ExamColors.getExamTypeColor(examType);
    
    // Determine status
    Color borderColor;
    Color? statusBgColor;
    String? statusText;
    
    if (_isToday) {
      borderColor = ExamColors.todayBorder;
      statusBgColor = ExamColors.todayBackground;
      statusText = 'TODAY';
    } else if (_isUpcoming) {
      borderColor = ExamColors.upcomingBorder;
      statusBgColor = null;
      statusText = null;
    } else {
      borderColor = ExamColors.pastBorder;
      statusBgColor = null;
      statusText = null;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? ExamColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: _isToday || _isUpcoming
            ? Border.all(color: borderColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: examTypeColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date box
                _buildDateBox(isDark, examTypeColor),
                const SizedBox(width: 16),
                
                // Exam details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      if (statusText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _isToday ? ExamColors.todayText : ExamColors.upcomingText,
                            ),
                          ),
                        ),
                      
                      // Course code and name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: examTypeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              exam.courseCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: examTypeColor,
                              ),
                            ),
                          ),
                          if (exam.courseType.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                exam.courseType,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Text(
                        exam.courseName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isPast 
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : const Color(0xFF1F2937)),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Time and venue info
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (exam.examTime.isNotEmpty)
                            _buildInfoChip(
                              Icons.access_time,
                              exam.examTime,
                              isDark,
                              examTypeColor,
                            ),
                          if (exam.examSession.isNotEmpty)
                            _buildInfoChip(
                              Icons.wb_sunny_outlined,
                              exam.examSession,
                              isDark,
                              examTypeColor,
                            ),
                          if (exam.venue.isNotEmpty)
                            _buildInfoChip(
                              Icons.location_on_outlined,
                              exam.venue,
                              isDark,
                              examTypeColor,
                            ),
                        ],
                      ),
                      
                      // Seat info
                      if (exam.seatNo.isNotEmpty || exam.seatLocation.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : examTypeColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: examTypeColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_seat,
                                size: 16,
                                color: examTypeColor,
                              ),
                              const SizedBox(width: 8),
                              if (exam.seatNo.isNotEmpty)
                                Text(
                                  'Seat: ${exam.seatNo}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                              if (exam.seatNo.isNotEmpty && exam.seatLocation.isNotEmpty)
                                const Text(' • '),
                              if (exam.seatLocation.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    exam.seatLocation,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Reporting time
                      if (exam.reportingTime.isNotEmpty && _isUpcoming) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: ExamColors.todayText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Report by: ${exam.reportingTime}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ExamColors.todayText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateBox(bool isDark, Color accentColor) {
    final date = _parseDate(exam.examDate);
    
    String day = '';
    String month = '';
    String weekday = '';
    
    if (date != null) {
      day = date.day.toString();
      month = _getMonthName(date.month);
      weekday = _getWeekdayName(date.weekday);
    } else {
      // Fallback: parse from string
      day = exam.examDate;
    }
    
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isPast
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [accentColor, accentColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (_isPast ? Colors.grey : accentColor).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          if (weekday.isNotEmpty)
            Text(
              weekday,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          Text(
            day,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (month.isNotEmpty)
            Text(
              month,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String text, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getMonthName(int month) {
    const months = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 
                    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month];
  }
  
  String _getWeekdayName(int weekday) {
    const days = ['', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday];
  }
}
