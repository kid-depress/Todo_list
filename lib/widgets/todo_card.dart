import 'package:flutter/material.dart';

import '../models/todo_item.dart';

class TodoCard extends StatelessWidget {
  const TodoCard({
    required this.item,
    required this.accentColor,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final TodoItem item;
  final Color accentColor;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.completed
                      ? theme.colorScheme.primaryContainer
                      : accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Checkbox(
                  value: item.completed,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
                  fillColor:
                      WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return accentColor;
                    }
                    return Colors.transparent;
                  }),
                  checkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onChanged: (bool? value) {
                    if (value != null) {
                      onToggle(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              decoration: item.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: item.completed
                                  ? theme.colorScheme.outline
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onSelected: (String value) {
                            if (value == 'edit') {
                              onTap();
                            } else if (value == 'delete') {
                              onDelete();
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.notes.isNotEmpty ? item.notes : '暂无备注',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: item.completed
                            ? theme.colorScheme.outline
                            : theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        if (item.dueAt != null)
                          _DueChip(dueAt: item.dueAt!)
                        else
                          const _DueChip.empty(),
                        if (item.completed)
                          const _SimpleChip(icon: Icons.check_circle, label: '已完成'),
                        if (!item.completed && item.notes.isNotEmpty)
                          const _SimpleChip(
                            icon: Icons.edit_note_rounded,
                            label: '有备注',
                            filled: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.dueAt}) : empty = false;

  const _DueChip.empty()
      : dueAt = null,
        empty = true;

  final DateTime? dueAt;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    if (empty || dueAt == null) {
      return _SimpleChip(
        icon: Icons.notifications_none,
        label: '未设置提醒',
        filled: false,
      );
    }

    final String text =
        '${dueAt!.month}/${dueAt!.day} ${dueAt!.hour.toString().padLeft(2, '0')}:${dueAt!.minute.toString().padLeft(2, '0')}';
    return _SimpleChip(
      icon: Icons.schedule,
      label: text,
      filled: false,
    );
  }
}

class _SimpleChip extends StatelessWidget {
  const _SimpleChip({required this.icon, required this.label, this.filled = false});

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = filled
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);
    final Color foreground = filled
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label),
      side: BorderSide.none,
      backgroundColor: background,
      labelStyle: theme.textTheme.labelMedium?.copyWith(color: foreground),
      visualDensity: VisualDensity.compact,
    );
  }
}
