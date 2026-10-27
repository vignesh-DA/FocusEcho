package com.focusecho.ai

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject
import java.util.UUID

/** Durable at-least-once staging for native events awaiting Flutter SQLite. */
class OfflineEventStore(context: Context) : SQLiteOpenHelper(
    context.applicationContext,
    "focus_echo_offline_events.db",
    null,
    1,
) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE offline_events (
                delivery_id TEXT PRIMARY KEY NOT NULL,
                payload TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )""".trimIndent(),
        )
        db.execSQL("CREATE INDEX offline_events_created_at_idx ON offline_events(created_at)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    @Synchronized
    fun stage(rawPayload: String): String {
        val deliveryId = UUID.randomUUID().toString()
        val payload = JSONObject(rawPayload).put("delivery_id", deliveryId).toString()
        writableDatabase.insertOrThrow(
            "offline_events",
            null,
            ContentValues().apply {
                put("delivery_id", deliveryId)
                put("payload", payload)
                put("created_at", System.currentTimeMillis())
            },
        )
        return payload
    }

    @Synchronized
    fun pending(): List<Pair<String, String>> {
        val result = mutableListOf<Pair<String, String>>()
        readableDatabase.query(
            "offline_events",
            arrayOf("delivery_id", "payload"),
            null,
            null,
            null,
            null,
            "created_at ASC",
        ).use { cursor ->
            while (cursor.moveToNext()) result.add(cursor.getString(0) to cursor.getString(1))
        }
        return result
    }

    @Synchronized
    fun acknowledge(deliveryId: String): Boolean =
        writableDatabase.delete("offline_events", "delivery_id = ?", arrayOf(deliveryId)) > 0
}
