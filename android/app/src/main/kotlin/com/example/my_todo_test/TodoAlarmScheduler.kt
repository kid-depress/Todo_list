package com.example.my_todo_test

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationManagerCompat

object TodoAlarmScheduler {
    const val EXTRA_NOTIFICATION_TODO_ID = "todo_alarm_notification_todo_id"

    private const val ACTION_TODO_REMINDER = "com.example.my_todo_test.TODO_REMINDER"
    private const val EXTRA_TODO_ID = "todo_id"
    private const val EXTRA_TODO_TITLE = "todo_title"
    private const val EXTRA_TODO_NOTES = "todo_notes"
    private const val EXTRA_TODO_TRIGGER_AT = "todo_trigger_at"

    const val NOTIFICATION_CHANNEL_ID = "todo_alarm_reminders"
    private const val NOTIFICATION_CHANNEL_NAME = "Todo reminders"
    private const val NOTIFICATION_CHANNEL_DESCRIPTION =
        "Reminder notifications scheduled with AlarmManager."

    fun sync(context: Context, reminders: List<ReminderAlarmPayload>) {
        val sanitized = reminders
            .filter { reminder -> reminder.triggerAtMillis > System.currentTimeMillis() }
            .distinctBy { reminder -> reminder.id }

        TodoAlarmStore.load(context).forEach { reminder ->
            cancel(context, reminder.id)
        }

        TodoAlarmStore.save(context, sanitized)
        sanitized.forEach { reminder ->
            schedule(context, reminder)
        }
    }

    fun rescheduleStored(context: Context) {
        val upcoming = TodoAlarmStore.load(context)
            .filter { reminder -> reminder.triggerAtMillis > System.currentTimeMillis() }
            .distinctBy { reminder -> reminder.id }

        TodoAlarmStore.save(context, upcoming)
        upcoming.forEach { reminder ->
            schedule(context, reminder)
        }
    }

    fun cancel(context: Context, todoId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildAlarmPendingIntent(context, todoId))
        NotificationManagerCompat.from(context).cancel(todoId)
    }

    fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = NOTIFICATION_CHANNEL_DESCRIPTION
            enableVibration(true)
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    fun buildContentIntent(context: Context, todoId: Int): PendingIntent {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("mytodo://reminder/$todoId")
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(EXTRA_NOTIFICATION_TODO_ID, todoId)
        }
        return PendingIntent.getActivity(
            context,
            todoId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun reminderTitle(intent: Intent): String =
        intent.getStringExtra(EXTRA_TODO_TITLE).orEmpty()

    fun reminderNotes(intent: Intent): String =
        intent.getStringExtra(EXTRA_TODO_NOTES).orEmpty()

    fun reminderId(intent: Intent): Int =
        intent.getIntExtra(EXTRA_TODO_ID, -1)

    fun onReminderDelivered(context: Context, todoId: Int) {
        TodoAlarmStore.remove(context, todoId)
    }

    private fun schedule(context: Context, reminder: ReminderAlarmPayload) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildAlarmPendingIntent(context, reminder)
        val triggerAtMillis = reminder.triggerAtMillis

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                alarmManager.canScheduleExactAlarms() -> {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }

            else -> {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
        }
    }

    private fun buildAlarmPendingIntent(
        context: Context,
        reminder: ReminderAlarmPayload,
    ): PendingIntent {
        val intent = Intent(context, TodoAlarmReceiver::class.java).apply {
            action = ACTION_TODO_REMINDER
            data = Uri.parse("mytodo://alarm/${reminder.id}")
            putExtra(EXTRA_TODO_ID, reminder.id)
            putExtra(EXTRA_TODO_TITLE, reminder.title)
            putExtra(EXTRA_TODO_NOTES, reminder.notes)
            putExtra(EXTRA_TODO_TRIGGER_AT, reminder.triggerAtMillis)
        }
        return PendingIntent.getBroadcast(
            context,
            reminder.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildAlarmPendingIntent(
        context: Context,
        todoId: Int,
    ): PendingIntent {
        val intent = Intent(context, TodoAlarmReceiver::class.java).apply {
            action = ACTION_TODO_REMINDER
            data = Uri.parse("mytodo://alarm/$todoId")
            putExtra(EXTRA_TODO_ID, todoId)
        }
        return PendingIntent.getBroadcast(
            context,
            todoId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
