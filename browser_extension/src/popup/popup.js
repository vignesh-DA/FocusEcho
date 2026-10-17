/**
 * @fileoverview FocusEcho Popup Script — Phase 1
 * Uses external script to satisfy MV3 Content Security Policy (no inline scripts).
 */
document.addEventListener('DOMContentLoaded', () => {
  const optLink = document.getElementById('opt-link');
  if (optLink) {
    optLink.addEventListener('click', (e) => {
      e.preventDefault();
      chrome.runtime.openOptionsPage();
    });
  }
});
