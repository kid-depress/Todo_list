import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:my_todo_test/models/todo_item.dart';
import 'package:my_todo_test/services/notification_service.dart';
import 'package:my_todo_test/todo_app.dart';

class FakeNotificationService extends NotificationService {
  int syncCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> getPermissionStatusWithAutoStart({
    required bool autoStartGranted,
    required bool unrestrictedBackgroundGranted,
  }) async {
    return NotificationPermissionStatus(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      unrestrictedBackgroundGranted: unrestrictedBackgroundGranted,
      batteryOptimizationDisabled: true,
      autoStartGranted: autoStartGranted,
    );
  }

  @override
  Future<void> syncTodos(List<TodoItem> todos) async {
    syncCount += 1;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders todo home', (WidgetTester tester) async {
    final FakeNotificationService notificationService =
        FakeNotificationService();
    await tester.pumpWidget(
      TodoApp(
        notificationService: notificationService,
      ),
    );
    await tester.pump();

    expect(find.text('任务提醒'), findsOneWidget);
    expect(find.text('新建任务'), findsOneWidget);
    expect(notificationService.syncCount, greaterThan(0));
  });

  test('can schedule reminders before keepalive guidance is confirmed', () {
    const NotificationPermissionStatus status = NotificationPermissionStatus(
      notificationsGranted: true,
      exactAlarmsGranted: true,
      unrestrictedBackgroundGranted: false,
      batteryOptimizationDisabled: true,
      autoStartGranted: false,
    );

    expect(status.canScheduleReminders, isTrue);
    expect(status.allRequiredGranted, isFalse);
  });
}
