import 'dart:async';

import 'package:flutter/material.dart';

import '../models/todo_draft.dart';
import '../models/todo_filter.dart';
import '../models/todo_item.dart';
import '../services/notification_service.dart';
import '../services/todo_storage.dart';
import '../widgets/todo_editor_sheet.dart';
import 'background_keepalive_guide_page.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key, this.storage, this.notificationService});

  final TodoStorage? storage;
  final NotificationService? notificationService;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  late final TodoStorage _storage;
  late final NotificationService _notificationService;
  late final bool _ownsNotificationService;
  StreamSubscription<int>? _notificationSubscription;

  List<TodoItem> _todos = <TodoItem>[];
  int _nextId = 1;
  TodoFilter _filter = TodoFilter.pending;
  bool _loading = true;
  int? _pendingNotificationTodoId;
  bool _showingReminderDialog = false;
  NotificationPermissionStatus? _permissionStatus;
  bool _autoStartConfirmed = false;
  bool _unrestrictedBackgroundConfirmed = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? TodoStorage();
    _notificationService = widget.notificationService ?? NotificationService();
    _ownsNotificationService = widget.notificationService == null;
    _notificationSubscription = _notificationService.notificationSelectionStream
        .listen(_handleNotificationSelection);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    if (_ownsNotificationService) {
      unawaited(_notificationService.dispose());
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _notificationService.initialize();
    final List<TodoItem> todos = await _storage.loadTodos();
    final int nextId = await _storage.loadNextId();
    final bool autoStartConfirmed = await _storage.loadAutoStartConfirmed();
    final bool unrestrictedBackgroundConfirmed = await _storage
        .loadUnrestrictedBackgroundConfirmed();
    final NotificationPermissionStatus permissionStatus =
        await _notificationService.getPermissionStatusWithAutoStart(
          autoStartGranted: autoStartConfirmed,
          unrestrictedBackgroundGranted: unrestrictedBackgroundConfirmed,
        );

    if (!mounted) return;

    setState(() {
      _todos = todos;
      _nextId = nextId;
      _loading = false;
      _permissionStatus = permissionStatus;
      _autoStartConfirmed = autoStartConfirmed;
      _unrestrictedBackgroundConfirmed = unrestrictedBackgroundConfirmed;
    });

    _presentReminderDialogIfNeeded();
    unawaited(_notificationService.syncTodos(_todos));
  }

  Future<void> _persistState() async {
    await _storage.saveTodos(_todos);
    await _storage.saveNextId(_nextId);
    await _notificationService.syncTodos(_todos);
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _bootstrap();
  }

  Future<void> _ensureReminderPermissions() async {
    final NotificationPermissionStatus status = await _notificationService
        .ensurePermissionsWithAutoStart(
          autoStartGranted: _autoStartConfirmed,
          unrestrictedBackgroundGranted: _unrestrictedBackgroundConfirmed,
        );
    if (!mounted) return;

    setState(() {
      _permissionStatus = status;
    });

    final String message = status.allRequiredGranted
        ? '提醒权限已开启，可以正常接收提醒'
        : '仍缺少：${status.missingRequiredPermissions.join('、')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (status.canScheduleReminders) {
      await _notificationService.syncTodos(_todos);
    }
  }

  Future<void> _openKeepAliveGuide() async {
    final Object? result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (BuildContext context) => const BackgroundKeepAliveGuidePage(),
      ),
    );

    if (result is! Map<String, bool>) {
      return;
    }

    final bool autoStartConfirmed = result['autoStartConfirmed'] ?? false;
    final bool unrestrictedBackgroundConfirmed =
        result['unrestrictedBackgroundConfirmed'] ?? false;

    await _storage.saveAutoStartConfirmed(autoStartConfirmed);
    await _storage.saveUnrestrictedBackgroundConfirmed(
      unrestrictedBackgroundConfirmed,
    );

    final NotificationPermissionStatus status = await _notificationService
        .getPermissionStatusWithAutoStart(
          autoStartGranted: autoStartConfirmed,
          unrestrictedBackgroundGranted: unrestrictedBackgroundConfirmed,
        );

    if (!mounted) return;

    setState(() {
      _autoStartConfirmed = autoStartConfirmed;
      _unrestrictedBackgroundConfirmed = unrestrictedBackgroundConfirmed;
      _permissionStatus = status;
    });
  }

  void _handleNotificationSelection(int todoId) {
    _pendingNotificationTodoId = todoId;
    _presentReminderDialogIfNeeded();
  }

  void _presentReminderDialogIfNeeded() {
    if (!mounted ||
        _loading ||
        _showingReminderDialog ||
        _pendingNotificationTodoId == null) {
      return;
    }

    final TodoItem? item = _findTodoById(_pendingNotificationTodoId!);
    if (item == null) {
      _pendingNotificationTodoId = null;
      return;
    }

    _showingReminderDialog = true;
    final int todoId = item.id;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final TodoItem? latestItem = _findTodoById(todoId);
      if (latestItem == null) {
        _pendingNotificationTodoId = null;
        _showingReminderDialog = false;
        return;
      }

      final bool? shouldOpen = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return _RingingReminderSheet(
            item: latestItem,
            onClose: () => Navigator.of(context).pop(false),
            onOpen: () => Navigator.of(context).pop(true),
          );
        },
      );

      await _notificationService.stopRingtone(todoId);

      _pendingNotificationTodoId = null;
      _showingReminderDialog = false;

      if (shouldOpen == true && mounted) {
        await _openEditor(item: latestItem);
      }
    });
  }

  List<TodoItem> get _visibleTodos {
    final DateTime now = DateTime.now();
    final List<TodoItem> filtered = switch (_filter) {
      TodoFilter.pending =>
        _todos.where((TodoItem item) => !item.completed).toList(),
      TodoFilter.completed =>
        _todos.where((TodoItem item) => item.completed).toList(),
      TodoFilter.today => _todos.where((TodoItem item) {
        return !item.completed &&
            item.dueAt != null &&
            _isSameDay(item.dueAt!, now);
      }).toList(),
    };

    filtered.sort((TodoItem a, TodoItem b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      if (a.dueAt == null && b.dueAt == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (a.dueAt == null) return 1;
      if (b.dueAt == null) return -1;
      return a.dueAt!.compareTo(b.dueAt!);
    });
    return filtered;
  }

  int get _pendingCount =>
      _todos.where((TodoItem item) => !item.completed).length;

  List<TodoItem> get _todayTodos {
    final DateTime now = DateTime.now();
    return _todos
        .where(
          (TodoItem item) =>
              !item.completed &&
              item.dueAt != null &&
              _isSameDay(item.dueAt!, now),
        )
        .toList();
  }

  List<TodoItem> get _completedTodos =>
      _todos.where((TodoItem item) => item.completed).toList();

  Future<void> _addTodo(TodoDraft draft) async {
    final TodoItem item = TodoItem(
      id: _nextId,
      title: draft.title.trim(),
      notes: draft.notes.trim(),
      dueAt: draft.dueAt,
      ringOnReminder: draft.ringOnReminder,
      createdAt: DateTime.now(),
    );

    setState(() {
      _todos = <TodoItem>[item, ..._todos];
      _nextId += 1;
    });

    await _persistState();
  }

  Future<void> _updateTodo(TodoItem oldItem, TodoDraft draft) async {
    setState(() {
      _todos = _todos.map((TodoItem item) {
        if (item.id != oldItem.id) return item;
        return item.copyWith(
          title: draft.title.trim(),
          notes: draft.notes.trim(),
          dueAt: draft.dueAt,
          ringOnReminder: draft.ringOnReminder,
        );
      }).toList();
    });

    await _persistState();
  }

  Future<void> _toggleCompleted(TodoItem item, bool completed) async {
    setState(() {
      _todos = _todos.map((TodoItem current) {
        if (current.id != item.id) return current;
        return current.copyWith(completed: completed);
      }).toList();
    });

    await _persistState();
  }

  Future<void> _deleteTodo(TodoItem item) async {
    setState(() {
      _todos.removeWhere((TodoItem current) => current.id == item.id);
      _todos = List<TodoItem>.from(_todos);
    });

    await _persistState();
  }

  Future<void> _openEditor({TodoItem? item}) async {
    final TodoDraft? draft = await showModalBottomSheet<TodoDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => TodoEditorSheet(initialItem: item),
    );

    if (draft == null) return;

    if (item == null) {
      await _addTodo(draft);
    } else {
      await _updateTodo(item, draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TodoItem> visibleTodos = _visibleTodos;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '任务提醒',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton.filledTonal(
            onPressed: _ensureReminderPermissions,
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: '检查提醒权限',
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建任务'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF2EBDD),
              Color(0xFFF7F5EF),
              Color(0xFFE8F0EC),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool wide = constraints.maxWidth >= 840;
                          final EdgeInsets padding = EdgeInsets.fromLTRB(
                            wide ? 28 : 16,
                            14,
                            wide ? 28 : 16,
                            104,
                          );

                          if (wide) {
                            return ListView(
                              padding: padding,
                              children: <Widget>[
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1180,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        SizedBox(
                                          width: 340,
                                          child: _DashboardRail(
                                            pendingCount: _pendingCount,
                                            todayCount: _todayTodos.length,
                                            completedCount:
                                                _completedTodos.length,
                                            permissionStatus: _permissionStatus,
                                            onCheckPermissions:
                                                _ensureReminderPermissions,
                                            onOpenKeepAliveGuide:
                                                _openKeepAliveGuide,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: _TaskSurface(
                                            filter: _filter,
                                            todos: visibleTodos,
                                            onFilterChanged:
                                                (TodoFilter value) {
                                                  setState(
                                                    () => _filter = value,
                                                  );
                                                },
                                            onOpenEditor: _openEditor,
                                            onToggleCompleted: _toggleCompleted,
                                            onDeleteTodo: _deleteTodo,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return ListView(
                            padding: padding,
                            children: <Widget>[
                              _DashboardRail(
                                pendingCount: _pendingCount,
                                todayCount: _todayTodos.length,
                                completedCount: _completedTodos.length,
                                permissionStatus: _permissionStatus,
                                onCheckPermissions: _ensureReminderPermissions,
                                onOpenKeepAliveGuide: _openKeepAliveGuide,
                              ),
                              const SizedBox(height: 16),
                              _TaskSurface(
                                filter: _filter,
                                todos: visibleTodos,
                                onFilterChanged: (TodoFilter value) {
                                  setState(() => _filter = value);
                                },
                                onOpenEditor: _openEditor,
                                onToggleCompleted: _toggleCompleted,
                                onDeleteTodo: _deleteTodo,
                              ),
                            ],
                          );
                        },
                  ),
                ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  TodoItem? _findTodoById(int id) {
    for (final TodoItem item in _todos) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}

class _DashboardRail extends StatelessWidget {
  const _DashboardRail({
    required this.pendingCount,
    required this.todayCount,
    required this.completedCount,
    required this.permissionStatus,
    required this.onCheckPermissions,
    required this.onOpenKeepAliveGuide,
  });

  final int pendingCount;
  final int todayCount;
  final int completedCount;
  final NotificationPermissionStatus? permissionStatus;
  final Future<void> Function() onCheckPermissions;
  final Future<void> Function() onOpenKeepAliveGuide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool needsAttention =
        permissionStatus != null && !permissionStatus!.allRequiredGranted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(32),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.24),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '安排今天，\n也照顾稍后的自己。',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '可为重要任务开启响铃，到点前 5 分钟会先通知，你也可以提前关闭本次响铃。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _MetricCard(
                label: '待办',
                value: pendingCount,
                icon: Icons.radio_button_unchecked_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: '今天',
                value: todayCount,
                icon: Icons.today_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: '完成',
                value: completedCount,
                icon: Icons.done_all_rounded,
              ),
            ),
          ],
        ),
        if (needsAttention) ...<Widget>[
          const SizedBox(height: 14),
          _PermissionCard(
            status: permissionStatus!,
            onCheckPermissions: onCheckPermissions,
            onOpenKeepAliveGuide: onOpenKeepAliveGuide,
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.status,
    required this.onCheckPermissions,
    required this.onOpenKeepAliveGuide,
  });

  final NotificationPermissionStatus status;
  final Future<void> Function() onCheckPermissions;
  final Future<void> Function() onOpenKeepAliveGuide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String missing = status.missingRequiredPermissions.join('、');

    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.84),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.notification_important_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '提醒权限需要确认',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '当前缺少：$missing。建议开启通知、精确闹钟和后台保活，避免错过提醒。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onCheckPermissions,
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('检查权限'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenKeepAliveGuide,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('保活引导'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSurface extends StatelessWidget {
  const _TaskSurface({
    required this.filter,
    required this.todos,
    required this.onFilterChanged,
    required this.onOpenEditor,
    required this.onToggleCompleted,
    required this.onDeleteTodo,
  });

  final TodoFilter filter;
  final List<TodoItem> todos;
  final ValueChanged<TodoFilter> onFilterChanged;
  final Future<void> Function({TodoItem? item}) onOpenEditor;
  final Future<void> Function(TodoItem item, bool completed) onToggleCompleted;
  final Future<void> Function(TodoItem item) onDeleteTodo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _titleFor(filter),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TodoFilter>(
              segments: const <ButtonSegment<TodoFilter>>[
                ButtonSegment<TodoFilter>(
                  value: TodoFilter.pending,
                  label: Text('待办'),
                  icon: Icon(Icons.radio_button_unchecked_rounded),
                ),
                ButtonSegment<TodoFilter>(
                  value: TodoFilter.today,
                  label: Text('今天'),
                  icon: Icon(Icons.today_rounded),
                ),
                ButtonSegment<TodoFilter>(
                  value: TodoFilter.completed,
                  label: Text('完成'),
                  icon: Icon(Icons.done_all_rounded),
                ),
              ],
              selected: <TodoFilter>{filter},
              onSelectionChanged: (Set<TodoFilter> values) {
                onFilterChanged(values.first);
              },
            ),
            const SizedBox(height: 16),
            if (todos.isEmpty)
              const _EmptyState()
            else
              _AnimatedTaskList(
                todos: todos,
                onOpenEditor: onOpenEditor,
                onToggleCompleted: onToggleCompleted,
                onDeleteTodo: onDeleteTodo,
              ),
          ],
        ),
      ),
    );
  }

  String _titleFor(TodoFilter filter) {
    return switch (filter) {
      TodoFilter.pending => '待办任务',
      TodoFilter.today => '今天提醒',
      TodoFilter.completed => '已完成',
    };
  }
}

// ignore: unused_element
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.item,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool overdue =
        !item.completed &&
        item.dueAt != null &&
        item.dueAt!.isBefore(DateTime.now());

    return Material(
      color: item.completed
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: item.completed,
                onChanged: (bool? value) {
                  if (value != null) {
                    onToggle(value);
                  }
                },
              ),
              const SizedBox(width: 8),
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
                              decoration: item.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: item.completed
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
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
                    if (item.notes.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        item.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InfoChip(
                          icon: item.dueAt == null
                              ? Icons.notifications_none_rounded
                              : Icons.schedule_rounded,
                          label: item.dueAt == null
                              ? '未设置提醒'
                              : _formatDueAt(item.dueAt!),
                          urgent: overdue,
                        ),
                        if (item.dueAt != null && item.ringOnReminder)
                          const _InfoChip(
                            icon: Icons.notifications_active_rounded,
                            label: '响铃',
                          ),
                        if (item.completed)
                          const _InfoChip(
                            icon: Icons.check_circle_rounded,
                            label: '已完成',
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

  String _formatDueAt(DateTime dueAt) {
    return '${dueAt.month}/${dueAt.day} ${dueAt.hour.toString().padLeft(2, '0')}:${dueAt.minute.toString().padLeft(2, '0')}';
  }
}

class _AnimatedTaskList extends StatefulWidget {
  const _AnimatedTaskList({
    required this.todos,
    required this.onOpenEditor,
    required this.onToggleCompleted,
    required this.onDeleteTodo,
  });

  final List<TodoItem> todos;
  final Future<void> Function({TodoItem? item}) onOpenEditor;
  final Future<void> Function(TodoItem item, bool completed) onToggleCompleted;
  final Future<void> Function(TodoItem item) onDeleteTodo;

  @override
  State<_AnimatedTaskList> createState() => _AnimatedTaskListState();
}

class _AnimatedTaskListState extends State<_AnimatedTaskList> {
  static const Duration _completeAnimationDuration = Duration(
    milliseconds: 520,
  );

  final Set<int> _completingTodoIds = <int>{};

  @override
  void didUpdateWidget(covariant _AnimatedTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<int> activeIds = widget.todos
        .map((TodoItem item) => item.id)
        .toSet();
    _completingTodoIds.removeWhere((int id) => !activeIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.todos.map((TodoItem item) {
        final bool hiding = _completingTodoIds.contains(item.id);

        return AnimatedSlide(
          key: ValueKey<String>('task-slide-${item.id}'),
          duration: _completeAnimationDuration,
          curve: Curves.easeInOutCubicEmphasized,
          offset: hiding ? const Offset(0.08, 0) : Offset.zero,
          child: AnimatedOpacity(
            duration: _completeAnimationDuration,
            curve: Curves.easeOutCubic,
            opacity: hiding ? 0 : 1,
            child: AnimatedSize(
              duration: _completeAnimationDuration,
              curve: Curves.easeInOutCubicEmphasized,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: hiding ? 0 : null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnimatedTaskCard(
                    item: item,
                    isAnimatingCompletion: hiding,
                    onTap: () => widget.onOpenEditor(item: item),
                    onToggle: (bool completed) =>
                        _handleToggle(item, completed),
                    onDelete: () => widget.onDeleteTodo(item),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleToggle(TodoItem item, bool completed) async {
    if (_completingTodoIds.contains(item.id)) {
      return;
    }

    if (!completed) {
      await widget.onToggleCompleted(item, false);
      return;
    }

    setState(() {
      _completingTodoIds.add(item.id);
    });

    await Future<void>.delayed(_completeAnimationDuration);
    if (!mounted) {
      return;
    }

    await widget.onToggleCompleted(item, true);
  }
}

class _AnimatedTaskCard extends StatelessWidget {
  const _AnimatedTaskCard({
    required this.item,
    required this.isAnimatingCompletion,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem item;
  final bool isAnimatingCompletion;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String trimmedNotes = item.notes.trim();
    final bool hasNotes = trimmedNotes.isNotEmpty;
    final bool overdue =
        !item.completed &&
        item.dueAt != null &&
        item.dueAt!.isBefore(DateTime.now());
    final Color baseColor = item.completed
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42)
        : theme.colorScheme.surfaceContainerLow;
    final Color animatedColor =
        Color.lerp(
          baseColor,
          theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
          isAnimatingCompletion ? 0.78 : 0,
        ) ??
        baseColor;

    return AnimatedScale(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      scale: isAnimatingCompletion ? 0.985 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.primary.withValues(
                alpha: isAnimatingCompletion ? 0.22 : 0.10,
              ),
              blurRadius: isAnimatingCompletion ? 30 : 20,
              offset: Offset(0, isAnimatingCompletion ? 6 : 10),
            ),
          ],
        ),
        child: Material(
          color: animatedColor,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    scale: isAnimatingCompletion ? 1.12 : 1,
                    child: Checkbox(
                      value: item.completed || isAnimatingCompletion,
                      onChanged: (bool? value) {
                        if (value != null) {
                          onToggle(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
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
                                  decoration: item.completed
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: item.completed
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
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
                        if (hasNotes) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            trimmedNotes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (hasNotes) const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            _InfoChip(
                              icon: item.dueAt == null
                                  ? Icons.notifications_none_rounded
                                  : Icons.schedule_rounded,
                              label: item.dueAt == null
                                  ? '未设提醒'
                                  : _formatDueAt(item.dueAt!),
                              urgent: overdue,
                            ),
                            if (item.dueAt != null && item.ringOnReminder)
                              const _InfoChip(
                                icon: Icons.notifications_active_rounded,
                                label: '响铃',
                              ),
                            if (isAnimatingCompletion || item.completed)
                              _InfoChip(
                                icon: isAnimatingCompletion
                                    ? Icons.auto_awesome_rounded
                                    : Icons.check_circle_rounded,
                                label: isAnimatingCompletion ? '已完成' : '已完成',
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
        ),
      ),
    );
  }

  String _formatDueAt(DateTime dueAt) {
    return '${dueAt.month}/${dueAt.day} ${dueAt.hour.toString().padLeft(2, '0')}:${dueAt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.urgent = false,
  });

  final IconData icon;
  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = urgent
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer.withValues(alpha: 0.55);
    final Color foreground = urgent
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label),
      backgroundColor: background,
      labelStyle: theme.textTheme.labelMedium?.copyWith(color: foreground),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.36,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.inbox_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            '这里很清爽',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '添加一个任务，让提醒帮你记住重要的事。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingingReminderSheet extends StatelessWidget {
  const _RingingReminderSheet({
    required this.item,
    required this.onClose,
    required this.onOpen,
  });

  final TodoItem item;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Dismissible(
      key: ValueKey<int>(item.id),
      direction: DismissDirection.down,
      onDismissed: (_) => onClose(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    Icon(
                      Icons.alarm_on_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '提醒时间到了',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.notes.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    item.notes.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '向下滑动可关闭闹钟',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onClose,
                        child: const Text('关闭闹钟'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: onOpen,
                        child: const Text('打开任务'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
