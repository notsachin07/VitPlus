import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vtop_models.dart';
import 'timetable_colors.dart';

/// Enum to represent the status of a class
enum ClassStatus { completed, ongoing, upcoming, nextClass, notToday }

/// A beautifully designed timetable card widget inspired by vitap-mate
class TimetableCard extends ConsumerStatefulWidget {
  final TimetableSlot slot;
  final bool isFreeSlot;

  const TimetableCard({
    super.key,
    required this.slot,
    this.isFreeSlot = false,
  });

  @override
  ConsumerState<TimetableCard> createState() => _TimetableCardState();
}

class _TimetableCardState extends ConsumerState<TimetableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ClassStatus getClassStatus() {
    if (widget.isFreeSlot) return ClassStatus.upcoming;
    
    final now = DateTime.now();
    final currentTime = Duration(hours: now.hour, minutes: now.minute);

    Duration parseTime(String timeStr) {
      if (timeStr.isEmpty) return Duration.zero;
      final parts = timeStr.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length < 2) return Duration.zero;
      return Duration(hours: parts[0], minutes: parts[1]);
    }

    const weekdayMap = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    final startTime = parseTime(widget.slot.startTime);
    final endTime = parseTime(widget.slot.endTime);
    final classWeekday = weekdayMap[widget.slot.day.toLowerCase()];
    final nextClassThreshold = currentTime + const Duration(minutes: 50);

    if (classWeekday != now.weekday) {
      return ClassStatus.notToday;
    }
    if (currentTime >= startTime && currentTime <= endTime) {
      return ClassStatus.ongoing;
    } else if (currentTime > endTime) {
      return ClassStatus.completed;
    } else if (nextClassThreshold >= startTime && nextClassThreshold <= endTime) {
      return ClassStatus.nextClass;
    } else {
      return ClassStatus.upcoming;
    }
  }

  Color getCardBackgroundColor(bool isDark) {
    if (isDark) return TimetableColors.darkCardBackground;
    if (widget.isFreeSlot) return TimetableColors.freeTimeBackground;
    return widget.slot.isLab
        ? TimetableColors.labBackground
        : TimetableColors.lectureBackground;
  }

  (Color border, Color background, Color text, String label) getStatusStyle(
    ClassStatus status,
  ) {
    switch (status) {
      case ClassStatus.ongoing:
        return (
          TimetableColors.ongoingBorder,
          TimetableColors.ongoingBackground,
          TimetableColors.ongoingText,
          'ONGOING',
        );
      case ClassStatus.completed:
        return (
          TimetableColors.completedBorder,
          TimetableColors.completedBackground,
          TimetableColors.completedText,
          'COMPLETED',
        );
      case ClassStatus.nextClass:
        return (
          TimetableColors.nextClassBorder,
          TimetableColors.nextClassBackground,
          TimetableColors.nextClassText,
          'NEXT CLASS',
        );
      case ClassStatus.upcoming:
        return (
          TimetableColors.upcomingBorder,
          TimetableColors.upcomingBackground,
          TimetableColors.upcomingText,
          'UPCOMING',
        );
      case ClassStatus.notToday:
        return (
          TimetableColors.notTodayBorder,
          TimetableColors.notTodayBackground,
          TimetableColors.notTodayText,
          'NOT TODAY',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = widget.isFreeSlot ? null : getClassStatus();
    final statusStyle = status != null ? getStatusStyle(status) : null;
    final isHighlighted = status == ClassStatus.ongoing || status == ClassStatus.nextClass;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
          _isExpanded ? _controller.forward() : _controller.reverse();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: getCardBackgroundColor(isDark),
            borderRadius: BorderRadius.circular(12),
            border: statusStyle != null && isHighlighted
                ? Border.all(color: statusStyle.$1, width: 2)
                : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: isHighlighted
                          ? TimetableColors.statusShadow
                          : TimetableColors.cardShadow,
                      blurRadius: isHighlighted ? 8 : 6,
                      offset: const Offset(0, 2),
                      spreadRadius: isHighlighted ? 1 : 0,
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: widget.isFreeSlot
                ? _buildFreeTimeCard(isDark)
                : _buildClassCard(isDark, statusStyle),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(
    bool isDark,
    (Color, Color, Color, String)? statusStyle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.slot.isLab
                    ? TimetableColors.labChipBackground
                    : TimetableColors.chipBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.slot.isLab ? Icons.science : Icons.menu_book,
                    size: 16,
                    color: widget.slot.isLab
                        ? TimetableColors.labIcon
                        : TimetableColors.lectureIcon,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.slot.isLab ? 'LAB' : 'LECTURE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.slot.isLab
                          ? TimetableColors.labIcon
                          : TimetableColors.lectureIcon,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (statusStyle != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusStyle.$2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusStyle.$1, width: 1),
                ),
                child: Text(
                  statusStyle.$4,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusStyle.$3,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Course Name (Title)
        Text(
          widget.slot.courseName.isNotEmpty 
              ? widget.slot.courseName 
              : widget.slot.courseCode,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Faculty Name
        if (widget.slot.faculty.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatFacultyName(widget.slot.faculty),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // Location and Course Code Row
        Row(
          children: [
            Expanded(
              child: _buildDetailChip(
                isDark,
                icon: Icons.location_on_outlined,
                text: widget.slot.venue.isNotEmpty 
                    ? widget.slot.venue 
                    : widget.slot.block,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 8),
            _buildDetailChip(
              isDark,
              icon: Icons.tag,
              text: widget.slot.courseCode,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Time and Slot Row
        Row(
          children: [
            Expanded(
              child: _buildDetailChip(
                isDark,
                icon: Icons.access_time,
                text: '${_to12H(widget.slot.startTime)} - ${_to12H(widget.slot.endTime)}',
                color: isDark ? Colors.white : const Color(0xFF374151),
                isBold: true,
              ),
            ),
            const SizedBox(width: 8),
            _buildDetailChip(
              isDark,
              icon: Icons.calendar_today,
              text: widget.slot.slotName,
              color: isDark ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ],
        ),

        // Expandable Course Type Section
        SizeTransition(
          sizeFactor: _animation,
          axisAlignment: -1.0,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailChip(
                      isDark,
                      icon: Icons.school_outlined,
                      text: widget.slot.courseType.isNotEmpty 
                          ? widget.slot.courseType 
                          : (widget.slot.isLab ? 'Lab' : 'Theory'),
                      color: isDark ? Colors.white : const Color(0xFF374151),
                      isBold: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFreeTimeCard(bool isDark) {
    // Get gap hours from slotName (calculated using floor division by 60)
    final gapHours = int.tryParse(widget.slot.slotName) ?? 0;
    final hourText = gapHours == 1 ? '1 hour gap' : '$gapHours hours gap';
    
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty, size: 16, color: Color(0xFFE65100)),
                  SizedBox(width: 4),
                  Text(
                    'FREE TIME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildDetailChip(
                isDark,
                icon: Icons.access_time,
                text: '${_to12H(widget.slot.startTime)} - ${_to12H(widget.slot.endTime)}',
                color: isDark ? Colors.white : const Color(0xFF374151),
                isBold: true,
              ),
            ),
            const SizedBox(width: 8),
            _buildDetailChip(
              isDark,
              icon: Icons.timer_outlined,
              text: hourText,
              color: TimetableColors.freeTimeIcon,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip(
    bool isDark, {
    required IconData icon,
    required String text,
    required Color color,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text.isEmpty ? '-' : text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _to12H(String time) {
    if (time.isEmpty) return '-';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    
    int hours = int.tryParse(parts[0]) ?? 0;
    final minutes = parts[1];
    String period;

    if (hours > 12) {
      hours -= 12;
      period = 'PM';
    } else if (hours == 12) {
      period = 'PM';
    } else if (hours == 0) {
      hours = 12;
      period = 'AM';
    } else {
      period = 'AM';
    }

    return '$hours:$minutes $period';
  }

  String _formatFacultyName(String value) {
    if (value.isEmpty) return 'Unknown Faculty';
    try {
      const delimiter = '-';
      final lastIndex = value.lastIndexOf(delimiter);
      if (lastIndex > 0) {
        return value.substring(0, lastIndex).trim();
      }
      return value;
    } catch (_) {
      return value;
    }
  }

  int _calculateDuration() {
    if (widget.slot.startTime.isEmpty || widget.slot.endTime.isEmpty) {
      return 0;
    }
    
    Duration parseTime(String timeStr) {
      final parts = timeStr.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      if (parts.length < 2) return Duration.zero;
      return Duration(hours: parts[0], minutes: parts[1]);
    }
    
    final start = parseTime(widget.slot.startTime);
    final end = parseTime(widget.slot.endTime);
    return (end - start).inMinutes;
  }
}
