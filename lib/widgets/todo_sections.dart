import 'package:flutter/material.dart';

import '../models/todo_filter.dart';
import '../models/todo_item.dart';
import 'todo_card.dart';
import 'todo_empty_state.dart';

class TodoSections extends StatelessWidget {
  const TodoSections({
    required this.visibleTodos,
    required this.filter,
    required this.todayTodos,
    required this.completedTodos,
    required this.onOpenEditor,
    required this.onToggleCompleted,
    required this.onDeleteTodo,
    super.key,
  });

  final List<TodoItem> visibleTodos;
  final TodoFilter filter;
  final List<TodoItem> todayTodos;
  final List<TodoItem> completedTodos;
  final Future<void> Function({TodoItem? item}) onOpenEditor;
  final Future<void> Function(TodoItem item, bool completed) onToggleCompleted;
  final Future<void> Function(TodoItem item) onDeleteTodo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (visibleTodos.isEmpty) {
      return TodoEmptyState(
        title: filter == TodoFilter.completed ? '还没有已完成任务' : '还没有待办',
        subtitle: filter == TodoFilter.completed
            ? '完成一些任务后，这里会记录你的进度。'
            : '点右下角按钮创建第一个提醒吧。',
        onAdd: () => onOpenEditor(),
      );
    }

    if (filter != TodoFilter.pending && filter != TodoFilter.today && filter != TodoFilter.completed) {
      return const SizedBox.shrink();
    }

    if (filter != TodoFilter.completed) {
      return Column(
        children: visibleTodos
            .map(
              (TodoItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TodoCard(
                  item: item,
                  accentColor: theme.colorScheme.primary,
                  onTap: () => onOpenEditor(item: item),
                  onToggle: (bool value) => onToggleCompleted(item, value),
                  onDelete: () => onDeleteTodo(item),
                ),
              ),
            )
            .toList(),
      );
    }

    return Column(
      children: completedTodos
          .map(
            (TodoItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TodoCard(
                item: item,
                accentColor: theme.colorScheme.secondary,
                onTap: () => onOpenEditor(item: item),
                onToggle: (bool value) => onToggleCompleted(item, value),
                onDelete: () => onDeleteTodo(item),
              ),
            ),
          )
          .toList(),
    );
  }
}
