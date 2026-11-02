/**
 * @fileoverview FocusEcho Popup Controller — Production Productive-Tab Waterfall Edition.
 *
 * Flow (idle state):
 *   Step 1: User types intention → clicks "Next — Pick Work Tab →"
 *   Step 2: Tab picker cards load; user picks one (or leaves Auto) → "Start Focus Session"
 *
 * Storage:
 *   SK.PINNED_TAB_ID   ('pinned_tab_id')      → chrome.storage.local
 *   SK.LAST_PRODUCTIVE_TAB_ID                  → managed by service-worker on onActivated
 */

const SK_PINNED_TAB_ID = 'pinned_tab_id';

// Dashboard origins to exclude from the productive-tab list
const DASHBOARD_ORIGINS = [
  'https://focusecho-app.vercel.app',
  'http://localhost:3000',
  'http://localhost:5173',
  'http://127.0.0.1',
];

function isDashboardUrl(url) {
  try {
    const origin = new URL(url).origin;
    return DASHBOARD_ORIGINS.some(o => origin === o || url.startsWith(o));
  } catch (_) {
    return false;
  }
}

function isWebUrl(url) {
  return url && (url.startsWith('http://') || url.startsWith('https://'));
}

function getHostname(url) {
  try { return new URL(url).hostname.replace(/^www\./, ''); } catch (_) { return url; }
}

function truncate(str, max = 35) {
  return str && str.length > max ? str.slice(0, max - 1) + '…' : str;
}

/** Returns true if the hostname is distracting based on config distraction list. */
function isDistracting(hostname, distractionList) {
  if (!hostname || !Array.isArray(distractionList)) return false;
  const h = hostname.replace(/^www\./, '');
  return distractionList.some(site => {
    const s = (typeof site === 'string' ? site : site.hostname || '').replace(/^www\./, '');
    return s && (h === s || h.endsWith('.' + s));
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  const optLink           = document.getElementById('opt-link');
  const badgeStatus       = document.getElementById('badge-status');
  const viewIdle          = document.getElementById('view-idle');
  const viewTabPick       = document.getElementById('view-tab-pick');
  const viewActive        = document.getElementById('view-active');
  const inputIntention    = document.getElementById('input-intention');
  const btnNext           = document.getElementById('btn-next');
  const btnBack           = document.getElementById('btn-back');
  const tabPickerList     = document.getElementById('tab-picker-list');
  const btnStart          = document.getElementById('btn-start');
  const btnStop           = document.getElementById('btn-stop');
  const txtIntention      = document.getElementById('txt-intention');
  const valCount          = document.getElementById('val-count');
  const valState          = document.getElementById('val-state');
  const inputParking      = document.getElementById('input-parking');
  const parkingList       = document.getElementById('parking-list');
  const parkingNote       = document.getElementById('parking-note');
  const allowSiteBtn      = document.getElementById('btn-allow-site');
  const productiveSelect  = document.getElementById('productive-tab-select');
  const targetTabLabel    = document.getElementById('target-tab-label');
  const targetTabName     = document.getElementById('target-tab-name');

  // Open options page link
  if (optLink) {
    optLink.addEventListener('click', (e) => {
      e.preventDefault();
      chrome.runtime.openOptionsPage();
    });
  }

  let configuredSites = [];        // distraction hostnames from config
  let selectedTabId   = null;      // null = "Auto"
  let openTabs        = [];        // filtered productive tabs for the picker

  // ---------------------------------------------------------------------------
  // Helpers: load open tabs filtered for the picker
  // ---------------------------------------------------------------------------
  async function loadProductiveTabs() {
    const all = await chrome.tabs.query({ currentWindow: true });
    return all.filter(tab => {
      if (!isWebUrl(tab.url)) return false;
      if (isDashboardUrl(tab.url)) return false;
      if (tab.url.startsWith(chrome.runtime.getURL(''))) return false;
      if (isDistracting(getHostname(tab.url), configuredSites)) return false;
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Render tab cards in the picker
  // ---------------------------------------------------------------------------
  function renderTabCards(tabs) {
    tabPickerList.innerHTML = '';

    // Option 0: Auto (no specific tab)
    const autoCard = document.createElement('div');
    autoCard.className = 'tab-card selected';
    autoCard.dataset.tabId = '';
    autoCard.innerHTML = `
      <span style="font-size:16px; flex-shrink:0;">&#x1F504;</span>
      <div class="tab-info">
        <div class="tab-title">Auto (Last Active Work Tab)</div>
        <div class="tab-host">Extension picks the best tab automatically</div>
      </div>`;
    autoCard.addEventListener('click', () => selectCard(autoCard, null));
    tabPickerList.appendChild(autoCard);

    // Productive tabs
    for (const tab of tabs) {
      const card = document.createElement('div');
      card.className = 'tab-card';
      card.dataset.tabId = String(tab.id);

      const faviconSrc = tab.favIconUrl || '';
      const faviconEl = faviconSrc
        ? `<img src="${faviconSrc}" alt="" onerror="this.replaceWith(document.createTextNode('🌐'))">`
        : '<span style="font-size:14px;flex-shrink:0;">🌐</span>';
      const hostname = getHostname(tab.url);

      card.innerHTML = `
        ${faviconEl}
        <div class="tab-info">
          <div class="tab-title">${truncate(tab.title || hostname)}</div>
          <div class="tab-host">${hostname}</div>
        </div>`;
      card.addEventListener('click', () => selectCard(card, tab.id));
      tabPickerList.appendChild(card);
    }
  }

  function selectCard(card, tabId) {
    tabPickerList.querySelectorAll('.tab-card').forEach(c => c.classList.remove('selected'));
    card.classList.add('selected');
    selectedTabId = tabId;
  }

  // ---------------------------------------------------------------------------
  // Populate the active-session productive-tab <select>
  // ---------------------------------------------------------------------------
  async function populateProductiveSelect() {
    const stored = await chrome.storage.local.get(SK_PINNED_TAB_ID);
    const pinnedId = stored[SK_PINNED_TAB_ID] ?? null;

    const tabs = await loadProductiveTabs();
    // Clear existing options (keep the Auto one)
    productiveSelect.innerHTML = '<option value="">Auto (Last Active Work Tab)</option>';
    let pinnedTitle = null;
    for (const tab of tabs) {
      const opt = document.createElement('option');
      opt.value = String(tab.id);
      const hostname = getHostname(tab.url);
      opt.textContent = `${truncate(tab.title || hostname, 28)} — ${hostname}`;
      if (tab.id === pinnedId) {
        opt.selected = true;
        pinnedTitle = tab.title || hostname;
      }
      productiveSelect.appendChild(opt);
    }
    // Show/hide the pinned indicator
    if (pinnedId && pinnedTitle) {
      targetTabLabel.style.display = 'flex';
      targetTabName.textContent = truncate(pinnedTitle, 30);
    } else {
      targetTabLabel.style.display = 'none';
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh current state from Service Worker
  // ---------------------------------------------------------------------------
  async function refresh() {
    try {
      const resp = await chrome.runtime.sendMessage({ type: 'fe:debug_get_state' });
      if (!resp || !resp.ok) return;

      const session = resp.session;
      const isActive = session && session.active;

      if (isActive) {
        viewIdle.style.display = 'none';
        viewTabPick.style.display = 'none';
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
        parkingNote.textContent = resp.cloud_ready
          ? `${(session.parked_items || []).length}/20 saved for this session`
          : 'Local only until you sign in to sync.';
        const allowState = await chrome.runtime.sendMessage({ type: 'fe:get_allow_site_state' });
        allowSiteBtn.style.display = allowState?.listed ? 'flex' : 'none';

        if (session.state?.includes('L1') || session.state?.includes('L2') || session.state?.includes('L3')) {
          badgeStatus.className = 'status-badge status-distracted';
          badgeStatus.textContent = session.state;
        } else {
          badgeStatus.className = 'status-badge status-active';
          badgeStatus.textContent = 'FOCUSING';
        }

        // Populate productive-tab selector in active view
        await populateProductiveSelect();
      } else {
        viewIdle.style.display = 'block';
        viewTabPick.style.display = 'none';
        viewActive.style.display = 'none';
        badgeStatus.className = 'status-badge status-idle';
        badgeStatus.textContent = 'IDLE';
        parkingList.replaceChildren();
        parkingNote.textContent = '';
        allowSiteBtn.style.display = 'none';
        targetTabLabel.style.display = 'none';
      }
    } catch (e) {
      console.warn('Failed to get state:', e);
    }
  }

  // ---------------------------------------------------------------------------
  // Step 1 → Step 2: "Next" button
  // ---------------------------------------------------------------------------
  btnNext?.addEventListener('click', async () => {
    viewIdle.style.display = 'none';
    viewTabPick.style.display = 'block';
    selectedTabId = null; // reset selection
    openTabs = await loadProductiveTabs();
    renderTabCards(openTabs);
  });

  // Step 2 → Step 1: "Back" button
  btnBack?.addEventListener('click', () => {
    viewTabPick.style.display = 'none';
    viewIdle.style.display = 'block';
  });

  // ---------------------------------------------------------------------------
  // Step 2: "Start Focus Session" button
  // ---------------------------------------------------------------------------
  btnStart?.addEventListener('click', async () => {
    const intention = inputIntention.value.trim() || 'Deep Work';
    btnStart.disabled = true;
    try {
      // Persist pinned tab selection
      if (selectedTabId != null) {
        await chrome.storage.local.set({ [SK_PINNED_TAB_ID]: selectedTabId });
      } else {
        await chrome.storage.local.remove(SK_PINNED_TAB_ID);
      }

      await chrome.runtime.sendMessage({
        type: 'fe:debug_start_session',
        intention,
        distraction_list: configuredSites,
      });
      inputIntention.value = '';
      await refresh();
    } finally {
      btnStart.disabled = false;
    }
  });

  // ---------------------------------------------------------------------------
  // Active view: productive-tab <select> change
  // ---------------------------------------------------------------------------
  productiveSelect?.addEventListener('change', async () => {
    const val = productiveSelect.value;
    if (val) {
      const tabId = parseInt(val, 10);
      await chrome.storage.local.set({ [SK_PINNED_TAB_ID]: tabId });
      // Update pinned label
      const selected = productiveSelect.options[productiveSelect.selectedIndex];
      targetTabLabel.style.display = 'flex';
      targetTabName.textContent = truncate(selected.textContent, 30);
    } else {
      await chrome.storage.local.remove(SK_PINNED_TAB_ID);
      targetTabLabel.style.display = 'none';
    }
  });

  // ---------------------------------------------------------------------------
  // Parking lot
  // ---------------------------------------------------------------------------
  inputParking?.addEventListener('keydown', async (event) => {
    if (event.key !== 'Enter') return;
    const item = inputParking.value.trim();
    if (!item || item.length > 120) return;
    await chrome.runtime.sendMessage({ type: 'fe:parking_add', item });
    inputParking.value = '';
    await refresh();
  });

  allowSiteBtn?.addEventListener('click', async () => {
    allowSiteBtn.disabled = true;
    try { await chrome.runtime.sendMessage({ type: 'fe:allow_site' }); await refresh(); }
    finally { allowSiteBtn.disabled = false; }
  });

  // ---------------------------------------------------------------------------
  // Stop Session button (also clears pinned tab — handled by CLEAR_SESSION in SW)
  // ---------------------------------------------------------------------------
  btnStop?.addEventListener('click', async () => {
    btnStop.disabled = true;
    try {
      await chrome.runtime.sendMessage({ type: 'fe:debug_stop_session' });
      await refresh();
    } finally {
      btnStop.disabled = false;
    }
  });

  // ---------------------------------------------------------------------------
  // Init: load config and render
  // ---------------------------------------------------------------------------
  try {
    const config = await chrome.runtime.sendMessage({ type: 'fe:get_config' });
    configuredSites = (config?.distraction_list || []).map(site => site.hostname || site).filter(Boolean);
  } catch (_) { configuredSites = []; }
  await refresh();
});
