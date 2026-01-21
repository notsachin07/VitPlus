import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class TrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  Future<void> init({
    required Function() onShow,
    required Function() onConnect,
    required Function() onDisconnect,
    required Function() onExit,
  }) async {
    await _systemTray.initSystemTray(
      title: 'VitPlus',
      iconPath: 'assets/icons/app_icon.ico',
      toolTip: 'VitPlus - WiFi Auto-Login',
    );

    await _menu.buildFrom([
      MenuItemLabel(
        label: 'Show VitPlus',
        onClicked: (menuItem) => onShow(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Quick Connect',
        onClicked: (menuItem) => onConnect(),
      ),
      MenuItemLabel(
        label: 'Disconnect',
        onClicked: (menuItem) => onDisconnect(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) => onExit(),
      ),
    ]);

    await _systemTray.setContextMenu(_menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        onShow();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  Future<void> updateStatus(String status) async {
    await _systemTray.setToolTip('VitPlus - $status');
  }

  Future<void> destroy() async {
    await _systemTray.destroy();
  }
}
