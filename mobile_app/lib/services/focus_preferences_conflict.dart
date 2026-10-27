enum FocusPreferenceWinner { local, remote }

/// Compares local pending settings with the canonical server settings.
/// A strictly newer local edit wins; equal timestamps resolve to the server.
FocusPreferenceWinner resolveFocusPreferenceConflict({
  required DateTime? localUpdatedAt,
  required DateTime remoteUpdatedAt,
}) {
  if (localUpdatedAt != null && localUpdatedAt.isAfter(remoteUpdatedAt)) {
    return FocusPreferenceWinner.local;
  }
  return FocusPreferenceWinner.remote;
}

/// Creates a mutable session snapshot without sharing the saved-list object.
List<String> createSessionSiteSnapshot(Iterable<String> savedSites) =>
    List<String>.of(savedSites);
