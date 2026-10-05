/**
 * @fileoverview Per-tab state management in chrome.storage.session.
 * Hostname only — full URL is never stored.
 */

import { SK } from '../shared/constants.js';

/**
 * Load the tab states map from session storage.
 * @returns {Promise<Record<number, import('../shared/storage-schema.js').TabState>>}
 */
export async function loadTabStates() {
  const result = await chrome.storage.session.get(SK.TAB_STATES);
  return result[SK.TAB_STATES] ?? {};
}

/**
 * Persist the tab states map.
 * @param {Record<number, import('../shared/storage-schema.js').TabState>} tabStates
 */
export async function saveTabStates(tabStates) {
  await chrome.storage.session.set({ [SK.TAB_STATES]: tabStates });
}

/**
 * Record a tab becoming active.
 * @param {number} tabId
 * @param {string} host  - already normalised hostname
 * @param {boolean} isDistracting
 * @param {number} [now]
 */
export async function markTabActive(tabId, host, isDistracting, now = Date.now()) {
  const tabStates = await loadTabStates();
  tabStates[tabId] = { host, is_distracting: isDistracting, active_start: now };
  await saveTabStates(tabStates);
}

/**
 * Record a tab becoming inactive (another tab was focused, or the tab navigated away).
 * @param {number} tabId
 */
export async function markTabInactive(tabId) {
  const tabStates = await loadTabStates();
  if (tabStates[tabId]) {
    tabStates[tabId] = { ...tabStates[tabId], active_start: null };
    await saveTabStates(tabStates);
  }
}

/**
 * Remove a closed tab from tracking.
 * @param {number} tabId
 */
export async function removeTab(tabId) {
  const tabStates = await loadTabStates();
  delete tabStates[tabId];
  await saveTabStates(tabStates);
}

/**
 * Get the state for a specific tab.
 * @param {number} tabId
 * @returns {Promise<import('../shared/storage-schema.js').TabState|null>}
 */
export async function getTabState(tabId) {
  const tabStates = await loadTabStates();
  return tabStates[tabId] ?? null;
}
