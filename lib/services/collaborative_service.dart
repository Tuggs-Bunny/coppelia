import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lastfm_service.dart';

/// Sends and retrieves collaborative listening data from the community server.
class CollaborativeService {
  /// Creates a collaborative service.
  const CollaborativeService();

  static const _baseUrl = 'https://api.spacemonkeys.online';

  /// Sends a listen event; fails silently on error.
  Future<void> sendListenEvent({
    required String hashedUserId,
    required String trackName,
    required String artistName,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/listen'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hashed_user_id': hashedUserId,
          'track_name': trackName,
          'artist_name': artistName,
        }),
      );
    } catch (_) {}
  }

  /// Returns community recommendations; returns empty list on error.
  Future<List<LastFmTrack>> getRecommendations(String hashedUserId) async {
    try {
      final uri = Uri.parse('$_baseUrl/recommendations')
          .replace(queryParameters: {'id': hashedUserId});
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final payload = jsonDecode(response.body) as List<dynamic>;
      return payload.whereType<Map<String, dynamic>>().map((raw) {
        return LastFmTrack(
          title: raw['track']?.toString() ?? '',
          artist: raw['artist']?.toString() ?? '',
          url: '',
          match: (raw['score'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Deletes all server-side data for [hashedUserId]; fails silently on error.
  Future<void> deleteUserData(String hashedUserId) async {
    try {
      await http.delete(Uri.parse('$_baseUrl/user/$hashedUserId'));
    } catch (_) {}
  }
}
