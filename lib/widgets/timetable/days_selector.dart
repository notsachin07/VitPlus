import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Get dates for the current week (Monday to Sunday)
List<DateTime> getCurrentWeekDates() {
  final now = DateTime.now();
  final referenceDate =
      now.weekday == DateTime.sunday ? now.add(const Duration(days: 1)) : now;
  final startOfWeek = referenceDate.subtract(
    Duration(days: referenceDate.weekday - 1),
  );

  return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
}

/// A beautiful day selector widget for the timetable, inspired by vitap-mate
class DaysSelector extends StatelessWidget {
  final int selectedDayIndex;
  final List<int> availableDays;
  final ValueChanged<int> onDaySelected;

  const DaysSelector({
    super.key,
    required this.selectedDayIndex,
    required this.availableDays,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateList = getCurrentWeekDates();
    final today = DateTime.now().weekday;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < availableDays.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _DayChip(
                  dayNumber: dateList[availableDays[i] - 1].day,
                  dayName: days[availableDays[i] - 1],
                  isSelected: availableDays[i] == selectedDayIndex,
                  isToday: today == availableDays[i],
                  isDark: isDark,
                  onTap: () => onDaySelected(availableDays[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final int dayNumber;
  final String dayName;
  final bool isSelected;
  final bool isToday;
  final bool isDark;
  final VoidCallback onTap;

  const _DayChip({
    required this.dayNumber,
    required this.dayName,
    required this.isSelected,
    required this.isToday,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDark ? Colors.white24 : Colors.black12),
            width: isToday && !isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNumber.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            // Today indicator dot
            if (isToday)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.primaryBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
