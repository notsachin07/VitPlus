import 'package:flutter/material.dart';
import '../../models/vtop_models.dart';
import 'marks_colors.dart';

/// A beautifully designed marks card widget inspired by vitap-mate
class MarksCard extends StatefulWidget {
  final CourseMarks course;
  
  const MarksCard({
    super.key,
    required this.course,
  });
  
  @override
  State<MarksCard> createState() => _MarksCardState();
}

class _MarksCardState extends State<MarksCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  bool get _isLab => widget.course.courseType.toLowerCase().contains('lab') ||
                     widget.course.courseType.toLowerCase().contains('lo');
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = MarksColors.getCardGradient(_isLab, isDark);
    final totalScore = widget.course.totalWeightedScore;
    final statusColors = MarksColors.getStatusColors(totalScore);
    
    return GestureDetector(
      onTap: widget.course.components.isNotEmpty ? _toggleExpand : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          ],
        ),
        child: Column(
          children: [
            // Main Card Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course type icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (_isLab ? MarksColors.labColor : MarksColors.catColor)
                              .withOpacity(isDark ? 0.3 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isLab ? Icons.science_outlined : Icons.school_outlined,
                          color: _isLab ? MarksColors.labColor : MarksColors.catColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Course info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    color: (_isLab ? MarksColors.labColor : MarksColors.catColor)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _isLab ? 'LAB' : 'LECTURE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _isLab ? MarksColors.labColor : MarksColors.catColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
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
                      
                      // Total score
                      _buildScoreChip(totalScore, statusColors, isDark),
                    ],
                  ),
                  
                  // Component summary chips
                  if (widget.course.components.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.course.components.take(4).map((c) => 
                        _buildComponentChip(c, isDark)
                      ).toList(),
                    ),
                  ],
                  
                  // Expand indicator
                  if (widget.course.components.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Expanded component details
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: _buildExpandedContent(isDark),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScoreChip(double score, (Color, Color, Color) colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colors.$1.withOpacity(0.2) : colors.$2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? colors.$1.withOpacity(0.5) : colors.$3,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.$1,
            ),
          ),
          Text(
            'Total',
            style: TextStyle(
              fontSize: 10,
              color: colors.$1.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComponentChip(MarkComponent component, bool isDark) {
    final color = MarksColors.getComponentColor(component.name);
    final scored = component.scoredMarksDouble;
    final max = component.maxMarksDouble;
    final percentage = max > 0 ? (scored / max * 100) : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _shortenComponentName(component.name),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${scored.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  String _shortenComponentName(String name) {
    // Shorten common component names
    final lower = name.toLowerCase();
    if (lower.contains('continuous assessment')) return 'CAT';
    if (lower.contains('final assessment')) return 'FAT';
    if (lower.contains('digital assignment')) return 'DA';
    if (lower.contains('quiz')) return 'Quiz';
    if (lower.contains('lab')) return 'Lab';
    
    // Return first 12 chars if too long
    if (name.length > 12) return '${name.substring(0, 10)}...';
    return name;
  }
  
  Widget _buildExpandedContent(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Component',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Marks',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Weighted',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Component rows
          ...widget.course.components.map((c) => _buildComponentRow(c, isDark)),
          
          // Total row
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: MarksColors.getStatusColors(widget.course.totalWeightedScore).$2.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: MarksColors.getStatusColors(widget.course.totalWeightedScore).$3,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Weighted Score',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                Text(
                  widget.course.totalWeightedScore.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MarksColors.getStatusColors(widget.course.totalWeightedScore).$1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildComponentRow(MarkComponent component, bool isDark) {
    final scored = component.scoredMarksDouble;
    final max = component.maxMarksDouble;
    final weighted = component.weightedScoreDouble;
    final percentage = max > 0 ? (scored / max * 100) : 0.0;
    final color = MarksColors.getComponentColor(component.name);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              component.name,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  '${scored.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              weighted.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
