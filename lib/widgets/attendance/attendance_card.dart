import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/vtop_models.dart';
import 'attendance_colors.dart';

/// A beautifully designed attendance card widget inspired by vitap-mate
class AttendanceCard extends ConsumerStatefulWidget {
  final AttendanceCourse course;
  final VoidCallback? onTap;
  
  const AttendanceCard({
    super.key,
    required this.course,
    this.onTap,
  });
  
  @override
  ConsumerState<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<AttendanceCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }
  
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }
  
  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLab = widget.course.isLab;
    final percentage = widget.course.percentage;
    final statusColors = AttendanceColors.getStatusColors(percentage);
    final gradientColors = AttendanceColors.getCardGradient(isLab, isDark);
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Icon, Course Info, Percentage
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course type icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isLab ? AttendanceColors.labIcon : AttendanceColors.theoryIcon)
                            .withOpacity(isDark ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isLab ? Icons.science_outlined : Icons.menu_book_outlined,
                        color: isLab ? AttendanceColors.labIcon : AttendanceColors.theoryIcon,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Course info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Course code and type badge
                          Row(
                            children: [
                              Text(
                                widget.course.courseCode,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isLab ? AttendanceColors.labIcon : AttendanceColors.theoryIcon)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isLab ? 'LAB' : 'LECTURE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isLab ? AttendanceColors.labIcon : AttendanceColors.theoryIcon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Course name
                          Text(
                            widget.course.courseName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Percentage indicator
                    _buildPercentageChip(percentage, statusColors, isDark),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total',
                        '${percentage.toStringAsFixed(0)}%',
                        Icons.percent,
                        statusColors.$1,
                        isDark,
                      ),
                    ),
                    if (widget.course.fatCatPercentage != '-' && 
                        widget.course.fatCatPercentage.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatItem(
                          'B/W Exams',
                          widget.course.fatCatPercentage,
                          Icons.calendar_today,
                          AttendanceColors.theoryIcon,
                          isDark,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatItem(
                        'Present',
                        '${widget.course.attendedClasses}/${widget.course.totalClasses}',
                        Icons.check_circle_outline,
                        AttendanceColors.presentColor,
                        isDark,
                      ),
                    ),
                  ],
                ),
                
                // Faculty and "Need X more" info
                if (widget.course.faculty.isNotEmpty || percentage < 75) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (widget.course.faculty.isNotEmpty) ...[
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatFacultyName(widget.course.faculty),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      
                      if (percentage < 75) ...[
                        const SizedBox(width: 8),
                        _buildNeedMoreChip(isDark),
                      ],
                      
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPercentageChip(double percentage, (Color, Color, Color) colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? colors.$1.withOpacity(0.2) : colors.$2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? colors.$1.withOpacity(0.5) : colors.$3,
          width: 1,
        ),
      ),
      child: Text(
        '${percentage.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: colors.$1,
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNeedMoreChip(bool isDark) {
    // Calculate classes needed for 75%
    final classesNeeded = _calculateClassesNeeded();
    if (classesNeeded <= 0) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AttendanceColors.warningBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AttendanceColors.warningBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: AttendanceColors.warningText,
          ),
          const SizedBox(width: 4),
          Text(
            'Need $classesNeeded more',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AttendanceColors.warningText,
            ),
          ),
        ],
      ),
    );
  }
  
  int _calculateClassesNeeded() {
    // (attended + x) / (total + x) = 0.75
    // x = (0.75 * total - attended) / 0.25
    final needed = ((0.75 * widget.course.totalClasses - widget.course.attendedClasses) / 0.25).ceil();
    return needed > 0 ? needed : 0;
  }
  
  String _formatFacultyName(String faculty) {
    // Format faculty name to be more readable
    if (faculty.isEmpty) return '';
    
    // Convert to title case
    return faculty.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length == 1) return word.toUpperCase();
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
