String? validateReminderTime(DateTime? dueAt, {DateTime? now}) {
  if (dueAt == null) {
    return null;
  }

  final DateTime comparisonTime = now ?? DateTime.now();
  if (!dueAt.isAfter(comparisonTime)) {
    return '提醒时间需要晚于当前时间';
  }

  return null;
}
