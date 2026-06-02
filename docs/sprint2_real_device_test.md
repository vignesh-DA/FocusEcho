# Sprint 2 Real-Device E2E Test Protocol

This protocol is the acceptance checklist for Sprint 2 reliability items.

## Device Matrix
- Pixel/stock Android (API 33+)
- Xiaomi MIUI 14+
- Samsung One UI 5+

## Preconditions
1. Install release or profile APK on physical device.
2. Fresh app install (clear app data).
3. Network ON.

## E2E Flow
1. Launch app and complete consent toggles.
2. Open permission wizard and grant:
   - Usage Access
   - Accessibility Service
   - Battery optimization ignore
3. On battery screen:
   - Tap **Disable Battery Restriction**
   - On Xiaomi/Samsung also tap **Open OEM Battery Settings (Xiaomi/Samsung)**
4. Complete app selector with at least one productive and one distracting app.
5. Start a focus session.
6. Switch to a distracting app and verify distraction handling appears.
7. Return to Focus Echo and confirm session remains active.
8. Lock device for 2 minutes, unlock, verify session still tracked.
9. Reboot device and verify boot recovery behavior (if previous session was active).

## Pass Criteria
- All three permissions show **Granted** in wizard.
- Focus session survives backgrounding and lock/unlock.
- Distraction event is captured after app switch.
- No crash while opening OEM battery settings on Xiaomi/Samsung.

## Evidence Capture
- Screen recording of onboarding + permission flow.
- Screenshot of each permission as granted.
- Logcat snippet for battery flow and app switch event.
