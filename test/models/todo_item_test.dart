import 'package:flutter_test/flutter_test.dart';

import 'package:my_todo_test/models/todo_item.dart';

void main() {
  test('encodes and decodes todo items', () {
    final List<TodoItem> items = <TodoItem>[
      TodoItem(
        id: 1,
        title: 'Review PR',
        notes: 'Check reminder edge cases',
        createdAt: DateTime.utc(2026, 5, 20, 12),
        dueAt: DateTime.utc(2026, 5, 21, 9, 30),
        completed: false,
        ringOnReminder: true,
      ),
    ];

    final String encoded = TodoItem.encodeList(items);
    final List<TodoItem> decoded = TodoItem.decodeList(encoded);

    expect(decoded, hasLength(1));
    expect(decoded.first.id, items.first.id);
    expect(decoded.first.title, items.first.title);
    expect(decoded.first.notes, items.first.notes);
    expect(decoded.first.createdAt, items.first.createdAt);
    expect(decoded.first.dueAt, items.first.dueAt);
    expect(decoded.first.ringOnReminder, isTrue);
  });
}
