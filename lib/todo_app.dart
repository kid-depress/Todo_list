import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/todo_home_page.dart';
import 'services/notification_service.dart';
import 'services/todo_storage.dart';

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
    return MaterialApp(
      title: '待办提醒',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F7D6D),
        ),
        useMaterial3: true,
      ),
      home: TodoHomePage(
        storage: storage,
        notificationService: notificationService,
      ),
    );
  }
}
