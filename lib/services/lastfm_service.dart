import 'dart:convert';

import 'package:http/http.dart' as http;

import 'user_profile_service.dart';

/// A track returned from the Last.fm similar-tracks API.
class LastFmTrack {
  /// Creates a Last.fm track result.
  const LastFmTrack({
    required this.title,
    required this.artist,
    required this.url,
    required this.match,
  });

  /// Track title.
  final String title;

  /// Artist name.
  final String artist;

  /// Last.fm URL for this track.
  final String url;

  /// Similarity score between 0 and 1.
  final double match;
}

/// Accumulates weighted track recommendations across a listening session.
class RecommendationEngine {
  final _service = const LastFmService();
  final Map<String, double> _scores = {};
  final Map<String, LastFmTrack> _representative = {};
  final List<String> _sourceTracks = [];

  /// Tracks fed into the engine this session, in order.
  List<String> get sourceTracks => List.unmodifiable(_sourceTracks);

  /// Returns the top recommendations sorted by adjusted score descending.
  ///
  /// When [userProfile] is provided, each track's raw Last.fm score is boosted
  /// or suppressed by the profile's artist weight, with the current time-vector
  /// weight applied as a half-strength secondary signal.
  List<LastFmTrack> getTopRecommendations({
    int limit = 50,
    UserProfileService? userProfile,
  }) {
    final timeArtists = userProfile?.getTimeVector()['artists'] ?? const {};

    final adjusted = <String, double>{};
    for (final entry in _scores.entries) {
      final track = _representative[entry.key];
      if (track == null) continue;
      var score = entry.value;
      if (userProfile != null) {
        score += userProfile.getArtistWeight(track.artist);
        score += (timeArtists[track.artist] ?? 0.0) * 0.5;
      }
      adjusted[entry.key] = score;
    }

    final sorted = adjusted.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((entry) {
      final t = _representative[entry.key]!;
      return LastFmTrack(
        title: t.title,
        artist: t.artist,
        url: t.url,
        match: adjusted[entry.key]!,
      );
    }).toList();
  }

  /// Fetches similar tracks for [trackTitle]/[artistName] and accumulates scores.
  Future<void> addTrack({
    required String apiKey,
    required String trackTitle,
    required String artistName,
  }) async {
    _sourceTracks.add('$trackTitle - $artistName');
    final results = await _service.getSimilarTracks(
      apiKey: apiKey,
      trackTitle: trackTitle,
      artistName: artistName,
    );
    for (final track in results) {
      final key =
          '${track.artist.toLowerCase()} - ${track.title.toLowerCase()}';
      _scores[key] = (_scores[key] ?? 0.0) + track.match;
      _representative[key] ??= track;
    }
  }

  /// Resets all accumulated scores.
  void clear() {
    _scores.clear();
    _representative.clear();
    _sourceTracks.clear();
  }
}

/// Fetches music recommendations from the Last.fm API.
class LastFmService {
  /// Creates a Last.fm service.
  const LastFmService();

  static const _baseUrl = 'https://ws.audioscrobbler.com/2.0/';

  /// Returns tracks similar to [trackTitle] by [artistName].
  Future<List<LastFmTrack>> getSimilarTracks({
    required String apiKey,
    required String trackTitle,
    required String artistName,
    int limit = 30,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'method': 'track.getSimilar',
      'track': trackTitle,
      'artist': artistName,
      'api_key': apiKey,
      'limit': limit.toString(),
      'format': 'json',
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Last.fm request failed: HTTP ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final error = payload['error'];
    if (error != null) {
      final message = payload['message']?.toString() ?? 'Unknown error';
      throw Exception('Last.fm error $error: $message');
    }
    final similarTracks =
        (payload['similartracks']?['track'] as List<dynamic>?) ?? [];
    return similarTracks.whereType<Map<String, dynamic>>().map((raw) {
      final name = raw['name']?.toString() ?? '';
      final artistMap = raw['artist'] as Map<String, dynamic>?;
      final artist = artistMap?['name']?.toString() ?? '';
      final url = raw['url']?.toString() ?? '';
      final match = double.tryParse(raw['match']?.toString() ?? '0') ?? 0.0;
      return LastFmTrack(
        title: name,
        artist: artist,
        url: url,
        match: match,
      );
    }).toList();
  }
}
