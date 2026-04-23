import 'package:flutter/material.dart';

import '../models/todo_draft.dart';
import '../models/todo_item.dart';

class TodoEditorSheet extends StatefulWidget {
  const TodoEditorSheet({required this.initialItem, super.key});

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
    _titleController = TextEditingController(
      text: widget.initialItem?.title ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialItem?.notes ?? '',
    );
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
    final DateTime seed =
        _dueAt ?? DateTime.now().add(const Duration(hours: 1));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
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
    final DateTime seed =
        _dueAt ?? DateTime.now().add(const Duration(hours: 1));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (picked == null) return;
    setState(() {
      final DateTime base = _dueAt ?? seed;
      _dueAt = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
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
    final TextStyle chipLabelStyle =
        theme.textTheme.labelLarge?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600);
    final String dueText = _dueAt == null
        ? '未设置'
        : '${_dueAt!.year}/${_dueAt!.month.toString().padLeft(2, '0')}/${_dueAt!.day.toString().padLeft(2, '0')} ${_dueAt!.hour.toString().padLeft(2, '0')}:${_dueAt!.minute.toString().padLeft(2, '0')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 20,
              top: 16,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.initialItem == null ? '新建待办' : '编辑待办',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '例如：晚上 8 点开会',
                      border: OutlineInputBorder(),
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入标题';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      hintText: '补充地点、链接、检查项等',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '提醒时间',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.date_range, size: 18),
                        label: Text('选择日期', style: chipLabelStyle),
                        labelStyle: chipLabelStyle,
                        backgroundColor: theme.colorScheme.surface,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        onPressed: _pickDate,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.access_time, size: 18),
                        label: Text('选择时间', style: chipLabelStyle),
                        labelStyle: chipLabelStyle,
                        backgroundColor: theme.colorScheme.surface,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        onPressed: _pickTime,
                      ),
                      if (_dueAt != null)
                        ActionChip(
                          avatar: const Icon(Icons.clear, size: 18),
                          label: Text('清除提醒', style: chipLabelStyle),
                          labelStyle: chipLabelStyle,
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          onPressed: _clearDueAt,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.alarm),
                      title: const Text('当前设置'),
                      subtitle: Text(dueText),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      _ringOnReminder
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                    ),
                    title: const Text('提醒时响铃'),
                    subtitle: Text(
                      _ringOnReminder ? '到点后播放系统提醒铃声' : '只发送通知，不播放铃声',
                    ),
                    value: _ringOnReminder,
                    onChanged: _dueAt == null
                        ? null
                        : (bool value) {
                            setState(() => _ringOnReminder = value);
                          },
                  ),
                  const SizedBox(height: 20),
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
        );
      },
    );
  }
}
