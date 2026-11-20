import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/open_places.dart';
import 'package:sport_venue_app/src/widgets/map_clusters.dart';

/// The city's open data and the map that has to stay readable with it.
void main() {
  test('the shipped file reads as free public courts in Moscow', () {
    final places = OpenPlaces.parse(
      File(OpenPlaces.asset).readAsStringSync(),
    );
    expect(places.length, greaterThan(5000));
    final ids = places.map((place) => place.id).toSet();
    expect(ids.length, places.length, reason: 'every id is unique');
    for (final place in places) {
      expect(place.id, startsWith(OpenPlaces.idPrefix));
      expect(place.isPublic, isTrue);
      expect(place.pricePerHour, 0);
      expect(place.sportIds, isNotEmpty);
      expect(place.latitude, inInclusiveRange(55.1, 56.1));
      expect(place.longitude, inInclusiveRange(36.7, 38.0));
    }
    expect(places.where((place) => place.isRestricted), isNotEmpty);
    expect(
      places.where((place) => place.sportIds.contains('football')),
      isNotEmpty,
    );
  });

  group('clusters', () {
    // Two courts across a road from each other, and one across the city.
    final points = [
      (55.7500, 37.6000),
      (55.7502, 37.6003),
      (55.6500, 37.7500),
    ];
    List<MapCluster<(double, double)>> at(double zoom) => clusterPoints(
      points,
      latitude: (p) => p.$1,
      longitude: (p) => p.$2,
      zoom: zoom,
    );

    test('neighbours merge at city scale, the far one stays apart', () {
      final groups = at(10);
      expect(groups.length, 2);
      expect(groups.first.items.length, 2);
      expect(groups.first.latitude, closeTo(55.7501, 0.0001));
      expect(groups.last.isSingle, isTrue);
    });

    test('close in, every court is its own pin', () {
      expect(at(18).every((group) => group.isSingle), isTrue);
    });

    test('at the widest zoom the whole city is one group', () {
      final groups = at(3);
      expect(groups.length, 1);
      expect(groups.single.items.length, 3);
    });
  });
}
