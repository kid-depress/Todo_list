import 'package:flutter/material.dart';

import '../models/todo_draft.dart';
import '../models/todo_item.dart';

class TodoEditorSheet extends StatefulWidget {
  const TodoEditorSheet({
    required this.initialItem,
    super.key,
  });

  final TodoItem? initialItem;

  @override
  State<TodoEditorSheet> createState() => _TodoEditorSheetState();
}

class _TodoEditorSheetState extends State<TodoEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  DateTime? _dueAt;
  late bool _ringOnReminder;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialItem?.title ?? '');
    _notesController =
        TextEditingController(text: widget.initialItem?.notes ?? '');
    _dueAt = widget.initialItem?.dueAt;
    _ringOnReminder = widget.initialItem?.ringOnReminder ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime seed = _dueAt ?? DateTime.now().add(const Duration(hours: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
      helpText: '选择提醒日期',
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked == null) return;
    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueAt?.hour ?? seed.hour,
        _dueAt?.minute ?? seed.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final DateTime seed = _dueAt ?? DateTime.now().add(const Duration(hours: 1));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      helpText: '选择提醒时间',
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked == null) return;
    setState(() {
      final DateTime base = _dueAt ?? seed;
      _dueAt = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
    });
  }

  void _clearDueAt() {
    setState(() {
      _dueAt = null;
      _ringOnReminder = false;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      TodoDraft(
        title: _titleController.text,
        notes: _notesController.text,
        dueAt: _dueAt,
        ringOnReminder: _dueAt != null && _ringOnReminder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dueText = _dueAt == null
        ? '未设置提醒时间'
        : '${_dueAt!.year}/${_dueAt!.month.toString().padLeft(2, '0')}/${_dueAt!.day.toString().padLeft(2, '0')} ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.only(
                  left: 20,
                  top: 14,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              widget.initialItem == null
                                  ? Icons.add_task_rounded
                                  : Icons.edit_note_rounded,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.initialItem == null ? '新建任务' : '编辑任务',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '设置时间、备注和响铃方式',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '标题',
                          hintText: '例如：晚上 8 点开会',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入标题';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          hintText: '补充地点、链接、检查项等',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '提醒设置',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ReminderPanel(
                        dueText: dueText,
                        hasDueAt: _dueAt != null,
                        ringOnReminder: _ringOnReminder,
                        onPickDate: _pickDate,
                        onPickTime: _pickTime,
                        onClear: _clearDueAt,
                        onRingChanged: (bool value) {
                          setState(() => _ringOnReminder = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _save,
                              child: const Text('保存'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReminderPanel extends StatelessWidget {
  const _ReminderPanel({
    required this.dueText,
    required this.hasDueAt,
    required this.ringOnReminder,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClear,
    required this.onRingChanged,
  });

  final String dueText;
  final bool hasDueAt;
  final bool ringOnReminder;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onClear;
  final ValueChanged<bool> onRingChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.event_available_rounded,
              color: theme.colorScheme.primary,
            ),
            title: const Text('当前提醒'),
            subtitle: Text(dueText),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onPickDate,
                icon: const Icon(Icons.date_range_rounded),
                label: const Text('日期'),
              ),
              FilledButton.tonalIcon(
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('时间'),
              ),
              if (hasDueAt)
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('清除'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              ringOnReminder
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
            ),
            title: const Text('提醒时响铃'),
            subtitle: Text(
              hasDueAt
                  ? '到点前 5 分钟先通知，可提前关闭本次响铃'
                  : '先设置提醒时间后再开启响铃',
            ),
            value: ringOnReminder,
            onChanged: hasDueAt ? onRingChanged : null,
          ),
        ],
      ),
    );
  }
}
