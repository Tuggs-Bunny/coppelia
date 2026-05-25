/// Describes what happened during a track's playback session.
enum PlaybackEvent {
  /// Track played past the 80% completion mark.
  completedOver80,

  /// Track was skipped after more than 45 seconds of listening.
  skippedAfter45s,

  /// Track was skipped within the first 45 seconds.
  skippedBefore45s,

  /// Track was hearted / added to favourites.
  loved,

  /// Track was explicitly replayed from the beginning.
  replayed,
}
