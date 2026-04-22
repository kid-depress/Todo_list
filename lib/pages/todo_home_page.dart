import 'dart:async';

import 'package:flutter/material.dart';

import 'background_keepalive_guide_page.dart';
import '../models/todo_draft.dart';
import '../models/todo_filter.dart';
import '../models/todo_item.dart';
import '../services/notification_service.dart';
import '../services/todo_storage.dart';
import '../widgets/todo_editor_sheet.dart';
import '../widgets/todo_filter_surface.dart';
import '../widgets/todo_hero_panel.dart';
import '../widgets/todo_sections.dart';

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

    if (status.allRequiredGranted) {
      await _notificationService.syncTodos(_todos);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提醒权限已开启，可以正常接收闹铃提醒了')));
      return;
    }

    final String missing = status.missingRequiredPermissions.join('、');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('还缺少 $missing，请继续在系统页面中允许')));
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

      final bool? shouldOpen = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提醒时间到了'),
            content: Text(
              latestItem.notes.trim().isEmpty
                  ? latestItem.title
                  : '${latestItem.title}\n\n${latestItem.notes.trim()}',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('知道了'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('打开待办'),
              ),
            ],
          );
        },
      );

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

  String get _dateLabel {
    const List<String> weekdays = <String>[
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日',
    ];
    final DateTime now = DateTime.now();
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 11) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

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
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '待办提醒',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '把今天要做的事，排得更清楚一点',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFFF6FBFA),
              theme.colorScheme.surface,
              const Color(0xFFF2F6F8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: <Widget>[
                          if (_permissionStatus != null &&
                              !_permissionStatus!
                                  .allRequiredGranted) ...<Widget>[
                            _PermissionNotice(
                              status: _permissionStatus!,
                              onPressed: _ensureReminderPermissions,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TodoHeroPanel(
                            dateLabel: _dateLabel,
                            greeting: _greeting,
                            pendingCount: _pendingCount,
                            onAdd: () => _openEditor(),
                          ),
                          const SizedBox(height: 16),
                          if (_permissionStatus != null &&
                              !_permissionStatus!
                                  .allRequiredGranted) ...<Widget>[
                            _BackgroundKeepAliveNotice(
                              onOpenGuide: _openKeepAliveGuide,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TodoFilterSurface(
                            selected: _filter,
                            onSelectionChanged: (TodoFilter value) {
                              setState(() => _filter = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          TodoSections(
                            visibleTodos: visibleTodos,
                            filter: _filter,
                            todayTodos: _todayTodos,
                            completedTodos: _completedTodos,
                            onOpenEditor: _openEditor,
                            onToggleCompleted: _toggleCompleted,
                            onDeleteTodo: _deleteTodo,
                          ),
                        ],
                      ),
                    ),
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

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.status, required this.onPressed});

  final NotificationPermissionStatus status;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String missing = status.missingRequiredPermissions.join('、');
    final bool fullScreenReady = status.fullScreenIntentGranted ?? false;

    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '提醒权限未开启完整',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '当前缺少：$missing。未授权时，到点后可能不会正常弹出提醒。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fullScreenReady ? '全屏提醒权限：已授权' : '全屏提醒权限：建议授权，这样锁屏或后台时提醒会更明显。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer.withValues(
                  alpha: 0.86,
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.security),
              label: const Text('检查并申请权限'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundKeepAliveNotice extends StatelessWidget {
  const _BackgroundKeepAliveNotice({required this.onOpenGuide});

  final Future<void> Function() onOpenGuide;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.shield_moon_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '清除后台后可能不提醒',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '部分 Android 系统会在你手动清除后台后停止应用，导致本地定时提醒失效。这通常不是 Flutter 通知代码本身能完全绕过的限制。',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              '建议把应用设为允许自启动、不限制后台、关闭省电优化，并尽量不要从最近任务里手动划掉它。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onOpenGuide,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('查看保活引导'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
