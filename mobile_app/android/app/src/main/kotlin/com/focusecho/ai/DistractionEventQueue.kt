package com.focusecho.ai

/**
 * Owns the per-session relapse counter that drives the
 * escalating intervention ladder. The counter resets when a new session
 * starts ([resetSession]) and increments on every distraction event.
 */
object DistractionEventQueue {
    @Volatile
    var relapseCount: Int = 0
        private set

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
