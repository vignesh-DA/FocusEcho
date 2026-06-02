package com.focusecho.ai

/**
 * Thread-safe in-memory queue shared between FocusAccessibilityService and
 * FocusDetectionService.  The AccessibilityService enqueues distraction
 * payloads here; the DetectionService drains them on each poll tick and
 * forwards them to Flutter via the EventChannel sink.
 *
 * This replaces the previous MethodChannel approach which was null whenever
 * the Flutter UI was destroyed (app killed / backgrounded).
 */
object DistractionEventQueue {
    private val queue = mutableListOf<String>()

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
}
