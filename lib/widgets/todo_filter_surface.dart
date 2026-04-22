import 'package:flutter/material.dart';

import '../models/todo_filter.dart';

class TodoFilterSurface extends StatelessWidget {
  const TodoFilterSurface({
    required this.selected,
    required this.onSelectionChanged,
    super.key,
  });

  final TodoFilter selected;
  final ValueChanged<TodoFilter> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '智能筛选',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                const Icon(Icons.tune_rounded, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TodoFilter>(
              segments: const <ButtonSegment<TodoFilter>>[
                ButtonSegment<TodoFilter>(
                  value: TodoFilter.pending,
                  label: Text('待完成'),
                  icon: Icon(Icons.schedule_outlined),
                ),
                ButtonSegment<TodoFilter>(
                  value: TodoFilter.today,
                  label: Text('今天'),
                  icon: Icon(Icons.today_outlined),
                ),
                ButtonSegment<TodoFilter>(
                  value: TodoFilter.completed,
                  label: Text('已完成'),
                  icon: Icon(Icons.check_circle_outline),
                ),
              ],
              selected: <TodoFilter>{selected},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onSelectionChanged: (Set<TodoFilter> selection) {
                onSelectionChanged(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
