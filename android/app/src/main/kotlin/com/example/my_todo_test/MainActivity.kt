package com.example.my_todo_test

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var selectionSink: EventChannel.EventSink? = null
    private var pendingSelection: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncTodos" -> {
                    runCatching {
                        val rawTodos = call.argument<List<*>>("todos").orEmpty()
                        val reminders = rawTodos.mapNotNull { entry ->
                            parseReminder(entry as? Map<*, *>)
                        }
                        TodoAlarmScheduler.sync(applicationContext, reminders)
                    }.onSuccess {
                        result.success(null)
                    }.onFailure { error ->
                        result.error(
                            "alarm_sync_failed",
                            error.message ?: "Failed to sync reminders.",
                            null,
                        )
                    }
                }

                "consumeLaunchTodoId" -> {
                    result.success(consumeTodoIdFromIntent(intent))
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SELECTION_CHANNEL_NAME,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink,
                ) {
                    selectionSink = events
                    pendingSelection?.let { todoId ->
                        events.success(todoId)
                        pendingSelection = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    selectionSink = null
                }
            },
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeTodoIdFromIntent(intent)?.let(::emitSelection)
    }

    private fun emitSelection(todoId: Int) {
        selectionSink?.success(todoId) ?: run {
            pendingSelection = todoId
        }
    }

    private fun consumeTodoIdFromIntent(intent: Intent?): Int? {
        val todoId = intent?.getIntExtra(TodoAlarmScheduler.EXTRA_NOTIFICATION_TODO_ID, -1)
            ?: return null
        if (todoId < 0) {
            return null
        }
        intent.removeExtra(TodoAlarmScheduler.EXTRA_NOTIFICATION_TODO_ID)
        return todoId
    }

    private fun parseReminder(raw: Map<*, *>?): ReminderAlarmPayload? {
        if (raw == null) {
            return null
        }
        val id = (raw["id"] as? Number)?.toInt() ?: return null
        val triggerAtMillis = (raw["triggerAtMillis"] as? Number)?.toLong() ?: return null
        val title = raw["title"] as? String ?: ""
        val notes = raw["notes"] as? String ?: ""
        return ReminderAlarmPayload(
            id = id,
            title = title,
            notes = notes,
            triggerAtMillis = triggerAtMillis,
        )
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "todo_alarm_manager/methods"
        private const val SELECTION_CHANNEL_NAME = "todo_alarm_manager/selections"
    }
}
