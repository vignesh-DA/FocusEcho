import { ALARM } from '../shared/constants.js';

export const DISTRACTION_NOTIFICATION_ID = 'fe-distraction-active';
const ICON_URL = 'src/assets/icons/icon-128.png';

function isAlertable(session, distraction) {
  return Boolean(
    session?.active &&
    distraction?.host &&
    !['PAUSED', 'SESSION_PAUSED', 'IDLE'].includes(session.state),
  );
}

async function createNotification(session, distraction, level) {
  const host = String(distraction.host).slice(0, 180);
  await chrome.notifications.create(DISTRACTION_NOTIFICATION_ID, {
    type: 'basic',
    iconUrl: chrome.runtime.getURL(ICON_URL),
    title: `FocusEcho — Still on ${host}?`,
    message: 'Your focus session is active. Return to focus when you’re ready.',
    contextMessage: `Level ${Number(level) || 1} focus reminder`,
    priority: 2,
  });
}

export async function showDistractionNotification(session, distraction, level = 1) {
  if (!isAlertable(session, distraction)) return;
  await createNotification(session, distraction, level);
  await chrome.alarms.create(ALARM.DISTRACTION_NUDGE, {
    delayInMinutes: 0.5,
    periodInMinutes: 0.5,
  });
}

export async function clearDistractionNotification() {
  await chrome.alarms.clear(ALARM.DISTRACTION_NUDGE);
  await chrome.notifications.clear(DISTRACTION_NOTIFICATION_ID);
}

export async function repeatDistractionNotification(loadSession, loadDistraction) {
  const [session, distraction] = await Promise.all([
    loadSession(),
    loadDistraction(),
  ]);
  if (!isAlertable(session, distraction)) {
    await clearDistractionNotification();
    return false;
  }
  await createNotification(session, distraction, distraction.level);
  return true;
}

export async function focusDashboardFromNotification(notificationId) {
  if (notificationId !== DISTRACTION_NOTIFICATION_ID) return false;
  const stored = await chrome.storage.local.get('fe_dashboard_tab_id');
  const tabId = stored.fe_dashboard_tab_id;
  if (tabId == null) {
    const config = await chrome.storage.local.get('fe_config');
    const dashboardUrl = config.fe_config?.dashboard_origins?.[0];
    if (!dashboardUrl) return false;
    await chrome.tabs.create({ url: dashboardUrl, active: true });
    return true;
  }
  try {
    const tab = await chrome.tabs.get(tabId);
    await chrome.tabs.update(tabId, { active: true });
    await chrome.windows.update(tab.windowId, { focused: true });
    return true;
  } catch (_) {
    return false;
  }
}
