/**
 * @fileoverview FocusEcho Production Popup Controller (EXT-3).
 * Interacts with background service worker to display active session state,
 * start/stop focus sessions, and open options.
 */

document.addEventListener('DOMContentLoaded', async () => {
  const optLink       = document.getElementById('opt-link');
  const badgeStatus   = document.getElementById('badge-status');
  const viewIdle      = document.getElementById('view-idle');
  const viewActive    = document.getElementById('view-active');
  const inputIntention= document.getElementById('input-intention');
  const btnStart      = document.getElementById('btn-start');
  const btnStop       = document.getElementById('btn-stop');
  const txtIntention  = document.getElementById('txt-intention');
  const valCount      = document.getElementById('val-count');
  const valState      = document.getElementById('val-state');
  const inputParking  = document.getElementById('input-parking');
  const parkingList   = document.getElementById('parking-list');
  const parkingNote   = document.getElementById('parking-note');

  // Open options page link (Required by CHECK-7 test)
  if (optLink) {
    optLink.addEventListener('click', (e) => {
      e.preventDefault();
      chrome.runtime.openOptionsPage();
    });
  }

  // Refresh current state from Service Worker
  async function refresh() {
    try {
      const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_get_state' });
      if (!resp || !resp.ok) return;

      const session = resp.session;
      const isActive = session && session.active;

      if (isActive) {
        viewIdle.style.display = 'none';
        viewActive.style.display = 'block';

        txtIntention.textContent = session.intention || 'Focus Session';
        valCount.textContent = session.distraction_count ?? 0;
        valState.textContent = session.state || 'MONITORING';
        parkingList.replaceChildren();
        for (const item of (session.parked_items || [])) {
          const li = document.createElement('li');
          const text = document.createElement('span');
          text.textContent = item;
          const remove = document.createElement('button');
          remove.className = 'parking-remove';
          remove.type = 'button';
          remove.textContent = '×';
          remove.addEventListener('click', async () => {
            await chrome.runtime.sendMessage({ type: 'fe:parking_remove', item });
            await refresh();
          });
          li.append(text, remove);
          parkingList.append(li);
        }
        parkingNote.textContent = session.session_id
          ? `${(session.parked_items || []).length}/20 saved for this session`
          : 'No shared session yet; items stay local.';

        if (session.state?.includes('L1') || session.state?.includes('L2') || session.state?.includes('L3')) {
          badgeStatus.className = 'status-badge status-distracted';
          badgeStatus.textContent = session.state;
        } else {
          badgeStatus.className = 'status-badge status-active';
          badgeStatus.textContent = 'FOCUSING';
        }
      } else {
        viewIdle.style.display = 'block';
        viewActive.style.display = 'none';
        badgeStatus.className = 'status-badge status-idle';
        badgeStatus.textContent = 'IDLE';
        parkingList.replaceChildren();
        parkingNote.textContent = '';
      }
    } catch (e) {
      console.warn('Failed to get state:', e);
    }
  }

  // Start Session button
  btnStart?.addEventListener('click', async () => {
    const intention = inputIntention.value.trim() || 'Deep Work';
    btnStart.disabled = true;
    try {
      await chrome.runtime.sendMessage({
        type: 'fe:debug_start_session',
        intention,
        distraction_list: ['youtube.com', 'twitter.com', 'x.com', 'reddit.com', 'instagram.com', 'facebook.com', 'tiktok.com'],
      });
      await refresh();
    } finally {
      btnStart.disabled = false;
    }
  });

  inputParking?.addEventListener('keydown', async (event) => {
    if (event.key !== 'Enter') return;
    const item = inputParking.value.trim();
    if (!item || item.length > 120) return;
    await chrome.runtime.sendMessage({ type: 'fe:parking_add', item });
    inputParking.value = '';
    await refresh();
  });

  // Stop Session button
  btnStop?.addEventListener('click', async () => {
    btnStop.disabled = true;
    try {
      await chrome.runtime.sendMessage({ type: 'fe:debug_stop_session' });
      await refresh();
    } finally {
      btnStop.disabled = false;
    }
  });

  await refresh();
});
