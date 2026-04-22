package com.example.my_todo_test

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class TodoAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val todoId = TodoAlarmScheduler.reminderId(intent)
        if (todoId < 0) {
            return
        }

        TodoAlarmScheduler.ensureNotificationChannel(context)
        TodoAlarmScheduler.onReminderDelivered(context, todoId)

        val title = TodoAlarmScheduler.reminderTitle(intent).ifBlank { "Todo reminder" }
        val notes = TodoAlarmScheduler.reminderNotes(intent)
        val body = notes.ifBlank { "It's time to check this todo." }

        val notification = NotificationCompat.Builder(
            context,
            TodoAlarmScheduler.NOTIFICATION_CHANNEL_ID,
        )
            .setSmallIcon(R.drawable.ic_todo_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(TodoAlarmScheduler.buildContentIntent(context, todoId))
            .build()

        NotificationManagerCompat.from(context).notify(todoId, notification)
    }
}
