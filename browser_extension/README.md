# FocusEcho Browser Monitor

This Manifest V3 extension provides real-time browser monitoring for the FocusEcho Web app. It observes active tab changes and navigation, compares hosts only against the user-configured distracting-site list, and sends live events to the open FocusEcho tab.

## Install locally

1. Open `chrome://extensions` (or `edge://extensions`).
2. Enable **Developer mode**.
3. Choose **Load unpacked** and select this `browser_extension` folder.
4. Open the FocusEcho web app, enable a focus session, and configure distracting sites such as `youtube.com` or `instagram.com`.

The extension does not persist browsing history or transmit browsing data to FocusEcho servers. It only relays current configured-host activity to the open FocusEcho page. Browser extensions cannot monitor native Android applications; use the Android app for that scope.

## Automated Live Chrome Test (EXT-1 Verification)

Run the automated live Chrome E2E test suite (verifies active service worker, 3s grace timer, glance <3s, 20s recovery event, L2 re-entry, CDP SW termination and wake, options popup opening, and active session restart):

```bash
node browser_extension/tests/live-chrome-test.js
```
*(or run `npm test` from the `browser_extension/` directory)*
