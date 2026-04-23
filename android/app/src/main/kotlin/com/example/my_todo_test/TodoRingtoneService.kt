package com.example.my_todo_test

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class TodoRingtoneService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var activeTodoId: Int = -1

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startRinging(intent)
            ACTION_STOP -> stopRinging(intent)
            else -> stopSelf(startId)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }

    private fun startRinging(intent: Intent) {
        val todoId = intent.getIntExtra(EXTRA_TODO_ID, -1)
        val triggerAtMillis = intent.getLongExtra(EXTRA_TODO_TRIGGER_AT, -1L)
        if (todoId < 0) {
            stopSelf()
            return
        }

        val title = intent.getStringExtra(EXTRA_TODO_TITLE).orEmpty().ifBlank {
            "Todo reminder"
        }
        val body = intent.getStringExtra(EXTRA_TODO_BODY).orEmpty().ifBlank {
            "It's time to check this todo."
        }

        TodoAlarmScheduler.ensureNotificationChannels(this)
        activeTodoId = todoId
        saveActiveTodoId(todoId)

        val notification = TodoAlarmScheduler.buildReminderNotification(
            context = this,
            todoId = todoId,
            title = title,
            body = body,
            triggerAtMillis = triggerAtMillis,
            ringOnReminder = true,
        )
        startForeground(todoId, notification)

        if (mediaPlayer?.isPlaying == true) {
            return
        }

        releasePlayer()
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(TodoAlarmScheduler.reminderAudioAttributes())
            setDataSource(this@TodoRingtoneService, TodoAlarmScheduler.reminderSoundUri())
            isLooping = true
            prepare()
            start()
        }
    }

    private fun stopRinging(intent: Intent) {
        val todoId = intent.getIntExtra(EXTRA_TODO_ID, activeTodoId)
        val triggerAtMillis = intent.getLongExtra(EXTRA_TODO_TRIGGER_AT, -1L)
        releasePlayer()

        if (todoId >= 0 && triggerAtMillis >= 0L) {
            TodoAlarmStore.suppressRing(this, todoId, triggerAtMillis)
        }

        if (todoId >= 0) {
            NotificationManagerCompat.from(this).cancel(todoId)
        }

        clearActiveTodoId()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun releasePlayer() {
        runCatching {
            val player = mediaPlayer ?: return@runCatching
            player.setOnCompletionListener(null)
            player.setOnPreparedListener(null)
            player.setOnErrorListener(null)
            if (player.isPlaying) {
                player.stop()
            }
            player.release()
        }
        mediaPlayer = null
    }

    private fun saveActiveTodoId(todoId: Int) {
        prefs(this).edit().putInt(ACTIVE_TODO_ID_KEY, todoId).apply()
    }

    private fun clearActiveTodoId() {
        prefs(this).edit().remove(ACTIVE_TODO_ID_KEY).apply()
    }

    companion object {
        private const val PREFS_NAME = "todo_ringtone_service"
        private const val ACTIVE_TODO_ID_KEY = "active_todo_id"
        private const val ACTION_START = "com.example.my_todo_test.START_RINGTONE"
        private const val ACTION_STOP = "com.example.my_todo_test.STOP_RINGTONE"
        private const val EXTRA_TODO_ID = "todo_id"
        private const val EXTRA_TODO_TITLE = "todo_title"
        private const val EXTRA_TODO_BODY = "todo_body"
        private const val EXTRA_TODO_TRIGGER_AT = "todo_trigger_at"

        fun start(
            context: Context,
            todoId: Int,
            title: String,
            body: String,
            triggerAtMillis: Long,
        ) {
            val intent = Intent(context, TodoRingtoneService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TODO_ID, todoId)
                putExtra(EXTRA_TODO_TITLE, title)
                putExtra(EXTRA_TODO_BODY, body)
                putExtra(EXTRA_TODO_TRIGGER_AT, triggerAtMillis)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun buildStopPendingIntent(
            context: Context,
            todoId: Int,
            title: String,
            body: String,
            triggerAtMillis: Long,
        ): PendingIntent {
            val intent = Intent(context, TodoRingtoneService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_TODO_ID, todoId)
                putExtra(EXTRA_TODO_TITLE, title)
                putExtra(EXTRA_TODO_BODY, body)
                putExtra(EXTRA_TODO_TRIGGER_AT, triggerAtMillis)
            }
            return PendingIntent.getService(
                context,
                todoId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun stop(context: Context, todoId: Int) {
            val intent = Intent(context, TodoRingtoneService::class.java).apply {
                action = ACTION_STOP
                putExtra(EXTRA_TODO_ID, todoId)
            }
            context.startService(intent)
        }

        fun activeTodoId(context: Context): Int? {
            val todoId = prefs(context).getInt(ACTIVE_TODO_ID_KEY, -1)
            return todoId.takeIf { it >= 0 }
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
}
