package com.focusecho.ai

/**
 * Thread-safe in-memory queue shared between FocusAccessibilityService and
 * FocusDetectionService.  The AccessibilityService enqueues distraction
 * payloads here; the DetectionService drains them on each poll tick and
 * forwards them to Flutter via the EventChannel sink.
 *
 * This replaces the previous MethodChannel approach which was null whenever
 * the Flutter UI was destroyed (app killed / backgrounded).
 *
 * Feature 2 — also owns the per-session relapse counter that drives the
 * escalating intervention ladder. The counter resets when a new session
 * starts ([resetSession]) and increments on every distraction event.
 */
object DistractionEventQueue {
    private val queue = mutableListOf<String>()

    @Volatile
    var relapseCount: Int = 0
        private set

    @Synchronized
    fun add(event: String) {
        queue.add(event)
        // Cap to prevent unbounded memory growth
        if (queue.size > 200) queue.removeAt(0)
    }

    @Synchronized
    fun drainAll(): List<String> {
        val copy = queue.toList()
        queue.clear()
        return copy
    }

    /** Feature 2 — registers a relapse and returns the 1-based count. */
    @Synchronized
    fun registerRelapse(): Int {
        relapseCount += 1
        return relapseCount
    }

    /** Feature 2 — resets the ladder when a new session starts. */
    @Synchronized
    fun resetSession() {
        relapseCount = 0
    }
}