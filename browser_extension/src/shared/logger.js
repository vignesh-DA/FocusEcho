/**
 * @fileoverview FocusEcho structured logger — mirrors Python's logging module.
 * Provides levels: DEBUG, INFO, WARN, ERROR with timestamps, subsystem tags,
 * and clear formatted console output.
 *
 * Usage:
 *   import { Logger } from '../shared/logger.js';
 *   const log = Logger.tag('SW');
 *   log.d('Evaluating navigation', { url, tabId });
 *   log.i('Focus session started', { sessionId, intention });
 *   log.w('Fallback to local cache', error);
 *   log.e('Failed to sync events', error);
 */

export const LogLevel = Object.freeze({
  DEBUG: 0,
  INFO:  1,
  WARN:  2,
  ERROR: 3,
});

let _currentLevel = LogLevel.DEBUG;

function _timestamp() {
  const n = new Date();
  const h  = String(n.getHours()).padStart(2, '0');
  const m  = String(n.getMinutes()).padStart(2, '0');
  const s  = String(n.getSeconds()).padStart(2, '0');
  const ms = String(n.getMilliseconds()).padStart(3, '0');
  return `${h}:${m}:${s}.${ms}`;
}

export const Logger = {
  /**
   * Set minimum level to emit (LogLevel.DEBUG, LogLevel.INFO, etc.)
   * @param {number} level
   */
  setLevel(level) {
    _currentLevel = level;
  },

  /**
   * DEBUG — granular step tracing
   */
  debug(tag, msg, ...args) {
    if (_currentLevel <= LogLevel.DEBUG) {
      console.log(`[FE DEBUG] [${tag}] ${_timestamp()} → ${msg}`, ...args);
    }
  },

  /**
   * INFO — milestones (session start/stop, sync complete, tab switch)
   */
  info(tag, msg, ...args) {
    if (_currentLevel <= LogLevel.INFO) {
      console.info(`[FE INFO ] [${tag}] ${_timestamp()} → ${msg}`, ...args);
    }
  },

  /**
   * WARN — recoverable issues (offline, fallback, retries)
   */
  warn(tag, msg, ...args) {
    if (_currentLevel <= LogLevel.WARN) {
      console.warn(`[FE WARN ] [${tag}] ${_timestamp()} → ${msg}`, ...args);
    }
  },

  /**
   * ERROR — unhandled exceptions or rejected promises
   */
  error(tag, msg, err, ...args) {
    if (_currentLevel <= LogLevel.ERROR) {
      if (err) {
        console.error(`[FE ERROR] [${tag}] ${_timestamp()} → ${msg}\n  ↳ Error:`, err, ...args);
      } else {
        console.error(`[FE ERROR] [${tag}] ${_timestamp()} → ${msg}`, ...args);
      }
    }
  },

  /**
   * Factory function to create a tagged logger for a module (e.g., SW, SM, SYNC, AM)
   * @param {string} tag
   */
  tag(tag) {
    return {
      d: (msg, ...args) => Logger.debug(tag, msg, ...args),
      i: (msg, ...args) => Logger.info(tag, msg, ...args),
      w: (msg, ...args) => Logger.warn(tag, msg, ...args),
      e: (msg, err, ...args) => Logger.error(tag, msg, err, ...args),
    };
  },
};
