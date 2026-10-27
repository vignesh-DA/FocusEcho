/**
 * @fileoverview Database synchronization module for FocusEcho browser extension.
 * Responsible for writing all distraction, recovery, and intervention activities
 * to the cloud database (Supabase) and FastAPI backend.
 *
 * Supports:
 *   1. Direct Supabase PostgREST upsert (with offline queue & retry)
 *   2. Foreign-key safety by ensuring focus_sessions parent row exists
 *   3. Supabase Realtime broadcast for instant cross-device nudges
 *   4. Backend /api/v1/events/batch sync fallback
 */

import { SK } from '../shared/constants.js';
import { Logger } from '../shared/logger.js';

const log = Logger.tag('DB-SYNC');

// Default project configuration (mirrors backend/.env)
export const DEFAULT_SUPABASE_URL = 'https://dfqwjobcbhifvuwwroys.supabase.co';
export const DEFAULT_SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRmcXdqb2JjYmhpZnZ1d3dyb3lzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMjEzMjQsImV4cCI6MjA5MTg5NzMyNH0.Bcj8It-Z8f-jkj3VeVehsIYyMmS-cJETeSB0xzQ6k9s';
export const DEFAULT_BACKEND_URL = 'http://localhost:8000';

/**
 * Maps known domains to friendly app labels.
 * @param {string} domain
 * @returns {string}
 */
export function getFriendlyAppLabel(domain) {
  if (!domain) return 'Web Browser';
  const clean = domain.toLowerCase().replace(/^(www\.|m\.)/, '');
  const known = {
    'youtube.com':   'YouTube',
    'twitter.com':   'X (Twitter)',
    'x.com':         'X',
    'reddit.com':    'Reddit',
    'instagram.com': 'Instagram',
    'facebook.com':  'Facebook',
    'tiktok.com':    'TikTok',
    'netflix.com':   'Netflix',
    'twitch.tv':     'Twitch',
    'linkedin.com':  'LinkedIn',
    'pinterest.com': 'Pinterest',
    'discord.com':   'Discord',
  };
  if (known[clean]) return known[clean];
  const name = clean.split('.')[0] || 'Web';
  return name.charAt(0).toUpperCase() + name.slice(1);
}

/**
 * Loads cloud sync settings from storage.
 * @returns {Promise<{
 *   supabaseUrl: string,
 *   supabaseAnonKey: string,
 *   backendUrl: string,
 *   authToken: string|null,
 *   refreshToken: string|null,
 *   userId: string|null
 * }>}
 */
export async function getSyncCredentials() {
  const r = await chrome.storage.local.get([
    'fe_supabase_url',
    'fe_supabase_anon_key',
    'fe_backend_url',
    'fe_auth_token',
    'fe_refresh_token',
    'fe_user_id',
    SK.CONFIG,
  ]);
  const config = r[SK.CONFIG] || {};

  return {
    supabaseUrl:     r.fe_supabase_url || config.supabase_url || DEFAULT_SUPABASE_URL,
    supabaseAnonKey: r.fe_supabase_anon_key || config.supabase_anon_key || DEFAULT_SUPABASE_ANON_KEY,
    backendUrl:      r.fe_backend_url || config.backend_url || DEFAULT_BACKEND_URL,
    authToken:       r.fe_auth_token || config.auth_token || null,
    refreshToken:    r.fe_refresh_token || config.refresh_token || null,
    userId:          r.fe_user_id || config.user_id || null,
  };
}

/**
 * Saves or updates cloud sync credentials in local storage.
 * @param {object} creds
 */
export async function saveSyncCredentials(creds) {
  const updates = {};
  if (creds.supabaseUrl)     updates.fe_supabase_url = creds.supabaseUrl;
  if (creds.supabaseAnonKey) updates.fe_supabase_anon_key = creds.supabaseAnonKey;
  if (creds.backendUrl)      updates.fe_backend_url = creds.backendUrl;
  if (creds.authToken)       updates.fe_auth_token = creds.authToken;
  if (creds.refreshToken)    updates.fe_refresh_token = creds.refreshToken;
  if (creds.userId)          updates.fe_user_id = creds.userId;
  await chrome.storage.local.set(updates);
}

/** Refreshes the short-lived access token without logging token material. */
export async function refreshAuthSession(creds) {
  if (!creds?.refreshToken || !creds?.supabaseUrl || !creds?.supabaseAnonKey) return null;
  try {
    const response = await fetch(`${creds.supabaseUrl}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: {
        apikey: creds.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ refresh_token: creds.refreshToken }),
    });
    if (!response.ok) return null;
    const payload = await response.json();
    if (!payload?.access_token) return null;
    const refreshed = {
      ...creds,
      authToken: payload.access_token,
      refreshToken: payload.refresh_token || creds.refreshToken,
      userId: payload.user?.id || creds.userId,
    };
    await saveSyncCredentials(refreshed);
    return refreshed;
  } catch (_) {
    return null;
  }
}

/** Makes one authenticated request and, after one 401, refreshes and retries once. */
async function fetchWithAuthRefresh(url, options, creds) {
  if (!creds?.authToken || !creds?.userId) {
    return { response: null, credentials: creds };
  }
  const send = (token) => fetch(url, {
    ...options,
    headers: {
      ...(options?.headers || {}),
      Authorization: `Bearer ${token}`,
    },
  });

  let credentials = creds;
  let response = await send(credentials.authToken);
  if (response.status === 401 && credentials.refreshToken) {
    const refreshed = await refreshAuthSession(credentials);
    if (refreshed && refreshed.authToken !== credentials.authToken) {
      credentials = refreshed;
      response = await send(credentials.authToken);
    }
  }
  return { response, credentials };
}

/**
 * Transforms an extension queued event into the Supabase distraction_events row schema.
 * @param {object} queuedEvent
 * @param {object|null} activeSession
 * @returns {object}
 */
export function formatDistractionEventRow(queuedEvent, activeSession) {
  const ev = queuedEvent.event || queuedEvent;
  const now = new Date();
  const triggeredAt = ev.distraction_started_at || ev.timestamp || now.toISOString();
  const level = ev.escalation_level ?? ev.from_level ?? 1;

  let riskScore = 'low';
  let riskScoreNumeric = 0.3;
  if (level === 2) {
    riskScore = 'medium';
    riskScoreNumeric = 0.6;
  } else if (level >= 3) {
    riskScore = 'high';
    riskScoreNumeric = 0.9;
  }

  const isRecovered = ev.event_type === 'recovery' || ev.event_type === 'intentional_switch';
  const recoveryTimeSec = ev.time_on_site_ms ? Math.round(ev.time_on_site_ms / 1000) : null;
  const timeAwaySec = recoveryTimeSec;

  let sessionMin = null;
  if (activeSession?.started_at) {
    const started = new Date(activeSession.started_at).getTime();
    const eventTime = new Date(triggeredAt).getTime();
    sessionMin = Math.max(0, Math.floor((eventTime - started) / 60000));
  }

  return {
    id:                           ev.id || ev.related_event_id || crypto.randomUUID(),
    session_id:                   ev.session_id || activeSession?.session_id,
    package_name:                 ev.domain || 'unknown_site',
    app_label:                    getFriendlyAppLabel(ev.domain),
    triggered_at:                 triggeredAt,
    recovered_at:                 isRecovered ? (ev.timestamp || now.toISOString()) : null,
    recovery_time_seconds:        recoveryTimeSec,
    risk_score:                   riskScore,
    event_type:                   isRecovered ? 'distraction' : (ev.event_type || 'distraction'),
    app_category:                 ev.category || 'unknown',
    time_away_seconds:            timeAwaySec,
    risk_score_numeric:           riskScoreNumeric,
    was_notification_triggered:   true,
    returned_to_origin:           false,
    switch_stack_depth:           1,
    time_of_day_hour:             now.getHours(),
    day_of_week:                  now.getDay() === 0 ? 7 : now.getDay(),
    session_minute_when_occurred: sessionMin,
    escalation_level:             level,
    is_recovered:                 isRecovered,
    is_synced:                    1,
  };
}

/** Converts and coalesces queued lifecycle updates by their stable event ID. */
export function formatQueuedEventRows(queue, activeSession) {
  const rowsById = new Map();
  for (const item of queue) {
    const row = formatDistractionEventRow(item, activeSession);
    const prior = rowsById.get(row.id);
    // A queued recovery updates the original distraction row. Collapse the
    // pair before PostgREST upsert so one batch never contains duplicate IDs.
    if (!prior || row.is_recovered || !prior.is_recovered) rowsById.set(row.id, row);
  }
  return [...rowsById.values()];
}

/**
 * Ensures the parent focus_session row exists in Supabase so foreign key checks pass.
 * @param {object} session
 * @param {object} creds
 */
async function ensureFocusSessionInCloud(session, creds) {
  if (!session?.session_id) return creds;
  let activeCreds = creds;
  const { supabaseUrl, supabaseAnonKey, userId } = activeCreds;

  if (!userId || !activeCreds.authToken) {
    console.warn('[FE DB-SYNC] Waiting for a Supabase auth session before syncing.');
    return activeCreds;
  }

  const sessionRow = {
    id:                 session.session_id,
    user_id:            userId,
    start_time:         new Date(session.started_at || Date.now()).toISOString(),
    end_time:           session.active
      ? null
      : new Date(session.ended_at || Date.now()).toISOString(),
    productive_app:     'Chrome',
    intent:             session.intention || 'Web Focus Session',
    total_distractions: session.distraction_count || 0,
    parked_items: Array.isArray(session.parked_items) ? session.parked_items : null,
    status:             session.active ? 'active' : 'completed',
    is_synced:          1,
  };

  try {
    const result = await fetchWithAuthRefresh(`${supabaseUrl}/rest/v1/focus_sessions`, {
      method: 'POST',
      headers: {
        'apikey':        supabaseAnonKey,
        'Content-Type':  'application/json',
        'Prefer':        'resolution=merge-duplicates',
      },
      body: JSON.stringify(sessionRow),
    }, activeCreds);
    activeCreds = result.credentials || activeCreds;
    const resp = result.response;
    if (!resp) return activeCreds;
    if (!resp.ok) {
      log.w(`focus_session parent upsert warning (${resp.status})`);
    }
  } catch (err) {
    log.w(`focus_session parent network skip (${err.name || 'Error'})`);
  }
  return activeCreds;
}

/**
 * Broadcasts distraction nudge over Supabase Realtime for cross-device awareness.
 * @param {object} row
 * @param {object} creds
 */
async function broadcastCrossSurfaceIntervention(row, creds) {
  const { supabaseUrl, supabaseAnonKey, authToken, userId } = creds;
  if (!userId || !authToken) return;


  const channel = `focusecho-interventions:${userId}`;
  const payload = {
    surface:          'browser',
    host_or_app:      row.app_label || row.package_name,
    escalation_level: row.escalation_level || 1,
    sent_at:          new Date().toISOString(),
  };

  try {
    // Post to Supabase Realtime REST broadcast endpoint
    const result = await fetchWithAuthRefresh(`${supabaseUrl}/rest/v1/rpc/broadcast_intervention`, {
      method: 'POST',
      headers: {
        'apikey':        supabaseAnonKey,
        'Content-Type':  'application/json',
      },
      body: JSON.stringify({ p_channel: channel, p_payload: payload }),
    }, creds);
    return result.credentials;
  } catch (_) {}
}

/**
 * Synchronizes all queued distraction & recovery events to Supabase and Backend.
 * Retries on next alarm if network is unreachable.
 *
 * @param {object|null} [activeSession]
 * @returns {Promise<{ synced: number, remaining: number, error?: string }>}
 */
export async function syncEventQueue(activeSession = null) {
  const queueData = await chrome.storage.local.get(SK.EVENT_QUEUE);
  const queue = queueData[SK.EVENT_QUEUE] || [];
  if (queue.length === 0) {
    return { synced: 0, remaining: 0 };
  }

  const creds = await getSyncCredentials();
  let activeCreds = creds;
  if (!activeCreds.authToken && activeCreds.refreshToken) {
    activeCreds = await refreshAuthSession(activeCreds) || activeCreds;
  }
  const { supabaseUrl, supabaseAnonKey, backendUrl, userId } = activeCreds;

  // Never attempt an authenticated write with the public anon key as the
  // bearer token. Keep the queue local until a real user session is present.
  if (!userId || !activeCreds.authToken) {
    return { synced: 0, remaining: queue.length, error: 'Authentication required — queued for retry' };
  }

  // 1. Ensure active focus_session exists in DB first
  if (activeSession) {
    activeCreds = await ensureFocusSessionInCloud(activeSession, activeCreds) || activeCreds;
  } else if (queue.length > 0) {
    const firstEv = queue[0].event || queue[0];
    if (firstEv.session_id) {
      activeCreds = await ensureFocusSessionInCloud({
        session_id: firstEv.session_id,
        started_at: firstEv.distraction_started_at || firstEv.timestamp,
        active: false,
        intention: 'Web Focus Session',
        distraction_count: queue.length,
      }, activeCreds) || activeCreds;
    }
  }

  // 2. Prepare payload rows. The deployed migrations include escalation_level,
  // so preserve it across browser/mobile/cloud paths for consistent analytics.
  const rows = formatQueuedEventRows(queue, activeSession);

  let writeSuccess = false;

  // Try direct Supabase PostgREST insert/upsert
  try {
    const result = await fetchWithAuthRefresh(`${supabaseUrl}/rest/v1/distraction_events`, {
      method: 'POST',
      headers: {
        'apikey':        supabaseAnonKey,
        'Content-Type':  'application/json',
        'Prefer':        'resolution=merge-duplicates',
      },
      body: JSON.stringify(rows),
    }, activeCreds);
    activeCreds = result.credentials || activeCreds;
    const res = result.response;
    if (res?.ok) writeSuccess = true;
    if (res?.ok || writeSuccess) {
      writeSuccess = true;
      log.i(`Successfully wrote ${rows.length} events to Supabase distraction_events!`);
    } else if (res) {
      log.w(`Supabase write failed (${res.status})`);
    }
  } catch (netErr) {
    log.w(`Network offline or Supabase unreachable: ${netErr.message}`);
  }

  // Fallback to FastAPI backend /api/v1/events/batch if direct Supabase failed
  if (!writeSuccess && backendUrl) {
    try {
      const backendRes = await fetch(`${backendUrl}/api/v1/events/batch`, {
        method: 'POST',
        headers: {
          'Content-Type':  'application/json',
          ...(activeCreds.authToken ? { 'Authorization': `Bearer ${activeCreds.authToken}` } : {}),
        },
        body: JSON.stringify({
          events: rows,
          user_id: userId,
        }),
      });

      if (backendRes.ok) {
        writeSuccess = true;
        log.i(`Successfully synced ${rows.length} events via FastAPI backend!`);
      }
    } catch (bErr) {
      log.w(`Backend batch endpoint unreachable: ${bErr.message}`);
    }
  }

  // If write succeeded, prune synced items from offline queue
  if (writeSuccess) {
    // Broadcast latest distraction event if applicable
    const latestDistraction = rows.filter(r => !r.is_recovered).pop();
    if (latestDistraction) {
      await broadcastCrossSurfaceIntervention(latestDistraction, activeCreds);
    }

    await chrome.storage.local.set({ [SK.EVENT_QUEUE]: [] });
    return { synced: rows.length, remaining: 0 };
  }

  return { synced: 0, remaining: queue.length, error: 'Database unreachable — queued for retry' };
}
