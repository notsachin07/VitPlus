import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/title_bar.dart';
import 'wifi_screen.dart';
import 'vitshare_screen.dart';
import 'settings_screen.dart';
import 'timetable_screen.dart';
import 'attendance_screen.dart';
import 'marks_screen.dart';
import 'exam_schedule_screen.dart';
import 'vtop_screen.dart';

final selectedNavProvider = StateProvider<int>((ref) => 2); // Default to Timetable

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedNav = ref.watch(selectedNavProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          const TitleBar(),
          Expanded(
            child: Row(
              children: [
                Sidebar(
                  selectedIndex: selectedNav,
                  onItemSelected: (index) {
                    ref.read(selectedNavProvider.notifier).state = index;
                  },
                ),
                Container(
                  width: 1,
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
                Expanded(
                  child: _buildContent(selectedNav),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const WiFiScreen();
      case 1:
        return const VitShareScreen();
      case 2:
        return const TimetableScreen();
      case 3:
        return const AttendanceScreen();
      case 4:
        return const MarksScreen();
      case 5:
        return const ExamScheduleScreen();
      case 6:
        return const VtopScreen();
      case 7:
        return const SettingsScreen();
      default:
        return const WiFiScreen();
    }
  }
}
