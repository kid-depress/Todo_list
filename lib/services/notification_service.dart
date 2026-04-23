import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/todo_item.dart';

class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.unrestrictedBackgroundGranted,
    required this.batteryOptimizationDisabled,
    required this.autoStartGranted,
    this.fullScreenIntentGranted,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool unrestrictedBackgroundGranted;
  final bool batteryOptimizationDisabled;
  final bool autoStartGranted;
  final bool? fullScreenIntentGranted;

  bool get canScheduleReminders => notificationsGranted && exactAlarmsGranted;

  bool get allRequiredGranted =>
      canScheduleReminders &&
      unrestrictedBackgroundGranted &&
      batteryOptimizationDisabled &&
      autoStartGranted;

  List<String> get missingRequiredPermissions {
    final List<String> missing = <String>[];
    if (!notificationsGranted) {
      missing.add('通知权限');
    }
    if (!exactAlarmsGranted) {
      missing.add('精准闹钟权限');
    }
    if (!unrestrictedBackgroundGranted) {
      missing.add('后台无限制');
    }
    if (!autoStartGranted) {
      missing.add('允许自启动');
    }
    if (!batteryOptimizationDisabled) {
      missing.add('关闭省电优化');
    }
    return missing;
  }
}

class NotificationService {
  NotificationService();

  static const MethodChannel _alarmMethodChannel = MethodChannel(
    'todo_alarm_manager/methods',
  );
  static const EventChannel _alarmSelectionChannel = EventChannel(
    'todo_alarm_manager/selections',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<int> _notificationSelectionController =
      StreamController<int>.broadcast();

  StreamSubscription<dynamic>? _selectionSubscription;
  bool _initialized = false;
  bool? _fullScreenIntentPermissionGranted;
  bool _batteryOptimizationDisabled = false;

  Stream<int> get notificationSelectionStream =>
      _notificationSelectionController.stream;

  Future<void> dispose() async {
    await _selectionSubscription?.cancel();
    await _notificationSelectionController.close();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    _selectionSubscription = _alarmSelectionChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
          final int? todoId = _coerceTodoId(event);
          if (todoId != null) {
            _notificationSelectionController.add(todoId);
          }
        });

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    _fullScreenIntentPermissionGranted = await androidPlugin
        ?.requestFullScreenIntentPermission();
    _batteryOptimizationDisabled = await _resolveBatteryOptimizationDisabled();

    final int? launchTodoId = _coerceTodoId(
      await _alarmMethodChannel.invokeMethod<Object?>('consumeLaunchTodoId'),
    );
    if (launchTodoId != null) {
      _notificationSelectionController.add(launchTodoId);
    }

    _initialized = true;
  }

  Future<void> syncTodos(List<TodoItem> todos) async {
    await initialize();
    final NotificationPermissionStatus status = await getPermissionStatus();
    if (!status.canScheduleReminders) {
      return;
    }

    final List<Map<String, Object?>> reminders = todos
        .where((TodoItem item) => !item.completed && item.dueAt != null)
        .where((TodoItem item) => item.dueAt!.isAfter(DateTime.now()))
        .map((TodoItem item) {
          return <String, Object?>{
            'id': item.id,
            'title': item.title,
            'notes': item.notes,
            'triggerAtMillis': item.dueAt!.millisecondsSinceEpoch,
            'ringOnReminder': item.ringOnReminder,
          };
        })
        .toList();

    await _alarmMethodChannel.invokeMethod<void>('syncTodos', <String, Object?>{
      'todos': reminders,
    });
  }

  Future<void> stopRingtone(int todoId) async {
    await initialize();
    await _alarmMethodChannel.invokeMethod<void>(
      'stopRingtone',
      <String, Object?>{'todoId': todoId},
    );
  }

  Future<NotificationPermissionStatus> getPermissionStatus() async {
    await initialize();
    return getPermissionStatusWithAutoStart(
      autoStartGranted: false,
      unrestrictedBackgroundGranted: false,
    );
  }

  Future<NotificationPermissionStatus> getPermissionStatusWithAutoStart({
    required bool autoStartGranted,
    required bool unrestrictedBackgroundGranted,
  }) async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool notificationsGranted =
        await androidPlugin?.areNotificationsEnabled() ?? true;
    final bool exactAlarmsGranted =
        await androidPlugin?.canScheduleExactNotifications() ?? true;

    return NotificationPermissionStatus(
      notificationsGranted: notificationsGranted,
      exactAlarmsGranted: exactAlarmsGranted,
      unrestrictedBackgroundGranted: unrestrictedBackgroundGranted,
      batteryOptimizationDisabled: _batteryOptimizationDisabled,
      autoStartGranted: autoStartGranted,
      fullScreenIntentGranted: _fullScreenIntentPermissionGranted,
    );
  }

  Future<NotificationPermissionStatus> ensurePermissions() async {
    await initialize();
    return ensurePermissionsWithAutoStart(
      autoStartGranted: false,
      unrestrictedBackgroundGranted: false,
    );
  }

  Future<NotificationPermissionStatus> ensurePermissionsWithAutoStart({
    required bool autoStartGranted,
    required bool unrestrictedBackgroundGranted,
  }) async {
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    _fullScreenIntentPermissionGranted = await androidPlugin
        ?.requestFullScreenIntentPermission();
    _batteryOptimizationDisabled = await _resolveBatteryOptimizationDisabled();

    return getPermissionStatusWithAutoStart(
      autoStartGranted: autoStartGranted,
      unrestrictedBackgroundGranted: unrestrictedBackgroundGranted,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final int? todoId = _coerceTodoId(response.payload);
    if (todoId != null) {
      _notificationSelectionController.add(todoId);
    }
  }

  int? _coerceTodoId(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  Future<bool> _resolveBatteryOptimizationDisabled() async {
    return true;
  }
}
