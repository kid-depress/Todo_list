class TodoDraft {
  const TodoDraft({
    required this.title,
    required this.notes,
    required this.dueAt,
  });

  final String title;
  final String notes;
  final DateTime? dueAt;
}
