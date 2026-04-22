import 'dart:async';

import 'package:flutter/material.dart';

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
  const TodoHomePage({
    super.key,
    this.storage,
    this.notificationService,
  });

  final TodoStorage? storage;
  final NotificationService? notificationService;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  late final TodoStorage _storage;
  late final NotificationService _notificationService;

  List<TodoItem> _todos = <TodoItem>[];
  int _nextId = 1;
  TodoFilter _filter = TodoFilter.pending;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? TodoStorage();
    _notificationService = widget.notificationService ?? NotificationService();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _notificationService.initialize();
    final List<TodoItem> todos = await _storage.loadTodos();
    final int nextId = await _storage.loadNextId();

    if (!mounted) return;

    setState(() {
      _todos = todos;
      _nextId = nextId;
      _loading = false;
    });

    await _autoCompleteOverdueTodos();
    unawaited(_notificationService.syncTodos(_todos));
  }

  Future<void> _autoCompleteOverdueTodos() async {
    final DateTime now = DateTime.now();
    final List<TodoItem> updated = _todos.map((TodoItem item) {
      final bool overdue = !item.completed &&
          item.dueAt != null &&
          item.dueAt!.isBefore(now);
      return overdue ? item.copyWith(completed: true) : item;
    }).toList();

    if (_listEquals(_todos, updated)) {
      return;
    }

    setState(() {
      _todos = updated;
    });

    await _persistState();
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

  int get _pendingCount => _todos.where((TodoItem item) => !item.completed).length;

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
        .where((TodoItem item) =>
            !item.completed &&
            item.dueAt != null &&
            _isSameDay(item.dueAt!, now))
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
                          TodoHeroPanel(
                            dateLabel: _dateLabel,
                            greeting: _greeting,
                            pendingCount: _pendingCount,
                            onAdd: () => _openEditor(),
                          ),
                          const SizedBox(height: 16),
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

  bool _listEquals(List<TodoItem> a, List<TodoItem> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      final TodoItem left = a[i];
      final TodoItem right = b[i];
      if (left.id != right.id ||
          left.title != right.title ||
          left.notes != right.notes ||
          left.createdAt != right.createdAt ||
          left.dueAt != right.dueAt ||
          left.completed != right.completed) {
        return false;
      }
    }
    return true;
  }
}
