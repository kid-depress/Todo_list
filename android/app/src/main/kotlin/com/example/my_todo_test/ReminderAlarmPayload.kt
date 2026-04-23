package com.example.my_todo_test

data class ReminderAlarmPayload(
    val id: Int,
    val title: String,
    val notes: String,
    val triggerAtMillis: Long,
    val ringOnReminder: Boolean,
)
