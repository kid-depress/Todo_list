package com.example.my_todo_test

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object TodoAlarmStore {
    private const val PREFS_NAME = "todo_alarm_store"
    private const val REMINDERS_KEY = "scheduled_reminders"
    private const val SUPPRESSED_RING_KEY = "suppressed_ring_reminders"

    fun save(context: Context, reminders: List<ReminderAlarmPayload>) {
        val array = JSONArray()
        reminders.forEach { reminder ->
            array.put(
                JSONObject().apply {
                    put("id", reminder.id)
                    put("title", reminder.title)
                    put("notes", reminder.notes)
                    put("triggerAtMillis", reminder.triggerAtMillis)
                    put("ringOnReminder", reminder.ringOnReminder)
                },
            )
        }

        prefs(context)
            .edit()
            .putString(REMINDERS_KEY, array.toString())
            .apply()
    }

    fun load(context: Context): List<ReminderAlarmPayload> {
        val source = prefs(context).getString(REMINDERS_KEY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(source)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val id = item.optInt("id", -1)
                    val triggerAtMillis = item.optLong("triggerAtMillis", -1L)
                    if (id < 0 || triggerAtMillis < 0L) {
                        continue
                    }
                    add(
                        ReminderAlarmPayload(
                            id = id,
                            title = item.optString("title", ""),
                            notes = item.optString("notes", ""),
                            triggerAtMillis = triggerAtMillis,
                            ringOnReminder = item.optBoolean("ringOnReminder", false),
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun remove(context: Context, todoId: Int) {
        val updated = load(context).filterNot { reminder -> reminder.id == todoId }
        save(context, updated)
        clearSuppressedRing(context, todoId)
    }

    fun suppressRing(context: Context, todoId: Int, triggerAtMillis: Long) {
        val updated = loadSuppressedRing(context)
            .filterNot { item -> item.first == todoId }
            .toMutableList()
            .apply { add(todoId to triggerAtMillis) }
        saveSuppressedRing(context, updated)
    }

    fun isRingSuppressed(context: Context, todoId: Int, triggerAtMillis: Long): Boolean {
        cleanupSuppressedRing(context)
        return loadSuppressedRing(context).any { item ->
            item.first == todoId && item.second == triggerAtMillis
        }
    }

    fun clearSuppressedRing(context: Context, todoId: Int) {
        val updated = loadSuppressedRing(context)
            .filterNot { item -> item.first == todoId }
        saveSuppressedRing(context, updated)
    }

    fun retainSuppressedRingFor(
        context: Context,
        reminders: List<ReminderAlarmPayload>,
    ) {
        val allowed = reminders
            .map { reminder -> reminder.id to reminder.triggerAtMillis }
            .toSet()
        val updated = loadSuppressedRing(context)
            .filter { item -> allowed.contains(item) }
        saveSuppressedRing(context, updated)
    }

    private fun cleanupSuppressedRing(context: Context) {
        val now = System.currentTimeMillis()
        val updated = loadSuppressedRing(context)
            .filter { item -> item.second >= now - 24 * 60 * 60 * 1000L }
        saveSuppressedRing(context, updated)
    }

    private fun loadSuppressedRing(context: Context): List<Pair<Int, Long>> {
        val source = prefs(context).getString(SUPPRESSED_RING_KEY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(source)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val id = item.optInt("id", -1)
                    val triggerAtMillis = item.optLong("triggerAtMillis", -1L)
                    if (id < 0 || triggerAtMillis < 0L) {
                        continue
                    }
                    add(id to triggerAtMillis)
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun saveSuppressedRing(context: Context, items: List<Pair<Int, Long>>) {
        val array = JSONArray()
        items.forEach { (id, triggerAtMillis) ->
            array.put(
                JSONObject().apply {
                    put("id", id)
                    put("triggerAtMillis", triggerAtMillis)
                },
            )
        }
        prefs(context)
            .edit()
            .putString(SUPPRESSED_RING_KEY, array.toString())
            .apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
