import 'package:flutter/material.dart';

import 'pages/todo_home_page.dart';
import 'services/notification_service.dart';
import 'services/todo_storage.dart';
import 'theme/app_theme.dart';

class TodoApp extends StatelessWidget {
  const TodoApp({
    super.key,
    this.storage,
    this.notificationService,
  });

  final TodoStorage? storage;
  final NotificationService? notificationService;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '待办提醒',
      theme: buildAppTheme(colorScheme),
      home: TodoHomePage(
        storage: storage,
        notificationService: notificationService,
      ),
    );
  }
}
