import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';
import '../models/playback_event.dart';

const _weightDeltas = {
  PlaybackEvent.completedOver80: 0.3,
  PlaybackEvent.skippedAfter45s: 0.1,
  PlaybackEvent.skippedBefore45s: -0.1,
  PlaybackEvent.loved: 0.5,
  PlaybackEvent.replayed: 0.4,
};

/// Persists per-user taste weights across sessions.
///
/// Call [init] once at startup to hydrate from disk. All getters are
/// synchronous after that; writes are fire-and-forget async saves.
class UserProfileService {
  Map<String, double> _artists = {};
  Map<String, double> _genres = {};
  Map<String, Map<String, Map<String, double>>> _timeVectors = {
    'morning': {'artists': {}, 'genres': {}},
    'afternoon': {'artists': {}, 'genres': {}},
    'evening': {'artists': {}, 'genres': {}},
    'late_night': {'artists': {}, 'genres': {}},
  };
  List<String> _tracksLoved = [];
  List<String> _tracksSkipped = [];
  List<String> _tracksPlayed = [];

  // ---------------------------------------------------------------------------
  // Init / persistence
  // ---------------------------------------------------------------------------

  Future<File> _profileFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/user_profile.json');
  }

  /// Loads the profile from disk. Safe to call multiple times.
  Future<void> init() async {
    final file = await _profileFile();
    if (!await file.exists()) return;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _artists = _parseDoubleMap(raw['artists']);
      _genres = _parseDoubleMap(raw['genres']);
      final tv = raw['time_vectors'] as Map<String, dynamic>? ?? {};
      for (final bucket in _buckets) {
        final b = tv[bucket] as Map<String, dynamic>? ?? {};
        _timeVectors[bucket] = {
          'artists': _parseDoubleMap(b['artists']),
          'genres': _parseDoubleMap(b['genres']),
        };
      }
      _tracksLoved = _parseStringList(raw['tracks_loved']);
      _tracksSkipped = _parseStringList(raw['tracks_skipped']);
      _tracksPlayed = _parseStringList(raw['tracks_played']);
    } catch (_) {
      // Corrupt file — keep in-memory defaults and overwrite on next save.
    }
  }

  Future<void> _save() async {
    final file = await _profileFile();
    final data = {
      'artists': _artists,
      'genres': _genres,
      'time_vectors': {
        for (final bucket in _buckets) bucket: _timeVectors[bucket]!,
      },
      'tracks_loved': _tracksLoved,
      'tracks_skipped': _tracksSkipped,
      'tracks_played': _tracksPlayed,
    };
    await file.writeAsString(jsonEncode(data));
  }

  // ---------------------------------------------------------------------------
  // Public API — synchronous reads
  // ---------------------------------------------------------------------------

  /// Weight for [artist] in [-1, 1]; 0.0 if unknown.
  double getArtistWeight(String artist) => _artists[artist] ?? 0.0;

  /// Weight for [genre] in [-1, 1]; 0.0 if unknown.
  double getGenreWeight(String genre) => _genres[genre] ?? 0.0;

  /// Artist and genre weights for the current time-of-day bucket.
  Map<String, Map<String, double>> getTimeVector() {
    return Map.unmodifiable(_timeVectors[_currentBucket()]!);
  }

  // ---------------------------------------------------------------------------
  // Public API — async writes
  // ---------------------------------------------------------------------------

  /// Records [event] for [track], updates in-memory weights, and saves.
  Future<void> recordEvent(MediaItem track, PlaybackEvent event) async {
    final delta = _weightDeltas[event]!;
    final bucket = _currentBucket();
    final tv = _timeVectors[bucket]!;

    for (final artist in track.artists) {
      _artists[artist] = _clamp((_artists[artist] ?? 0.0) + delta);
      tv['artists']![artist] =
          _clamp((tv['artists']![artist] ?? 0.0) + delta);
    }
    for (final genre in track.genres) {
      _genres[genre] = _clamp((_genres[genre] ?? 0.0) + delta);
      tv['genres']![genre] = _clamp((tv['genres']![genre] ?? 0.0) + delta);
    }

    switch (event) {
      case PlaybackEvent.loved:
        if (!_tracksLoved.contains(track.id)) _tracksLoved.add(track.id);
      case PlaybackEvent.skippedBefore45s:
      case PlaybackEvent.skippedAfter45s:
        if (!_tracksSkipped.contains(track.id)) _tracksSkipped.add(track.id);
      case PlaybackEvent.completedOver80:
      case PlaybackEvent.replayed:
        if (!_tracksPlayed.contains(track.id)) _tracksPlayed.add(track.id);
    }

    await _save();
  }

  /// Clears all learned weights and saves an empty profile.
  Future<void> reset() async {
    _artists = {};
    _genres = {};
    _timeVectors = {
      for (final bucket in _buckets)
        bucket: {'artists': {}, 'genres': {}},
    };
    _tracksLoved = [];
    _tracksSkipped = [];
    _tracksPlayed = [];
    await _save();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static const _buckets = ['morning', 'afternoon', 'evening', 'late_night'];

  String _currentBucket() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'late_night';
  }

  static double _clamp(double v) => v.clamp(-1.0, 1.0);

  static Map<String, double> _parseDoubleMap(dynamic raw) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<String>().toList();
  }
}
