import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:my_todo_test/models/todo_item.dart';
import 'package:my_todo_test/services/todo_storage.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('saves and restores todos and settings', () async {
    final TodoStorage storage = TodoStorage();
    final List<TodoItem> todos = <TodoItem>[
      TodoItem(
        id: 3,
        title: 'Morning run',
        notes: 'Bring water',
        createdAt: DateTime.utc(2026, 5, 20, 6),
        dueAt: DateTime.utc(2026, 5, 21, 6, 30),
        ringOnReminder: true,
      ),
    ];

    await storage.saveTodos(todos);
    await storage.saveNextId(4);
    await storage.saveAutoStartConfirmed(true);
    await storage.saveUnrestrictedBackgroundConfirmed(true);

    final List<TodoItem> restoredTodos = await storage.loadTodos();

    expect(restoredTodos, hasLength(1));
    expect(restoredTodos.first.title, 'Morning run');
    expect(await storage.loadNextId(), 4);
    expect(await storage.loadAutoStartConfirmed(), isTrue);
    expect(await storage.loadUnrestrictedBackgroundConfirmed(), isTrue);
  });

  test('returns defaults when nothing has been stored', () async {
    final TodoStorage storage = TodoStorage();

    expect(await storage.loadTodos(), isEmpty);
    expect(await storage.loadNextId(), 1);
    expect(await storage.loadAutoStartConfirmed(), isFalse);
    expect(await storage.loadUnrestrictedBackgroundConfirmed(), isFalse);
  });
}
