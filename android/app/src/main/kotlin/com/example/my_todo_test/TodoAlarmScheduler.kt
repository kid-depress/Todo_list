package com.example.my_todo_test

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object TodoAlarmScheduler {
    const val EXTRA_NOTIFICATION_TODO_ID = "todo_alarm_notification_todo_id"

    private const val ACTION_TODO_REMINDER = "com.example.my_todo_test.TODO_REMINDER"
    private const val ACTION_SUPPRESS_RING = "com.example.my_todo_test.SUPPRESS_RING"
    private const val EXTRA_TODO_ID = "todo_id"
    private const val EXTRA_TODO_TITLE = "todo_title"
    private const val EXTRA_TODO_NOTES = "todo_notes"
    private const val EXTRA_TODO_TRIGGER_AT = "todo_trigger_at"
    private const val EXTRA_TODO_RING_ON_REMINDER = "todo_ring_on_reminder"
    private const val EXTRA_REMINDER_KIND = "reminder_kind"
    private const val REMINDER_KIND_FINAL = "final"
    private const val REMINDER_KIND_UPCOMING = "upcoming"

    private const val UPCOMING_NOTIFICATION_ID_OFFSET = 1_000_000
    private const val UPCOMING_REMINDER_ADVANCE_MILLIS = 5 * 60 * 1000L

    const val RING_NOTIFICATION_CHANNEL_ID = "todo_alarm_reminders_ring_v2"
    const val SILENT_NOTIFICATION_CHANNEL_ID = "todo_alarm_reminders_silent"
    private const val RING_NOTIFICATION_CHANNEL_NAME = "Todo reminders with sound"
    private const val SILENT_NOTIFICATION_CHANNEL_NAME = "Todo reminders"
    private const val RING_NOTIFICATION_CHANNEL_DESCRIPTION =
        "Reminder notifications scheduled with AlarmManager and sound enabled."
    private const val SILENT_NOTIFICATION_CHANNEL_DESCRIPTION =
        "Reminder notifications scheduled with AlarmManager."

    fun sync(context: Context, reminders: List<ReminderAlarmPayload>) {
        val sanitized = reminders
            .filter { reminder -> reminder.triggerAtMillis > System.currentTimeMillis() }
            .distinctBy { reminder -> reminder.id }

        TodoAlarmStore.load(context).forEach { reminder ->
            cancel(context, reminder.id, clearSuppressedRing = false)
        }

        TodoAlarmStore.retainSuppressedRingFor(context, sanitized)
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

    fun cancel(
        context: Context,
        todoId: Int,
        clearSuppressedRing: Boolean = true,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildAlarmPendingIntent(context, todoId, REMINDER_KIND_FINAL))
        alarmManager.cancel(buildAlarmPendingIntent(context, todoId, REMINDER_KIND_UPCOMING))
        NotificationManagerCompat.from(context).cancel(todoId)
        NotificationManagerCompat.from(context).cancel(upcomingNotificationId(todoId))
        if (clearSuppressedRing) {
            TodoAlarmStore.clearSuppressedRing(context, todoId)
        }
    }

    fun ensureNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val audioAttributes = reminderAudioAttributes()
        val ringChannel = NotificationChannel(
            RING_NOTIFICATION_CHANNEL_ID,
            RING_NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = RING_NOTIFICATION_CHANNEL_DESCRIPTION
            setSound(reminderSoundUri(), audioAttributes)
            enableVibration(true)
            setShowBadge(true)
        }
        val silentChannel = NotificationChannel(
            SILENT_NOTIFICATION_CHANNEL_ID,
            SILENT_NOTIFICATION_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = SILENT_NOTIFICATION_CHANNEL_DESCRIPTION
            setSound(null, null)
            enableVibration(false)
            setShowBadge(true)
        }
        manager.createNotificationChannels(listOf(ringChannel, silentChannel))
    }

    fun notificationChannelId(ringOnReminder: Boolean): String =
        if (ringOnReminder) RING_NOTIFICATION_CHANNEL_ID else SILENT_NOTIFICATION_CHANNEL_ID

    fun buildReminderNotification(
        context: Context,
        todoId: Int,
        title: String,
        body: String,
        triggerAtMillis: Long,
        ringOnReminder: Boolean,
        upcoming: Boolean = false,
    ): Notification {
        val notificationTitle = if (upcoming) "5 分钟后将响铃：$title" else title
        val notificationBody = if (upcoming) {
            "即将到提醒时间，可提前关闭本次响铃。\n\n$body"
        } else {
            body
        }
        val notificationId = if (upcoming) upcomingNotificationId(todoId) else todoId
        val builder = NotificationCompat.Builder(
            context,
            notificationChannelId(ringOnReminder && !upcoming),
        )
            .setSmallIcon(R.drawable.ic_todo_reminder)
            .setContentTitle(notificationTitle)
            .setContentText(notificationBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notificationBody))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(!ringOnReminder || upcoming)
            .setDefaults(if (ringOnReminder && !upcoming) NotificationCompat.DEFAULT_ALL else 0)
            .setSound(if (ringOnReminder && !upcoming) reminderSoundUri() else null)
            .setSilent(upcoming || !ringOnReminder)
            .setContentIntent(buildContentIntent(context, todoId))

        if (upcoming) {
            builder.addAction(
                R.drawable.ic_todo_reminder,
                "关闭本次响铃",
                buildSuppressRingPendingIntent(context, todoId, triggerAtMillis),
            )
        } else if (ringOnReminder) {
            builder
                .setOngoing(true)
                .addAction(
                    R.drawable.ic_todo_reminder,
                    "停止响铃",
                    TodoRingtoneService.buildStopPendingIntent(
                        context = context,
                        todoId = notificationId,
                        title = title,
                        body = body,
                        triggerAtMillis = triggerAtMillis,
                    ),
                )
        }

        return builder.build()
    }

    fun reminderSoundUri(): Uri =
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: Settings.System.DEFAULT_NOTIFICATION_URI

    fun reminderAudioAttributes(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

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

    fun reminderTriggerAtMillis(intent: Intent): Long =
        intent.getLongExtra(EXTRA_TODO_TRIGGER_AT, -1L)

    fun shouldRingOnReminder(context: Context, intent: Intent): Boolean {
        val todoId = reminderId(intent)
        val triggerAtMillis = reminderTriggerAtMillis(intent)
        return intent.getBooleanExtra(EXTRA_TODO_RING_ON_REMINDER, false) &&
            !TodoAlarmStore.isRingSuppressed(context, todoId, triggerAtMillis)
    }

    fun isUpcomingReminder(intent: Intent): Boolean =
        intent.getStringExtra(EXTRA_REMINDER_KIND) == REMINDER_KIND_UPCOMING

    fun handleSuppressRing(context: Context, intent: Intent) {
        val todoId = reminderId(intent)
        val triggerAtMillis = reminderTriggerAtMillis(intent)
        if (todoId < 0 || triggerAtMillis < 0L) {
            return
        }

        TodoAlarmStore.suppressRing(context, todoId, triggerAtMillis)
        NotificationManagerCompat.from(context).cancel(upcomingNotificationId(todoId))
    }

    fun onReminderDelivered(context: Context, todoId: Int) {
        TodoAlarmStore.remove(context, todoId)
        NotificationManagerCompat.from(context).cancel(upcomingNotificationId(todoId))
    }

    private fun schedule(context: Context, reminder: ReminderAlarmPayload) {
        scheduleAlarm(
            context = context,
            reminder = reminder,
            triggerAtMillis = reminder.triggerAtMillis,
            reminderKind = REMINDER_KIND_FINAL,
        )

        val upcomingTriggerAtMillis =
            reminder.triggerAtMillis - UPCOMING_REMINDER_ADVANCE_MILLIS
        if (reminder.ringOnReminder && upcomingTriggerAtMillis > System.currentTimeMillis()) {
            scheduleAlarm(
                context = context,
                reminder = reminder,
                triggerAtMillis = upcomingTriggerAtMillis,
                reminderKind = REMINDER_KIND_UPCOMING,
            )
        }
    }

    private fun scheduleAlarm(
        context: Context,
        reminder: ReminderAlarmPayload,
        triggerAtMillis: Long,
        reminderKind: String,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildAlarmPendingIntent(context, reminder, reminderKind)

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
        reminderKind: String,
    ): PendingIntent {
        val intent = Intent(context, TodoAlarmReceiver::class.java).apply {
            action = ACTION_TODO_REMINDER
            data = Uri.parse("mytodo://alarm/${reminder.id}/$reminderKind")
            putExtra(EXTRA_TODO_ID, reminder.id)
            putExtra(EXTRA_TODO_TITLE, reminder.title)
            putExtra(EXTRA_TODO_NOTES, reminder.notes)
            putExtra(EXTRA_TODO_TRIGGER_AT, reminder.triggerAtMillis)
            putExtra(EXTRA_TODO_RING_ON_REMINDER, reminder.ringOnReminder)
            putExtra(EXTRA_REMINDER_KIND, reminderKind)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCodeFor(reminder.id, reminderKind),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildAlarmPendingIntent(
        context: Context,
        todoId: Int,
        reminderKind: String,
    ): PendingIntent {
        val intent = Intent(context, TodoAlarmReceiver::class.java).apply {
            action = ACTION_TODO_REMINDER
            data = Uri.parse("mytodo://alarm/$todoId/$reminderKind")
            putExtra(EXTRA_TODO_ID, todoId)
            putExtra(EXTRA_REMINDER_KIND, reminderKind)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCodeFor(todoId, reminderKind),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildSuppressRingPendingIntent(
        context: Context,
        todoId: Int,
        triggerAtMillis: Long,
    ): PendingIntent {
        val intent = Intent(context, TodoAlarmReceiver::class.java).apply {
            action = ACTION_SUPPRESS_RING
            data = Uri.parse("mytodo://alarm/$todoId/suppress-ring/$triggerAtMillis")
            putExtra(EXTRA_TODO_ID, todoId)
            putExtra(EXTRA_TODO_TRIGGER_AT, triggerAtMillis)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCodeFor(todoId, "suppress"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun requestCodeFor(todoId: Int, reminderKind: String): Int =
        when (reminderKind) {
            REMINDER_KIND_UPCOMING -> upcomingNotificationId(todoId)
            "suppress" -> todoId + 2_000_000
            else -> todoId
        }

    private fun upcomingNotificationId(todoId: Int): Int =
        todoId + UPCOMING_NOTIFICATION_ID_OFFSET
}
