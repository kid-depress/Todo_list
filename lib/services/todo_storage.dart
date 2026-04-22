import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_item.dart';

class TodoStorage {
  TodoStorage([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _todosKey = 'todo_items_v1';
  static const String _nextIdKey = 'todo_next_id_v1';
  static const String _autoStartConfirmedKey =
      'reminder_auto_start_confirmed_v1';
  static const String _unrestrictedBackgroundConfirmedKey =
      'reminder_unrestricted_background_confirmed_v1';

  final SharedPreferencesAsync _preferences;

  Future<List<TodoItem>> loadTodos() async {
    try {
      return TodoItem.decodeList(await _preferences.getString(_todosKey));
    } catch (_) {
      return <TodoItem>[];
    }
  }

  Future<int> loadNextId() async {
    try {
      return await _preferences.getInt(_nextIdKey) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  Future<void> saveTodos(List<TodoItem> items) async {
    try {
      await _preferences.setString(_todosKey, TodoItem.encodeList(items));
    } catch (_) {}
  }

  Future<void> saveNextId(int nextId) async {
    try {
      await _preferences.setInt(_nextIdKey, nextId);
    } catch (_) {}
  }

  Future<bool> loadAutoStartConfirmed() async {
    try {
      return await _preferences.getBool(_autoStartConfirmedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveAutoStartConfirmed(bool confirmed) async {
    try {
      await _preferences.setBool(_autoStartConfirmedKey, confirmed);
    } catch (_) {}
  }

  Future<bool> loadUnrestrictedBackgroundConfirmed() async {
    try {
      return await _preferences.getBool(_unrestrictedBackgroundConfirmedKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveUnrestrictedBackgroundConfirmed(bool confirmed) async {
    try {
      await _preferences.setBool(
        _unrestrictedBackgroundConfirmedKey,
        confirmed,
      );
    } catch (_) {}
  }
}
