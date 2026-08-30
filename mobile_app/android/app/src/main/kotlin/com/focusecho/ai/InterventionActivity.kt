package com.focusecho.ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Feature 2 — full-screen escalating intervention (levels 2-3).
 *
 * Level 2 (relapse 2-3): distraction count + session intent with
 *   [Return to Focus] / [Take a Break].
 * Level 3 (relapse 4+): [Pause Session] / [Return to Focus] — no
 *   dismiss-and-ignore option.
 *
 * Every show / button press is forwarded to Flutter through
 * [DistractionEventQueue] so the intervention_event table stays complete.
 */
class InterventionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )
        window.setBackgroundDrawable(ColorDrawable(Color.parseColor("#B3000000")))

        val level = intent.getIntExtra(EXTRA_LEVEL, 2)
        val distractionCount = intent.getIntExtra(EXTRA_COUNT, 0)
        val appLabel = intent.getStringExtra(EXTRA_APP_LABEL) ?: "a distracting app"
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val sessionIntent = prefs.getString("flutter.session_intent", "") ?: ""

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = if (level >= 3) "⚠️ Repeated drift detected" else "⚠️ Focus check"
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
        }
        root.addView(title)

        val detail = TextView(this).apply {
            text = buildString {
                append("You have drifted $distractionCount time(s) this session — ")
                append("last: $appLabel.\n\n")
                if (sessionIntent.isNotBlank()) append("Your goal: \"$sessionIntent\"")
            }
            setTextColor(Color.parseColor("#DDDDDD"))
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 32)
        }
        root.addView(detail)

        if (level >= 3) {
            // Level 3 — forced choice: pause or return. No ignore option.
            root.addView(makeButton("⏸ Pause Session") {
                reportAction(level, "pause_session")
                finish()
            })
            root.addView(makeButton("🎯 Return to Focus") {
                reportAction(level, "return_to_focus")
                launchFocusEcho()
                finish()
            })
        } else {
            // Level 2 — full-screen alert with a break option.
            root.addView(makeButton("🎯 Return to Focus") {
                reportAction(level, "return_to_focus")
                launchFocusEcho()
                finish()
            })
            root.addView(makeButton("☕ Take a Break") {
                reportAction(level, "take_break")
                finish()
            })
        }

        setContentView(root)
        reportShown(level)
    }

    private fun makeButton(label: String, onClick: () -> Unit): Button {
        return Button(this).apply {
            text = label
            setOnClickListener { onClick() }
        }
    }

    private fun reportShown(level: Int) {
        DistractionEventQueue.add(
            org.json.JSONObject()
                .put("eventType", "intervention_shown")
                .put("level", level)
                .put("timestamp", java.time.Instant.now().toString())
                .toString()
        )
    }

    private fun reportAction(level: Int, action: String) {
        DistractionEventQueue.add(
            org.json.JSONObject()
                .put("eventType", "intervention_action")
                .put("level", level)
                .put("action", action)
                .put("timestamp", java.time.Instant.now().toString())
                .toString()
        )
    }

    private fun launchFocusEcho() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        startActivity(intent)
    }

    companion object {
        const val EXTRA_LEVEL = "level"
        const val EXTRA_COUNT = "distraction_count"
        const val EXTRA_APP_LABEL = "app_label"

        fun start(context: Context, level: Int, distractionCount: Int, appLabel: String) {
            val intent = Intent(context, InterventionActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra(EXTRA_LEVEL, level)
                putExtra(EXTRA_COUNT, distractionCount)
                putExtra(EXTRA_APP_LABEL, appLabel)
            }
            context.startActivity(intent)
        }
    }
}