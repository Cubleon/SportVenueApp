import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as maplibre;

import 'location_picker.dart';

import '../data/api_client.dart';
import '../models/sport_venue_models.dart';
import '../theme/app_theme.dart';

const surfaceLabels = {
  'asphalt': 'Асфальт',
  'rubber': 'Резиновое покрытие',
  'artificial_grass': 'Искусственная трава',
  'grass': 'Газон',
  'sand': 'Песок',
  'other': 'Другое',
};

const submissionStatusLabels = {
  'pending': 'На модерации',
  'approved': 'Одобрено · На карте',
  'rejected': 'Отклонено',
};

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(submission['name'] as String, style: context.text.titleLarge),
        const SizedBox(height: 8),
        Text(submission['address'] as String),
        const SizedBox(height: 8),
        SelectableText('${submission['geo_lat']}, ${submission['geo_lng']}'),
        TextButton.icon(
          icon: const Icon(Icons.map_outlined),
          label: const Text('Посмотреть на карте'),
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
        const SizedBox(height: 8),
        Text('Виды спорта: $names'),
        Text(
          'Покрытие: ${surfaceLabels[submission['surface']] ?? submission['surface']}',
        ),
        Text(
          'Освещение: ${submission['has_lighting'] == true ? 'Есть' : 'Нет'}',
        ),
        const Text('Общественная площадка · Бесплатный доступ'),
        if ((submission['description'] as String).isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(submission['description'] as String),
        ],
        const SizedBox(height: 10),
        Text(
          'Отправлено ${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year}',
          style: context.text.bodySmall?.copyWith(color: context.colors.muted),
        ),
      ],
    );
  }
}
