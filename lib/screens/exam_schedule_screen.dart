import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vtop_provider.dart';
import '../models/vtop_models.dart';
import '../theme/app_theme.dart';

class ExamScheduleScreen extends ConsumerStatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  ConsumerState<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends ConsumerState<ExamScheduleScreen> {
  @override
  void initState() {
    super.initState();
    // Load exam schedule if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vtopState = ref.read(vtopProvider);
      if (vtopState.examSchedule == null) {
        ref.read(vtopProvider.notifier).fetchExamSchedule();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vtopState = ref.watch(vtopProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Column(
        children: [
          _buildHeader(isDark, vtopState),
          Expanded(
            child: _buildExamScheduleContent(isDark, vtopState),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, VtopState vtopState) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 28,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exam Schedule',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (vtopState.selectedSemester != null)
                  Text(
                    vtopState.selectedSemester!.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          if (vtopState.isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(vtopProvider.notifier).fetchExamSchedule(),
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }

  Widget _buildExamScheduleContent(bool isDark, VtopState vtopState) {
    if (vtopState.error != null && vtopState.examSchedule == null) {
      return _buildErrorState(isDark, vtopState.error!);
    }

    if (vtopState.examSchedule == null) {
      if (vtopState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _buildEmptyState(isDark);
    }

    final examGroups = vtopState.examSchedule!.examGroups;
    if (examGroups.isEmpty) {
      return _buildNoExamsState(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: examGroups.length,
      itemBuilder: (context, index) {
        final group = examGroups[index];
        return _buildExamTypeSection(isDark, group.examType, group.exams);
      },
    );
  }

  Widget _buildExamTypeSection(bool isDark, String examType, List<ExamSlot> exams) {
    // Sort exams by date
    final sortedExams = List<ExamSlot>.from(exams);
    sortedExams.sort((a, b) => a.examDate.compareTo(b.examDate));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getExamTypeColor(examType),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  examType,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${exams.length} exam${exams.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        ...sortedExams.map((exam) => _buildExamCard(isDark, exam, examType)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildExamCard(bool isDark, ExamSlot exam, String examType) {
    final isUpcoming = _isUpcomingExam(exam.examDate);
    final isPast = _isPastExam(exam.examDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isUpcoming
            ? Border.all(color: AppTheme.primaryBlue, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date box
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isPast
                        ? (isDark ? Colors.white12 : Colors.black.withOpacity(0.05))
                        : _getExamTypeColor(examType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _getDayOfMonth(exam.examDate),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isPast
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : _getExamTypeColor(examType),
                        ),
                      ),
                      Text(
                        _getMonth(exam.examDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : _getExamTypeColor(examType),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Exam details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              exam.courseCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPast
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          if (exam.slot.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                exam.slot,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isPast
                                      ? (isDark ? Colors.white24 : Colors.black26)
                                      : (isDark ? Colors.white54 : Colors.black45),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isPast
                                ? (isDark ? Colors.white24 : Colors.black26)
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            exam.examTime.isNotEmpty ? exam.examTime : 'TBA',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPast
                                  ? (isDark ? Colors.white24 : Colors.black26)
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                          if (exam.venue.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: isPast
                                  ? (isDark ? Colors.white24 : Colors.black26)
                                  : (isDark ? Colors.white54 : Colors.black54),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                exam.venue,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPast
                                      ? (isDark ? Colors.white24 : Colors.black26)
                                      : (isDark ? Colors.white60 : Colors.black54),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUpcoming)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'UPCOMING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (isPast)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'COMPLETED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getExamTypeColor(String examType) {
    final type = examType.toUpperCase();
    if (type.contains('CAT1') || type.contains('CAT-1')) {
      return Colors.orange;
    } else if (type.contains('CAT2') || type.contains('CAT-2')) {
      return Colors.purple;
    } else if (type.contains('FAT') || type.contains('FINAL')) {
      return Colors.red;
    }
    return AppTheme.primaryBlue;
  }

  bool _isUpcomingExam(String dateStr) {
    try {
      // Try to parse date in common formats
      final now = DateTime.now();
      final examDate = _parseDate(dateStr);
      if (examDate == null) return false;

      // Upcoming = within next 7 days
      final diff = examDate.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    } catch (_) {
      return false;
    }
  }

  bool _isPastExam(String dateStr) {
    try {
      final now = DateTime.now();
      final examDate = _parseDate(dateStr);
      if (examDate == null) return false;
      return examDate.isBefore(now);
    } catch (_) {
      return false;
    }
  }

  DateTime? _parseDate(String dateStr) {
    // Try multiple formats
    final formats = [
      RegExp(r'(\d{2})/(\d{2})/(\d{4})'), // DD/MM/YYYY
      RegExp(r'(\d{2})-(\d{2})-(\d{4})'), // DD-MM-YYYY
      RegExp(r'(\d{4})-(\d{2})-(\d{2})'), // YYYY-MM-DD
    ];

    for (final format in formats) {
      final match = format.firstMatch(dateStr);
      if (match != null) {
        try {
          if (dateStr.contains('/') || dateStr.contains('-') && dateStr.indexOf('-') == 2) {
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
        } catch (_) {}
      }
    }
    return null;
  }

  String _getDayOfMonth(String dateStr) {
    final date = _parseDate(dateStr);
    if (date != null) {
      return date.day.toString().padLeft(2, '0');
    }
    // Try to extract just the day
    final match = RegExp(r'(\d{1,2})').firstMatch(dateStr);
    return match?.group(1) ?? '??';
  }

  String _getMonth(String dateStr) {
    final date = _parseDate(dateStr);
    if (date != null) {
      const months = [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ];
      return months[date.month - 1];
    }
    return '???';
  }

  Widget _buildNoExamsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: AppTheme.successGreen.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No exams scheduled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your free time!',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No exam schedule data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your VTOP credentials in Settings\nand tap refresh to load exam schedule',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(vtopProvider.notifier).fetchExamSchedule(),
            icon: const Icon(Icons.refresh),
            label: const Text('Load Schedule'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorRed.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load exam schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(vtopProvider.notifier).fetchExamSchedule(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
