import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:my_todo_test/models/todo_item.dart';
import 'package:my_todo_test/services/notification_service.dart';
import 'package:my_todo_test/todo_app.dart';

class FakeNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> syncTodos(List<TodoItem> todos) async {}
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders todo home', (WidgetTester tester) async {
    await tester.pumpWidget(
      TodoApp(
        notificationService: FakeNotificationService(),
      ),
    );
    await tester.pump();

    expect(find.text('待办提醒'), findsWidgets);
    expect(find.text('新建'), findsOneWidget);
  });
}
