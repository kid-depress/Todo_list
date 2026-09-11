import 'package:flutter_test/flutter_test.dart';

import 'package:my_todo_test/validators/todo_draft_validator.dart';

void main() {
  test('allows empty reminder time', () {
    expect(validateReminderTime(null), isNull);
  });

  test('rejects reminder times in the past', () {
    final DateTime now = DateTime(2026, 5, 20, 10);

    expect(
      validateReminderTime(
        DateTime(2026, 5, 20, 9, 59),
        now: now,
      ),
      isNotNull,
    );
  });

  test('accepts reminder times in the future', () {
    final DateTime now = DateTime(2026, 5, 20, 10);

    expect(
      validateReminderTime(
        DateTime(2026, 5, 20, 10, 1),
        now: now,
      ),
      isNull,
    );
  });
}
