package com.example.my_todo_test

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

class TodoAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.my_todo_test.SUPPRESS_RING") {
            TodoAlarmScheduler.handleSuppressRing(context, intent)
            return
        }

        val todoId = TodoAlarmScheduler.reminderId(intent)
        if (todoId < 0) {
            return
        }

        TodoAlarmScheduler.ensureNotificationChannels(context)

        val title = TodoAlarmScheduler.reminderTitle(intent).ifBlank { "Todo reminder" }
        val notes = TodoAlarmScheduler.reminderNotes(intent)
        val body = notes.ifBlank { "It's time to check this todo." }
        val triggerAtMillis = TodoAlarmScheduler.reminderTriggerAtMillis(intent)
        val upcoming = TodoAlarmScheduler.isUpcomingReminder(intent)
        val ringOnReminder = !upcoming && TodoAlarmScheduler.shouldRingOnReminder(context, intent)

        if (!upcoming) {
            TodoAlarmScheduler.onReminderDelivered(context, todoId)
        }

        val notification = TodoAlarmScheduler.buildReminderNotification(
            context = context,
            todoId = todoId,
            title = title,
            body = body,
            triggerAtMillis = triggerAtMillis,
            ringOnReminder = ringOnReminder,
            upcoming = upcoming,
        )

        NotificationManagerCompat.from(context).notify(
            if (upcoming) todoId + 1_000_000 else todoId,
            notification,
        )
        if (ringOnReminder) {
            TodoRingtoneService.start(
                context = context,
                todoId = todoId,
                title = title,
                body = body,
                triggerAtMillis = triggerAtMillis,
            )
        }
    }
}
