package com.example.my_todo_test

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object TodoAlarmStore {
    private const val PREFS_NAME = "todo_alarm_store"
    private const val REMINDERS_KEY = "scheduled_reminders"

    fun save(context: Context, reminders: List<ReminderAlarmPayload>) {
        val array = JSONArray()
        reminders.forEach { reminder ->
            array.put(
                JSONObject().apply {
                    put("id", reminder.id)
                    put("title", reminder.title)
                    put("notes", reminder.notes)
                    put("triggerAtMillis", reminder.triggerAtMillis)
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
                        ),
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun remove(context: Context, todoId: Int) {
        val updated = load(context).filterNot { reminder -> reminder.id == todoId }
        save(context, updated)
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
