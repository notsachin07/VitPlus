import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vtop_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/timetable/timetable_card.dart';
import '../widgets/timetable/days_selector.dart';
import '../widgets/timetable/timetable_utils.dart';
import '../widgets/timetable/timetable_colors.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  int _selectedDayIndex = 1;
  List<int> _availableDays = [];
  bool _mergeLabs = true;
  bool _showFreeSlots = true;
  double? _startX;

  @override
  void initState() {
    super.initState();
    // Set to current day
    _selectedDayIndex = DateTime.now().weekday;

    // Load timetable if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vtopState = ref.read(vtopProvider);
      if (vtopState.timetable == null) {
        ref.read(vtopProvider.notifier).fetchTimetable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vtopState = ref.watch(vtopProvider);

    // Update available days when timetable data changes
    if (vtopState.timetable != null) {
      final days = getDayList(vtopState.timetable);
      if (days.isNotEmpty && _availableDays.isEmpty) {
        _availableDays = days;
        if (!_availableDays.contains(_selectedDayIndex)) {
          _selectedDayIndex = _availableDays.first;
        }
      } else {
        _availableDays = days;
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Column(
        children: [
          _buildHeader(isDark, vtopState),
          if (vtopState.timetable != null && _availableDays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DaysSelector(
                selectedDayIndex: _selectedDayIndex,
                availableDays: _availableDays,
                onDaySelected: (day) => setState(() => _selectedDayIndex = day),
              ),
            ),
          Expanded(
            child: _buildTimetableContent(isDark, vtopState),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, VtopState vtopState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 24,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Table',
                  style: TextStyle(
                    fontSize: 22,
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
          // Settings popup menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.tune,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'Options',
            onSelected: (value) {
              setState(() {
                if (value == 'merge') {
                  _mergeLabs = !_mergeLabs;
                } else if (value == 'free') {
                  _showFreeSlots = !_showFreeSlots;
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'merge',
                checked: _mergeLabs,
                child: const Text('Merge Lab Slots'),
              ),
              CheckedPopupMenuItem(
                value: 'free',
                checked: _showFreeSlots,
                child: const Text('Show Free Time'),
              ),
            ],
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
              onPressed: () => ref.read(vtopProvider.notifier).fetchTimetable(),
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }

  Widget _buildTimetableContent(bool isDark, VtopState vtopState) {
    if (vtopState.error != null && vtopState.timetable == null) {
      return _buildErrorState(isDark, vtopState.error!);
    }

    if (vtopState.timetable == null) {
      if (vtopState.isLoading) {
        return _buildLoadingState(isDark);
      }
      return _buildEmptyState(isDark);
    }

    if (_availableDays.isEmpty) {
      return _buildNoDataState(isDark);
    }

    // Get and process slots for selected day
    var daySlots = getDaySlots(vtopState.timetable!, _selectedDayIndex);

    if (daySlots.isEmpty) {
      return _buildNoClassesState(isDark);
    }

    // Apply merge labs if enabled
    if (_mergeLabs) {
      daySlots = mergeLabSlots(daySlots);
    }

    // Sort by start time
    daySlots.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Add free slots if enabled
    List<dynamic> displaySlots = _showFreeSlots 
        ? addFreeSlots(daySlots) 
        : daySlots;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        _startX = details.globalPosition.dx;
      },
      onHorizontalDragUpdate: (details) {
        final currentX = details.globalPosition.dx;
        final deltaX = currentX - (_startX ?? currentX);

        final currentIndex = _availableDays.indexOf(_selectedDayIndex);
        
        if (deltaX > 80 && currentIndex > 0) {
          setState(() {
            _selectedDayIndex = _availableDays[currentIndex - 1];
          });
          _startX = currentX;
        } else if (deltaX < -80 && currentIndex < _availableDays.length - 1) {
          setState(() {
            _selectedDayIndex = _availableDays[currentIndex + 1];
          });
          _startX = currentX;
        }
      },
      onHorizontalDragEnd: (_) => _startX = null,
      child: RefreshIndicator(
        onRefresh: () => ref.read(vtopProvider.notifier).fetchTimetable(),
        color: AppTheme.primaryBlue,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          itemCount: displaySlots.length + 1, // +1 for footer
          itemBuilder: (context, index) {
            if (index == displaySlots.length) {
              return _buildFooter(isDark, vtopState);
            }
            
            final slot = displaySlots[index];
            final isFreeSlot = slot.serial == -1;
            
            return TimetableCard(
              slot: slot,
              isFreeSlot: isFreeSlot,
            );
          },
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark, VtopState vtopState) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
          const SizedBox(width: 8),
          Text(
            vtopState.timetable != null
                ? 'Last updated: ${_formatDateTime(vtopState.timetable!.fetchedAt)}'
                : 'Swipe horizontally to change day',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                TimetableColors.upcomingBorder,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading timetable...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Timetable Data',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your VTOP credentials in Settings\nand tap refresh to load your timetable',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => ref.read(vtopProvider.notifier).fetchTimetable(),
              icon: const Icon(Icons.refresh),
              label: const Text('Load Timetable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No schedule data found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassesState(bool isDark) {
    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.weekend_outlined,
              size: 48,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Classes on ${dayNames[_selectedDayIndex]}!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy your day off 🎉',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load Timetable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => ref.read(vtopProvider.notifier).fetchTimetable(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
