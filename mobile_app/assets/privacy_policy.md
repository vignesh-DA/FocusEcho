Focus Echo AI Privacy Policy

Focus Echo AI helps users recover focus. This policy explains what data is processed and how it is handled.

Data processed
FocusEcho processes app/site identifiers (package names or hostnames), session start and end times, distraction and recovery timing, focus ratings, selected drift reasons, parked notes, and focus statistics. Flutter app parked notes are free text and are stored locally, then included with a session upload if cloud sync is enabled. Extension popup notes remain in the active extension session.

Data we do not collect
We do not collect message content or chat history. We do not collect personal file contents. We do not collect device photos, contacts, or microphone recordings. We do not collect location or GPS data.

Local-only mode
If Local-only mode is enabled, all data stays on device in local SQLite storage and cloud sync is disabled.

Cloud sync
Cloud sync is optional and user controlled. If enabled, session and focus settings are synced to the configured Supabase project. The browser extension can sync distraction-event metadata when connected to an authenticated account. The EchoCoach feature sends session facts to the configured Groq model only after the user opts in; it sends the parked-item count, never the parked note text.

Data retention
Automatic deletion after a fixed retention period is not currently implemented. Cloud data remains until you delete it in app settings or remove your account through the configured Supabase project.

Data deletion rights
Users can request data deletion at any time from the app settings using Delete My Data, or by contacting support.

Contact
Privacy requests: privacy@focusecho.ai
