import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vtop_provider.dart';
import '../models/vtop_models.dart';
import '../theme/app_theme.dart';
import '../widgets/exam/exam_card.dart';
import '../widgets/exam/exam_colors.dart';

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

    return RefreshIndicator(
      onRefresh: () => ref.read(vtopProvider.notifier).fetchExamSchedule(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: examGroups.length,
        itemBuilder: (context, index) {
          final group = examGroups[index];
          return _buildExamTypeSection(isDark, group.examType, group.exams);
        },
      ),
    );
  }

  Widget _buildExamTypeSection(bool isDark, String examType, List<ExamSlot> exams) {
    // Sort exams by date
    final sortedExams = List<ExamSlot>.from(exams);
    sortedExams.sort((a, b) => a.examDate.compareTo(b.examDate));
    final examColor = ExamColors.getExamTypeColor(examType);
    
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
                  gradient: LinearGradient(
                    colors: [examColor, examColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: examColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
        ...sortedExams.map((exam) => ExamCard(exam: exam, examType: examType)),
        const SizedBox(height: 16),
      ],
    );
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
