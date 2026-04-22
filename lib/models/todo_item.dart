import 'dart:convert';

class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.notes = '',
    this.dueAt,
    this.completed = false,
  });

  final int id;
  final String title;
  final String notes;
  final DateTime createdAt;
  final DateTime? dueAt;
  final bool completed;

  TodoItem copyWith({
    int? id,
    String? title,
    String? notes,
    DateTime? createdAt,
    DateTime? dueAt,
    bool? completed,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt?.toIso8601String(),
        'completed': completed,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? ''),
      completed: json['completed'] as bool? ?? false,
    );
  }

  static String encodeList(List<TodoItem> items) {
    return jsonEncode(items.map((TodoItem item) => item.toJson()).toList());
  }

  static List<TodoItem> decodeList(String? source) {
    if (source == null || source.trim().isEmpty) {
      return <TodoItem>[];
    }

    final dynamic decoded = jsonDecode(source);
    if (decoded is! List) {
      return <TodoItem>[];
    }

    return decoded
        .whereType<Map>()
        .map((Map<dynamic, dynamic> json) {
          return TodoItem.fromJson(
            json.map((dynamic key, dynamic value) {
              return MapEntry<String, dynamic>(key.toString(), value);
            }),
          );
        })
        .toList();
  }
}
