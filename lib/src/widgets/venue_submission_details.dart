import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import 'location_picker.dart';
import 'shared_widgets.dart';

import '../../l10n/l10n.dart';
import '../data/api_client.dart';
import '../data/formatters.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';

/// The surfaces a public court can have, in the order the form offers them.
const surfaceKeys = [
  'asphalt',
  'rubber',
  'artificial_grass',
  'grass',
  'sand',
  'other',
];

/// What a surface key reads as. An unknown one is shown as sent.
String surfaceLabel(L l10n, String? key) => switch (key) {
  'asphalt' => l10n.surfaceAsphalt,
  'rubber' => l10n.surfaceRubber,
  'artificial_grass' => l10n.surfaceArtificialGrass,
  'grass' => l10n.surfaceGrass,
  'sand' => l10n.surfaceSand,
  'other' => l10n.surfaceOther,
  null => l10n.surfaceUnknown,
  _ => key,
};

/// Where a submission stands, as its author and the moderator read it.
String submissionStatusLabel(L l10n, String status) => switch (status) {
  'pending' => l10n.submissionPending,
  'approved' => l10n.submissionApproved,
  'rejected' => l10n.submissionRejected,
  _ => status,
};

/// A submitted public court: name and address on top, then the facts as the
/// same label–value rows the rest of the app uses for a club.
class VenueSubmissionDetails extends StatelessWidget {
  const VenueSubmissionDetails({
    super.key,
    required this.submission,
    required this.sports,
  });

  final ApiJsonObject submission;
  final List<Sport> sports;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ids = (submission['sport_ids'] as List).cast<String>();
    final names = ids
        .map(
          (id) =>
              sports.where((sport) => sport.id == id).firstOrNull?.name ?? id,
        )
        .join(', ');
    final created = DateTime.parse(
      submission['created_at'] as String,
    ).toUtc().add(const Duration(hours: 3));
    final description = submission['description'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(submission['name'] as String, style: context.text.titleMedium),
        const SizedBox(height: 4),
        Text(
          submission['address'] as String,
          style: context.text.bodyMedium?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 12),
        ...summaryRowsDivided(context, [
          SummaryRow(label: l10n.venueSports, value: names.capitalized),
          SummaryRow(
            label: l10n.surfaceLabel,
            value: surfaceLabel(l10n, submission['surface'] as String?),
          ),
          SummaryRow(
            label: l10n.lightingLabel,
            value: submission['has_lighting'] == true
                ? l10n.lightingYes
                : l10n.lightingNo,
          ),
          SummaryRow(label: l10n.accessLabel, value: l10n.publicAccessValue),
        ]),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(description, style: context.text.bodyMedium),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(l10n.showOnMap),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => LocationPicker(
                readOnly: true,
                initialPoint: maplibre.Geographic(
                  lat: (submission['geo_lat'] as num).toDouble(),
                  lon: (submission['geo_lng'] as num).toDouble(),
                ),
              ),
            ),
          ),
        ),
        Text(
          l10n.submittedOn(AppFormatters.dateShort(created)),
          style: context.text.bodySmall?.copyWith(color: context.colors.muted),
        ),
      ],
    );
  }
}
