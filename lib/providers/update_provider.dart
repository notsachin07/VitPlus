import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';

/// Provider that checks for updates in the background
final updateAvailableProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final notifier = UpdateNotifier();
  // Check for updates on app start
  notifier.checkForUpdateSilently();
  return notifier;
});

class UpdateState {
  final bool isUpdateAvailable;
  final UpdateInfo? updateInfo;
  final bool isChecking;

  const UpdateState({
    this.isUpdateAvailable = false,
    this.updateInfo,
    this.isChecking = false,
  });

  UpdateState copyWith({
    bool? isUpdateAvailable,
    UpdateInfo? updateInfo,
    bool? isChecking,
  }) {
    return UpdateState(
      isUpdateAvailable: isUpdateAvailable ?? this.isUpdateAvailable,
      updateInfo: updateInfo ?? this.updateInfo,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _updateService = UpdateService();

  UpdateNotifier() : super(const UpdateState());

  /// Silently check for updates without showing any dialogs
  Future<void> checkForUpdateSilently() async {
    try {
      state = state.copyWith(isChecking: true);
      final updateInfo = await _updateService.checkForUpdate();
      state = UpdateState(
        isUpdateAvailable: updateInfo.isUpdateAvailable,
        updateInfo: updateInfo,
        isChecking: false,
      );
    } catch (e) {
      // Silently fail - don't show errors for background checks
      state = state.copyWith(isChecking: false);
    }
  }

  /// Clear the update notification after user has seen it
  void clearUpdateNotification() {
    state = state.copyWith(isUpdateAvailable: false);
  }

  /// Get the cached update info
  UpdateInfo? get updateInfo => state.updateInfo;
}
