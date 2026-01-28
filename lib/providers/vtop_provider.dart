import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vtop_models.dart';
import '../services/vtop_service.dart';
import '../services/storage_service.dart';

// VTOP Service Provider
final vtopServiceProvider = Provider<VtopService>((ref) {
  return VtopService();
});

// VTOP State
class VtopState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? error;
  final List<Semester> semesters;
  final String? selectedSemesterId;
  final TimetableData? timetable;
  final AttendanceData? attendance;
  final MarksData? marks;
  final ExamScheduleData? examSchedule;
  final DateTime? lastSynced;

  const VtopState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.error,
    this.semesters = const [],
    this.selectedSemesterId,
    this.timetable,
    this.attendance,
    this.marks,
    this.examSchedule,
    this.lastSynced,
  });

  VtopState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? error,
    List<Semester>? semesters,
    String? selectedSemesterId,
    TimetableData? timetable,
    AttendanceData? attendance,
    MarksData? marks,
    ExamScheduleData? examSchedule,
    DateTime? lastSynced,
    bool clearError = false,
  }) {
    return VtopState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      error: clearError ? null : (error ?? this.error),
      semesters: semesters ?? this.semesters,
      selectedSemesterId: selectedSemesterId ?? this.selectedSemesterId,
      timetable: timetable ?? this.timetable,
      attendance: attendance ?? this.attendance,
      marks: marks ?? this.marks,
      examSchedule: examSchedule ?? this.examSchedule,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }

  Semester? get selectedSemester {
    if (selectedSemesterId == null) return null;
    return semesters.where((s) => s.id == selectedSemesterId).firstOrNull;
  }
}

// VTOP State Notifier
class VtopNotifier extends StateNotifier<VtopState> {
  final VtopService _vtopService;
  final StorageService _storage = StorageService();

  VtopNotifier(this._vtopService) : super(const VtopState()) {
    _loadSavedData();
  }

  /// Load saved data from local storage
  Future<void> _loadSavedData() async {
    try {
      final semesters = await _storage.getSavedSemesters();
      final selectedSemesterId = await _storage.getSelectedSemesterId();
      final timetable = await _storage.getSavedTimetable();
      final attendance = await _storage.getSavedAttendance();
      final marks = await _storage.getSavedMarks();
      final examSchedule = await _storage.getSavedExamSchedule();

      state = state.copyWith(
        semesters: semesters,
        selectedSemesterId: selectedSemesterId,
        timetable: timetable,
        attendance: attendance,
        marks: marks,
        examSchedule: examSchedule,
      );
    } catch (e) {
      // Ignore errors loading saved data
    }
  }

  /// Check if VTOP credentials are saved
  Future<bool> hasCredentials() async {
    final creds = await _storage.getVtopCredentials();
    return creds != null && 
           creds['username']?.isNotEmpty == true && 
           creds['password']?.isNotEmpty == true;
  }

  /// Login to VTOP
  Future<bool> login({String? username, String? password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get credentials from parameters or storage
      String? user = username;
      String? pass = password;

      if (user == null || pass == null) {
        final creds = await _storage.getVtopCredentials();
        if (creds == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'No credentials saved. Please add VTOP credentials in Settings.',
          );
          return false;
        }
        user = creds['username'];
        pass = creds['password'];
      }

      if (user == null || user.isEmpty || pass == null || pass.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid credentials',
        );
        return false;
      }

      final result = await _vtopService.login(user, pass);

      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          error: result.message,
        );
        return false;
      }

      // Save credentials if login successful
      if (username != null && password != null) {
        await _storage.saveVtopCredentials(username, password);
      }

      // Save session (cookie) for future use
      if (_vtopService.cookie != null) {
        await _storage.saveVtopSession(
          cookie: _vtopService.cookie!,
          csrfToken: _vtopService.csrfToken,
          authorizedId: _vtopService.authorizedId,
        );
      }

      // Fetch semesters after login
      final semesters = await _vtopService.fetchSemesters();
      
      // Select the first (most recent) semester if none selected
      String? selectedId = state.selectedSemesterId;
      if (selectedId == null && semesters.isNotEmpty) {
        selectedId = semesters.first.id;
      }

      await _storage.saveVtopData(
        semesters: semesters,
        selectedSemesterId: selectedId,
      );

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        semesters: semesters,
        selectedSemesterId: selectedId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: $e',
      );
      return false;
    }
  }

  /// Change selected semester
  Future<void> selectSemester(Semester semester) async {
    state = state.copyWith(selectedSemesterId: semester.id);
    await _storage.saveVtopData(selectedSemesterId: semester.id);
    
    // Optionally refresh data for new semester
    if (_vtopService.isAuthenticated) {
      await syncAll();
    }
  }

  /// Load credentials (reload after settings change)
  Future<void> loadCredentials() async {
    final hasCredentials = await this.hasCredentials();
    if (hasCredentials && !state.isLoggedIn) {
      // Just verify credentials exist, don't auto-login
      state = state.copyWith(clearError: true);
    }
  }

  /// Fetch timetable
  Future<void> fetchTimetable() async {
    if (!_vtopService.isAuthenticated) {
      final loggedIn = await login();
      if (!loggedIn) return;
    }

    final semesterId = state.selectedSemesterId;
    if (semesterId == null) {
      state = state.copyWith(error: 'No semester selected');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final timetable = await _vtopService.fetchTimetable(semesterId);
      await _storage.saveVtopData(timetable: timetable);
      
      state = state.copyWith(
        isLoading: false,
        timetable: timetable,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch timetable: $e',
      );
    }
  }

  /// Fetch attendance
  Future<void> fetchAttendance() async {
    if (!_vtopService.isAuthenticated) {
      final loggedIn = await login();
      if (!loggedIn) return;
    }

    final semesterId = state.selectedSemesterId;
    if (semesterId == null) {
      state = state.copyWith(error: 'No semester selected');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final attendance = await _vtopService.fetchAttendance(semesterId);
      await _storage.saveVtopData(attendance: attendance);
      
      state = state.copyWith(
        isLoading: false,
        attendance: attendance,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch attendance: $e',
      );
    }
  }

  /// Fetch detailed attendance for a specific course
  Future<List<AttendanceDetail>> fetchAttendanceDetail(AttendanceCourse course) async {
    if (!_vtopService.isAuthenticated) {
      final loggedIn = await login();
      if (!loggedIn) return [];
    }

    final semesterId = state.selectedSemesterId;
    if (semesterId == null) {
      throw Exception('No semester selected');
    }

    try {
      return await _vtopService.fetchAttendanceDetail(
        semesterId: semesterId,
        courseId: course.courseId,
        courseType: course.courseType,
      );
    } catch (e) {
      throw Exception('Failed to fetch attendance detail: $e');
    }
  }

  /// Fetch marks
  Future<void> fetchMarks() async {
    if (!_vtopService.isAuthenticated) {
      final loggedIn = await login();
      if (!loggedIn) return;
    }

    final semesterId = state.selectedSemesterId;
    if (semesterId == null) {
      state = state.copyWith(error: 'No semester selected');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final marks = await _vtopService.fetchMarks(semesterId);
      await _storage.saveVtopData(marks: marks);
      
      state = state.copyWith(
        isLoading: false,
        marks: marks,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch marks: $e',
      );
    }
  }

  /// Fetch exam schedule
  Future<void> fetchExamSchedule() async {
    if (!_vtopService.isAuthenticated) {
      final loggedIn = await login();
      if (!loggedIn) return;
    }

    final semesterId = state.selectedSemesterId;
    if (semesterId == null) {
      state = state.copyWith(error: 'No semester selected');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final examSchedule = await _vtopService.fetchExamSchedule(semesterId);
      await _storage.saveVtopData(examSchedule: examSchedule);
      
      state = state.copyWith(
        isLoading: false,
        examSchedule: examSchedule,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch exam schedule: $e',
      );
    }
  }

  /// Sync all data
  Future<void> syncAll() async {
    if (!_vtopService.isAuthenticated) {
      final loggedIn = await login();
      if (!loggedIn) return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final semesterId = state.selectedSemesterId;
      if (semesterId == null) {
        state = state.copyWith(isLoading: false, error: 'No semester selected');
        return;
      }

      final timetable = await _vtopService.fetchTimetable(semesterId);
      final attendance = await _vtopService.fetchAttendance(semesterId);
      final marks = await _vtopService.fetchMarks(semesterId);
      final examSchedule = await _vtopService.fetchExamSchedule(semesterId);

      await _storage.saveVtopData(
        timetable: timetable,
        attendance: attendance,
        marks: marks,
        examSchedule: examSchedule,
      );

      state = state.copyWith(
        isLoading: false,
        timetable: timetable,
        attendance: attendance,
        marks: marks,
        examSchedule: examSchedule,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sync failed: $e',
      );
    }
  }

  /// Logout and clear data
  Future<void> logout() async {
    _vtopService.logout();
    await _storage.clearVtopCredentials();
    await _storage.clearVtopData();
    
    state = const VtopState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// VTOP State Provider
final vtopProvider = StateNotifierProvider<VtopNotifier, VtopState>((ref) {
  return VtopNotifier(ref.read(vtopServiceProvider));
});
