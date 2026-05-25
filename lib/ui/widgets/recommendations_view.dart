import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../services/lastfm_service.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import 'corner_radius.dart';
import 'track_list_section.dart';

/// Displays weighted Last.fm track recommendations accumulated over the session.
class RecommendationsView extends StatelessWidget {
  /// Creates the recommendations view.
  const RecommendationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nowPlaying = state.nowPlaying;
    final apiKey = state.lastFmApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      return const _EmptyState(
        message:
            'Add your Last.fm API key in Settings to see recommendations.',
        icon: Icons.vpn_key_outlined,
      );
    }

    if (nowPlaying == null) {
      return const _EmptyState(
        message: 'Play a track to get recommendations.',
        icon: Icons.recommend,
      );
    }

    final isFetching = state.isRecommendationsFetching;
    final tracks = state.recommendationEngine.getTopRecommendations(
      userProfile: state.userProfileService,
      collaborativeResults: state.collaborativeOptIn
          ? state.collaborativeRecommendations
          : null,
    );
    final sourceTracks = state.recommendationEngine.sourceTracks;
    final subtitleText = sourceTracks.isEmpty
        ? 'Play some music to get started'
        : sourceTracks.join(', ');
    final subtitleWidget = Builder(
      builder: (context) => Text(
        subtitleText,
        softWrap: true,
        overflow: TextOverflow.visible,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ColorTokens.textSecondary(context),
            ),
      ),
    );

    final clearButton = Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: const Icon(Icons.refresh, size: 18),
        tooltip: 'Clear session',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        onPressed:
            isFetching ? null : () => state.clearRecommendations(),
      ),
    );

    if (isFetching && tracks.isEmpty) {
      return TrackListSection(
        title: LibraryView.recommendations.title,
        subtitleWidget: subtitleWidget,
        trailing: clearButton,
        bodyBuilder: (_, __, ___) =>
            const Center(child: CircularProgressIndicator()),
      );
    }

    if (tracks.isEmpty) {
      return TrackListSection(
        title: LibraryView.recommendations.title,
        subtitleWidget: subtitleWidget,
        trailing: clearButton,
        bodyBuilder: (context, _, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No recommendations found for this track.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
            ),
          ),
        ),
      );
    }

    return TrackListSection(
      title: LibraryView.recommendations.title,
      subtitleWidget: subtitleWidget,
      trailing: clearButton,
      itemCount: tracks.length,
      itemBuilder: (context, index) => _RecommendationRow(
        track: tracks[index],
        index: index,
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.track, required this.index});

  final LastFmTrack track;
  final int index;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    double clamped(double value, {double min = 0, double max = 999}) =>
        (value * densityScale).clamp(min, max);
    final scoreText = '${(track.match * 100).toStringAsFixed(0)}%';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: space(14).clamp(10.0, 18.0),
        vertical: space(12).clamp(8.0, 16.0),
      ),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.04),
        borderRadius: BorderRadius.circular(
          context.scaledRadius(clamped(14, min: 8, max: 18)),
        ),
        border: Border.all(color: ColorTokens.border(context, 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: space(2).clamp(1.0, 4.0)),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context),
                      ),
                ),
              ],
            ),
          ),
          SizedBox(width: space(12)),
          Text(
            scoreText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ColorTokens.textSecondary(context, 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(space(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: space(48).clamp(32.0, 64.0),
              color: ColorTokens.textSecondary(context, 0.4),
            ),
            SizedBox(height: space(16)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ColorTokens.textSecondary(context),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
