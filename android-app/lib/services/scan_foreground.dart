import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void _taskEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_IdleTaskHandler());
}

// Minimaler Handler – der Service läuft nur um den Prozess am Leben zu halten.
class _IdleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class ScanForeground {
  static void _init(String text) {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'notenleser_scan',
        channelName: 'Notenleser',
        channelDescription: 'Läuft während der Notenerkennung',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
      ),
    );
  }

  static Future<void> start(String notificationText) async {
    _init(notificationText);
    await FlutterForegroundTask.startService(
      serviceId: 42,
      notificationTitle: 'Notenleser',
      notificationText: notificationText,
      callback: _taskEntryPoint,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
