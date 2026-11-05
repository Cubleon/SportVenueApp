import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

class ClubDashboardFixture {
  ClubDashboardFixture({bool empty = false}) {
    if (!empty) {
      clubs.add({
        'id': 'club-owned',
        'name': 'Спортклуб «Арена»',
        'address': 'Москва, ул. Лужники, 24',
        'city_id': 'moscow',
        'description': 'Теннис и командные игры каждый день.',
        'geo_lat': 55.715,
        'geo_lng': 37.555,
      });
      venues.add({
        'id': 'court-owned',
        'club_id': 'club-owned',
        'name': 'Теннисный корт №1',
        'sport_ids': ['tennis'],
        'base_price_per_hour': 2500,
        'capacity_min': 1,
        'capacity_max': 4,
        'description': 'Крытый корт с покрытием хард.',
      });
    }
  }

  late final client = SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    initialTokens: ApiTokenPair(
      accessToken: 'club-access',
      refreshToken: 'club-refresh',
      tokenType: 'bearer',
      expiresAt: DateTime.utc(2099),
    ),
    httpClient: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (request.method == 'GET') {
        if (loadFails) return _json({'detail': 'Unavailable'}, 503);
        if (path.endsWith('/sports')) {
          return _json([
            {'id': 'tennis', 'name': 'Теннис'},
            {'id': 'football', 'name': 'Футбол'},
          ]);
        }
        if (path.endsWith('/club/clubs')) return _json(clubs);
        if (path.endsWith('/club/venues')) return _json(venues);
        if (path.endsWith('/availability')) return _json(windows);
      }
      if (request.method == 'DELETE') {
        await beforeDelete?.call();
        if (deletionConflicts) return _json({'detail': 'Booking exists'}, 409);
        if (deleteStatus != 204) {
          return _json({'detail': 'Unavailable'}, deleteStatus);
        }
        if (path.contains('/club/clubs/')) {
          final id = request.url.pathSegments.last;
          final venueIds = venues
              .where((venue) => venue['club_id'] == id)
              .map((venue) => venue['id'])
              .toSet();
          clubs.removeWhere((club) => club['id'] == id);
          venues.removeWhere((venue) => venue['club_id'] == id);
          windows.removeWhere(
            (window) => venueIds.contains(window['venue_id']),
          );
        } else if (path.contains('/club/venues/') &&
            !path.contains('/availability/')) {
          final id = request.url.pathSegments.last;
          venues.removeWhere((venue) => venue['id'] == id);
          windows.removeWhere((window) => window['venue_id'] == id);
        } else {
          windows.removeWhere((window) => path.endsWith('/${window['id']}'));
        }
        if (loadFailsAfterDelete) loadFails = true;
        return http.Response('', 204);
      }
      await beforeSave?.call();
      if (saveStatus != 200) {
        return _json({'detail': 'Save failed'}, saveStatus);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (path.endsWith('/availability')) {
        final window = <String, dynamic>{'id': 'window-new', ...body};
        windows.add(window);
        return _json(window);
      }
      if (path.endsWith('/club/clubs/club-owned')) {
        clubs.first.addAll(body);
        return _json(clubs.first);
      }
      if (path.endsWith('/club/clubs')) {
        final club = <String, dynamic>{'id': 'club-new', ...body};
        clubs.add(club);
        return _json(club);
      }
      if (path.endsWith('/venues')) {
        final venue = <String, dynamic>{
          'id': 'court-new',
          'club_id': 'club-owned',
          ...body,
        };
        venues.add(venue);
        return _json(venue);
      }
      return _json({'detail': 'Not Found'}, 404);
    }),
  );

  final clubs = <Map<String, dynamic>>[];
  final venues = <Map<String, dynamic>>[];
  final windows = <Map<String, dynamic>>[];
  final requests = <http.Request>[];
  bool loadFails = false;
  bool deletionConflicts = false;
  bool loadFailsAfterDelete = false;
  int deleteStatus = 204;
  int saveStatus = 200;
  Future<void> Function()? beforeSave;
  Future<void> Function()? beforeDelete;

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}
