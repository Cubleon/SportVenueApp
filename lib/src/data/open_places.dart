import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../models/sport_venue_models.dart';

/// Free public courts from the city's open data (data.mos.ru, CC BY 4.0).
///
/// The file is built by `tool/open_data/build_places.py` and ships with the
/// app: the server has no public courts yet, and a map of four clubs said
/// the city had nowhere to play. Each row is a court nobody books — a yard,
/// a school ground or a park pitch — shown as a public venue.
class OpenPlaces {
  const OpenPlaces._();

  static const asset = 'assets/data/moscow_places.json';

  /// Venue ids from this file start with this, so a link to one can be told
  /// from a club's and the place can be found again.
  static const idPrefix = 'mos-';

  /// A universal court takes the three games people bring a ball for.
  static const _universal = ['football', 'basketball', 'volleyball'];

  static Future<List<Venue>> load([AssetBundle? bundle]) async {
    final text = await (bundle ?? rootBundle).loadString(asset);
    return parse(text);
  }

  static List<Venue> parse(String text) {
    final doc = jsonDecode(text) as Map<String, dynamic>;
    final fields = (doc['fields'] as List).cast<String>();
    int at(String name) => fields.indexOf(name);
    final id = at('id'),
        kind = at('kind'),
        sport = at('sport'),
        name = at('name'),
        address = at('address'),
        lat = at('lat'),
        lon = at('lon'),
        surface = at('surface'),
        lighting = at('lighting'),
        description = at('description');
    final places = <Venue>[];
    for (final raw in doc['rows'] as List) {
      final row = raw as List;
      final sportId = row[sport] as String;
      final latitude = (row[lat] as num).toDouble();
      final longitude = (row[lon] as num).toDouble();
      places.add(
        Venue(
          id: '$idPrefix${row[id]}',
          name: row[name] as String,
          address: row[address] as String,
          sportIds: sportId == 'universal' ? _universal : [sportId],
          pricePerHour: 0,
          capacityMin: 2,
          capacityMax: 22,
          rating: 0,
          distanceKm: _kmFromCentre(latitude, longitude),
          latitude: latitude,
          longitude: longitude,
          description: row[description] as String,
          gradient: _gradient,
          isPublic: true,
          isRestricted: row[kind] == 'school',
          surface: row[surface] as String,
          hasLighting: row[lighting] == 1,
        ),
      );
    }
    return places;
  }

  /// The same measure clubs carry: straight-line kilometres from the
  /// Kremlin, which is what the distance filter compares.
  static double _kmFromCentre(double latitude, double longitude) {
    const centreLat = 55.755864, centreLon = 37.617698, radiusKm = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(latitude - centreLat);
    final dLon = rad(longitude - centreLon);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(centreLat)) *
            math.cos(rad(latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static const _gradient = [Color(0xFF1B3B2A), Color(0xFF3E7D5A)];
}
