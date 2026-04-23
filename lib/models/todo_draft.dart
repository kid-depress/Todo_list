class TodoDraft {
  const TodoDraft({
    required this.title,
    required this.notes,
    required this.dueAt,
    required this.ringOnReminder,
  });

  final String title;
  final String notes;
  final DateTime? dueAt;
  final bool ringOnReminder;
}
