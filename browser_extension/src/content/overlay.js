/**
 * @fileoverview FocusEcho In-Page Intervention Content Script (EXT-2).
 * Injected on monitored sites to display escalating interventions (L1 Toast,
 * L2 Countdown Modal, L3 Full Shield Blocker).
 *
 * Isolated inside a Shadow DOM root to prevent host page CSS collisions.
 */

(function () {
  // Prevent duplicate injection
  if (window.__feOverlayInjected) return;
  window.__feOverlayInjected = true;

  const ROOT_ID = 'focusecho-overlay-root';
  let hostElement = null;
  let shadowRoot = null;
  let countdownTimer = null;
  let emergencyHoldTimer = null;

  /**
   * Initializes or returns the Shadow Root host.
   */
  function getShadow() {
    if (!hostElement || !document.contains(hostElement)) {
      hostElement = document.createElement('div');
      hostElement.id = ROOT_ID;
      hostElement.style.all = 'initial';
      (document.body || document.documentElement).appendChild(hostElement);
      shadowRoot = hostElement.attachShadow({ mode: 'open' });
    }
    return shadowRoot;
  }

  /**
   * Clears and hides active overlays.
   */
  function hideOverlay() {
    if (countdownTimer) {
      clearInterval(countdownTimer);
      countdownTimer = null;
    }
    if (emergencyHoldTimer) {
      clearInterval(emergencyHoldTimer);
      emergencyHoldTimer = null;
    }
    if (shadowRoot) {
      shadowRoot.innerHTML = '';
    }
  }

  /**
   * Injects CSS stylesheet into the shadow root.
   */
  function ensureStyles(shadow) {
    if (!shadow.querySelector('link[data-fe-style]')) {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.setAttribute('data-fe-style', 'true');
      link.href = chrome.runtime.getURL('src/content/overlay.css');
      shadow.appendChild(link);
    }
  }

  /**
   * Sends user action event to the background Service Worker.
   */
  function sendToWorker(evType, payload = {}) {
    chrome.runtime.sendMessage({
      type: 'fe:cs_ev',
      ev_type: evType,
      payload,
    }).catch(() => {});
  }

  /**
   * Level 1: Floating Heads-Up Toast
   */
  function showL1Toast(intention) {
    hideOverlay();
    const shadow = getShadow();
    ensureStyles(shadow);

    const container = document.createElement('div');
    container.className = 'fe-toast';
    container.innerHTML = `
      <div class="fe-toast-header">
        <span class="fe-badge-l1">⚠️ Focus Nudge (L1)</span>
        <button class="fe-close-btn" id="fe-toast-close" title="Dismiss">×</button>
      </div>
      <div class="fe-toast-title">Are you drifting from your goal?</div>
      <div class="fe-intention-quote">"${escapeHtml(intention || 'Deep Work')}"</div>
      <button class="fe-btn-primary" id="fe-back-focus-btn">
        <span>⚡</span> Return to Focus
      </button>
      <button class="fe-btn-secondary" id="fe-allow-site-btn">Allow this site for this session</button>
    `;

    shadow.appendChild(container);

    container.querySelector('#fe-toast-close')?.addEventListener('click', () => {
      container.style.opacity = '0';
      container.style.transform = 'translateY(-10px)';
      setTimeout(() => container.remove(), 250);
    });

    container.querySelector('#fe-back-focus-btn')?.addEventListener('click', () => {
      sendToWorker('USER_BACK_TO_FOCUS');
      hideOverlay();
    });
    container.querySelector('#fe-allow-site-btn')?.addEventListener('click', () => {
      sendToWorker('ALLOW_SITE_FOR_SESSION', { host: location.hostname });
      hideOverlay();
    });
  }

  /**
   * Level 2: Friction Countdown Modal
   */
  function showL2Modal(intention, countdownSeconds = 15) {
    hideOverlay();
    const shadow = getShadow();
    ensureStyles(shadow);

    let remaining = countdownSeconds;

    const backdrop = document.createElement('div');
    backdrop.className = 'fe-backdrop';
    backdrop.innerHTML = `
      <div class="fe-modal">
        <div class="fe-countdown-circle" id="fe-countdown-val">${remaining}</div>
        <div class="fe-modal-title">Friction Check (Level 2)</div>
        <div class="fe-modal-desc">
          Take a deep breath. You declared you would focus on:
        </div>
        <div class="fe-intention-quote">"${escapeHtml(intention || 'Your intention')}"</div>
        <button class="fe-btn-primary" id="fe-l2-return-btn" style="margin-top: 14px;">
          <span>⚡</span> Return to Focus Now
        </button>
        <button class="fe-btn-secondary" id="fe-l2-continue-btn" disabled>
          Continue to site (wait ${remaining}s)
        </button>
        <button class="fe-btn-secondary" id="fe-l2-allow-site-btn">Allow this site for this session</button>
      </div>
    `;

    shadow.appendChild(backdrop);

    const valEl = backdrop.querySelector('#fe-countdown-val');
    const continueBtn = backdrop.querySelector('#fe-l2-continue-btn');

    countdownTimer = setInterval(() => {
      remaining -= 1;
      if (valEl) valEl.textContent = Math.max(0, remaining);

      if (remaining <= 0) {
        clearInterval(countdownTimer);
        countdownTimer = null;
        if (continueBtn) {
          continueBtn.disabled = false;
          continueBtn.textContent = 'Dismiss & Continue to site';
        }
        sendToWorker('COUNTDOWN_EXPIRED');
      } else if (continueBtn) {
        continueBtn.textContent = `Continue to site (wait ${remaining}s)`;
      }
    }, 1000);

    backdrop.querySelector('#fe-l2-return-btn')?.addEventListener('click', () => {
      sendToWorker('USER_BACK_TO_FOCUS');
      hideOverlay();
    });

    continueBtn?.addEventListener('click', () => {
      if (!continueBtn.disabled) {
        hideOverlay();
      }
    });
    backdrop.querySelector('#fe-l2-allow-site-btn')?.addEventListener('click', () => {
      sendToWorker('ALLOW_SITE_FOR_SESSION', { host: location.hostname });
      hideOverlay();
    });
  }

  /**
   * Level 3: Full Screen Shield Blocker
   */
  function showL3Blocker(intention) {
    hideOverlay();

    // Immediately mute all playing video/audio on the page so Reels/YouTube
    // audio does not bleed through or keep playing behind the shield.
    try {
      document.querySelectorAll('video, audio').forEach(el => {
        if (!el.paused) {
          el.pause();
          el.dataset.__feMuted = '1';
        }
        el.muted = true;
      });
    } catch (_) {}

    const shadow = getShadow();
    ensureStyles(shadow);

    const screen = document.createElement('div');
    screen.className = 'fe-blocker-screen';
    screen.innerHTML = `
      <div class="fe-shield-icon">🛡️</div>
      <div class="fe-blocker-title">Site Blocked by FocusEcho</div>
      <p style="color: #9ca3af; font-size: 14px; max-width: 440px; text-align: center;">
        You have reached Level 3 distraction escalation on this site.
      </p>
      <div class="fe-blocker-card">
        <div style="font-size: 11px; text-transform: uppercase; color: #60a5fa; letter-spacing: 1px; margin-bottom: 6px;">Your Declared Intention</div>
        <div style="font-size: 16px; font-weight: 600; color: #ffffff;">"${escapeHtml(intention || 'Deep Work')}"</div>
      </div>
      <button class="fe-btn-primary" id="fe-l3-return-btn" style="max-width: 340px; padding: 13px;">
        <span>⚡</span> Return to Productive Tab
      </button>

      <div class="fe-emergency-wrap">
        <button class="fe-emergency-btn" id="fe-emergency-btn">
          <div class="fe-emergency-progress" id="fe-emergency-bar"></div>
          <span style="position: relative; z-index: 1;">Hold for 3s to emergency unlock</span>
        </button>
      </div>
    `;

    shadow.appendChild(screen);

    screen.querySelector('#fe-l3-return-btn')?.addEventListener('click', () => {
      sendToWorker('USER_BACK_TO_FOCUS');
      hideOverlay();
    });

    // Hold-to-escape emergency button
    const emergencyBtn = screen.querySelector('#fe-emergency-btn');
    const progressBar = screen.querySelector('#fe-emergency-bar');
    let holdStart = 0;
    const HOLD_TIME_MS = 3000;

    function startHold(e) {
      e.preventDefault();
      holdStart = Date.now();
      if (progressBar) progressBar.style.width = '0%';

      emergencyHoldTimer = setInterval(() => {
        const elapsed = Date.now() - holdStart;
        const pct = Math.min(100, Math.round((elapsed / HOLD_TIME_MS) * 100));
        if (progressBar) progressBar.style.width = `${pct}%`;

        if (elapsed >= HOLD_TIME_MS) {
          clearInterval(emergencyHoldTimer);
          emergencyHoldTimer = null;
          sendToWorker('USER_EMERGENCY_HOLD');
          hideOverlay();
        }
      }, 50);
    }

    function cancelHold() {
      if (emergencyHoldTimer) {
        clearInterval(emergencyHoldTimer);
        emergencyHoldTimer = null;
      }
      if (progressBar) progressBar.style.width = '0%';
    }

    emergencyBtn?.addEventListener('pointerdown', startHold);
    emergencyBtn?.addEventListener('pointerup', cancelHold);
    emergencyBtn?.addEventListener('pointerleave', cancelHold);
  }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // ---------------------------------------------------------------------------
  // "Back in Flow" Recovery Toast — shown on the productive work tab
  // ---------------------------------------------------------------------------
  function showRecoveryToast(remainingMinutes, isDashboardFallback) {
    // Remove any existing recovery toast
    const existing = document.getElementById('__fe_recovery_toast__');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.id = '__fe_recovery_toast__';

    let toastText, toastColor;
    if (isDashboardFallback) {
      // User was redirected to the Focus Dashboard (no real work tab open)
      toastText = '&#x26A1; Returned to Focus Dashboard &mdash; Open a work tab to lock it in!';
      toastColor = '#60a5fa'; // blue
    } else {
      const timeText = (remainingMinutes != null && remainingMinutes > 0)
        ? ` &#x2022; ~${remainingMinutes}m left`
        : '';
      toastText = `&#x26A1; Back in flow &mdash; Keep going!${timeText}`;
      toastColor = '#3fb950'; // emerald green
    }

    const borderColor = isDashboardFallback ? '#3b82f6' : '#2ea043';
    const bgGradient = isDashboardFallback
      ? 'linear-gradient(135deg, #0d1a2f 0%, #0a1220 100%)'
      : 'linear-gradient(135deg, #0d1f12 0%, #0a1a0a 100%)';
    const shadowColor = isDashboardFallback
      ? 'rgba(59, 130, 246, 0.35)'
      : 'rgba(46, 160, 67, 0.35)';

    toast.innerHTML = `
      <div style="
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 2147483647;
        pointer-events: none;
        background: ${bgGradient};
        border: 1.5px solid ${borderColor};
        border-radius: 999px;
        padding: 10px 18px;
        display: flex;
        align-items: center;
        gap: 8px;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 13px;
        font-weight: 600;
        color: ${toastColor};
        box-shadow: 0 4px 20px ${shadowColor}, 0 2px 8px rgba(0,0,0,0.5);
        opacity: 0;
        transform: translateX(20px);
        transition: opacity 0.25s ease, transform 0.25s ease;
        white-space: nowrap;
        max-width: 380px;
      " id="__fe_recovery_pill__">
        <span id="__fe_recovery_text__">${toastText}</span>
      </div>`;

    document.documentElement.appendChild(toast);
    // Set HTML content safely after inserting
    const textEl = document.getElementById('__fe_recovery_text__');
    if (textEl) textEl.innerHTML = toastText;

    // Animate in
    requestAnimationFrame(() => {
      const pill = document.getElementById('__fe_recovery_pill__');
      if (pill) {
        pill.style.opacity = '1';
        pill.style.transform = 'translateX(0)';
      }
    });

    // Animate out and remove after 2.5 s (3 s for dashboard fallback)
    const displayMs = isDashboardFallback ? 3000 : 2500;
    setTimeout(() => {
      const pill = document.getElementById('__fe_recovery_pill__');
      if (pill) {
        pill.style.opacity = '0';
        pill.style.transform = 'translateX(20px)';
        setTimeout(() => toast.remove(), 300);
      }
    }, displayMs);
  }

  // ---------------------------------------------------------------------------
  // Message Listener from Background Service Worker
  // ---------------------------------------------------------------------------
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!message || typeof message !== 'object') return;

    if (message.type === 'fe:show_overlay') {
      const level = message.level || 1;
      const intention = message.intention || '';
      if (level === 1) {
        showL1Toast(intention);
      } else if (level === 2) {
        showL2Modal(intention, 15);
      } else if (level >= 3) {
        showL3Blocker(intention);
      }
      sendResponse?.({ ok: true, shown: level });
      return true;
    }

    if (message.type === 'fe:hide_overlay') {
      hideOverlay();
      sendResponse?.({ ok: true, hidden: true });
      return true;
    }

    if (message.type === 'SHOW_RECOVERY_TOAST') {
      showRecoveryToast(message.remainingMinutes ?? null, message.dashboardFallback === true);
      sendResponse?.({ ok: true });
      return true;
    }
  });
})();
