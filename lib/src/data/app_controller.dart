import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sport_venue_models.dart';
import 'api_client.dart';
import 'session_store.dart';
import 'mock_data.dart';

/// The kinds of failure the app has words for.
enum AppErrorKind {
  network,
  invalidResponse,
  sessionExpired,
  slotTaken,
  gameFull,
  cancelNotOrganizer,
  badPhone,
  invalidCode,
  challengeExpired,
  tooManyAttempts,
  timeout,
  serverSaidSo,
  unknown,
}

class AppController extends ChangeNotifier {
  factory AppController({
    DateTime? now,
    SportVenueApiClient? api,
    bool closeApiOnDispose = false,
    SessionStore session = const NoSessionStore(),
  }) {
    return AppController._(
      now: now,
      api: api,
      closeApiOnDispose: closeApiOnDispose,
      session: session,
    );
  }

  AppController._({
    DateTime? now,
    this._api,
    this._closeApiOnDispose = false,
    this._session = const NoSessionStore(),
  }) : _now = now ?? DateTime.now() {
    sports = List<Sport>.from(MockData.sports);
    venues = List<Venue>.from(MockData.venues);
    selectedSportIds = {'football', 'padel', 'tennis'};

    // Unit and widget tests use the controller without a transport. The
    // production app constructs [connected], which replaces these fixtures
    // with server responses immediately after login.
    if (_api == null) {
      games = MockData.games(_now);
      bookings = [MockData.initialBooking(_now)];
    }
  }

  factory AppController.connected({
    DateTime? now,
    SportVenueApiClient? api,
    SessionStore session = const SecureSessionStore(),
  }) {
    // The client already knew how to hand its tokens over — nothing was
    // catching them, so every launch started from the phone number again.
    late final SportVenueApiClient client;
    client =
        api ??
        SportVenueApiClient(
          onTokensChanged: (tokens) =>
              tokens == null ? session.clear() : session.write(tokens),
        );
    return AppController(
      now: now,
      api: client,
      closeApiOnDispose: api == null,
      session: session,
    );
  }

  final DateTime _now;
  final SportVenueApiClient? _api;
  final bool _closeApiOnDispose;
  final SessionStore _session;

  String phone = '';
  String? userId;
  String? userName;
  bool isSignedIn = false;
  Set<String> selectedSportIds = {};
  List<Sport> sports = [];
  List<Venue> venues = [];
  List<Booking> bookings = [];
  List<Game> games = [];
  String? _phoneChallengeId;

  DateTime get now => _now;
  bool get isConnected => _api != null;
  String get greetingName =>
      userName?.trim().isNotEmpty == true ? userName!.trim() : 'спортсмен';

  List<Sport> get selectedSports {
    return sports
        .where((sport) => selectedSportIds.contains(sport.id))
        .toList();
  }

  List<Booking> get upcomingBookings {
    final upcoming = bookings
        .where((booking) => booking.isActive && booking.startsAt.isAfter(_now))
        .toList();
    upcoming.sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return upcoming;
  }

  bool canCancelBooking(Booking booking) {
    return _api == null || (userId != null && booking.organizerId == userId);
  }

  Sport sportById(String id) {
    return sports.firstWhere(
      (sport) => sport.id == id,
      orElse: () =>
          Sport(id: id, name: id, icon: '•', color: const Color(0xFF00A7C4)),
    );
  }

  List<Venue> get preferredVenues {
    if (selectedSportIds.isEmpty) {
      return venues;
    }
    return venues
        .where((venue) => venue.sportIds.any(selectedSportIds.contains))
        .toList();
  }

  List<Game> get preferredGames {
    if (selectedSportIds.isEmpty) {
      return games;
    }
    return games
        .where((game) => selectedSportIds.contains(game.sportId))
        .toList();
  }

  Future<void> startPhoneVerification(String newPhone) async {
    final api = _api;
    phone = newPhone;
    if (api == null) {
      _phoneChallengeId = 'demo';
      return;
    }
    final challenge = await api.startPhoneCall(
      phone: newPhone,
      consentAccepted: true,
    );
    _phoneChallengeId = challenge.id;
  }

  Future<void> signIn(String newPhone, String code) async {
    final api = _api;
    if (api == null) {
      if (_phoneChallengeId != 'demo' || code != '1111') {
        throw const ApiException(
          kind: ApiExceptionKind.authentication,
          message: 'invalid call code',
          statusCode: 400,
        );
      }
      phone = newPhone;
      isSignedIn = true;
      notifyListeners();
      return;
    }

    try {
      final challengeId = _phoneChallengeId;
      if (challengeId == null) {
        throw StateError('Phone verification has not been started');
      }
      await api.verifyPhoneCall(challengeId: challengeId, code: code);
      await _loadRemoteState(api);
      phone = newPhone;
      isSignedIn = true;
      notifyListeners();
    } catch (_) {
      api.clearTokens();
      rethrow;
    }
  }

  Future<void> _loadRemoteState(SportVenueApiClient api) async {
    final responses = await Future.wait<Object>([
      api.listSports(),
      api.listVenues(),
      api.getMe(),
      api.listBookings(),
      api.listGames(),
    ]);

    final sportRows = responses[0] as ApiJsonList;
    final venueRows = responses[1] as ApiJsonList;
    final user = responses[2] as ApiJsonObject;
    final bookingRows = responses[3] as ApiJsonList;
    final gameRows = responses[4] as ApiJsonList;

    final nextSports = sportRows.map(Sport.fromJson).toList();
    final nextVenues = _mapVenues(venueRows, nextSports);
    final nextUserId = user['id'] as String?;
    final preferredRows = user['preferred_sports'];
    final serverPreferences = preferredRows is List
        ? preferredRows
              .whereType<Map>()
              .map((item) => item['id'])
              .whereType<String>()
              .toSet()
        : <String>{};
    final validDefaults = selectedSportIds
        .where((id) => nextSports.any((sport) => sport.id == id))
        .toSet();
    final nextSelectedIds = serverPreferences.isNotEmpty
        ? serverPreferences
        : validDefaults.isNotEmpty
        ? validDefaults
        : nextSports.take(3).map((sport) => sport.id).toSet();

    sports = nextSports;
    venues = nextVenues;
    userId = nextUserId;
    userName = _userDisplayName(user);
    phone = user['phone'] as String? ?? phone;
    selectedSportIds = nextSelectedIds;
    bookings = bookingRows
        .map(
          (row) => _bookingFromJson(
            row,
            venueCatalog: nextVenues,
            currentUserId: nextUserId,
          ),
        )
        .toList();
    games = gameRows
        .map(
          (row) => _gameFromJson(
            row,
            venueCatalog: nextVenues,
            currentUserId: nextUserId,
          ),
        )
        .toList();
  }

  Future<void> completeSports(Set<String> ids) async {
    final next = Set<String>.from(ids);
    if (next.isEmpty || next.length > 6) {
      throw ArgumentError('Select between one and six sports.');
    }
    final api = _api;
    if (api != null) {
      await api.updatePreferences(next);
    }
    selectedSportIds = next;
    notifyListeners();
  }

  void togglePreferredSport(String id) {
    final next = Set<String>.from(selectedSportIds);
    if (next.contains(id)) {
      if (next.length == 1) {
        return;
      }
      next.remove(id);
    } else {
      next.add(id);
    }
    selectedSportIds = next;
    notifyListeners();

    final api = _api;
    if (api != null) {
      unawaited(_savePreferences(api, next));
    }
  }

  Future<void> _savePreferences(
    SportVenueApiClient api,
    Set<String> next,
  ) async {
    try {
      await api.updatePreferences(next);
    } catch (_) {
      // Re-fetching the profile on the next login resolves any optimistic
      // difference. Interactive onboarding uses [completeSports] and surfaces
      // request errors directly.
    }
  }

  Future<List<TimeSlot>> loadSlots({
    required Venue venue,
    required DateTime day,
    required int durationMinutes,
  }) async {
    final api = _api;
    if (api == null) {
      return MockData.timeSlots();
    }
    final rows = await api.listVenueSlots(
      venue.id,
      day: day,
      durationMinutes: durationMinutes,
    );
    return rows.map(TimeSlot.fromJson).toList();
  }

  Future<Booking> addBooking(BookingDraft draft) async {
    final api = _api;
    if (api == null) {
      final statusCode = draft.mode == PaymentMode.split
          ? 'collecting_shares'
          : 'confirmed';
      final booking = Booking(
        id: 'booking-${bookings.length + 1}',
        draft: draft,
        statusCode: statusCode,
        organizerId: userId,
        createdAt: _now,
      );
      bookings = [booking, ...bookings];
      notifyListeners();
      return booking;
    }

    final startsAt = _apiStartTime(draft.date, draft.startHour);
    await api.createSlotLock(
      draft.venue.id,
      startsAt: startsAt,
      durationMinutes: draft.durationMinutes,
    );
    final row = await api.createBooking(
      venueId: draft.venue.id,
      startsAt: startsAt,
      durationMinutes: draft.durationMinutes,
      players: draft.players,
      paymentMode: draft.mode.name,
    );
    final booking = _bookingFromJson(
      row,
      venueCatalog: venues,
      currentUserId: userId,
    );
    bookings = [booking, ...bookings.where((item) => item.id != booking.id)];
    notifyListeners();
    return booking;
  }

  Future<Booking> cancelBooking(Booking booking) async {
    final api = _api;
    final updated = api == null
        ? booking.copyWith(statusCode: 'cancelled')
        : _bookingFromJson(
            await api.cancelBooking(booking.id),
            venueCatalog: venues,
            currentUserId: userId,
          );

    bookings = [
      for (final item in bookings)
        if (item.id == updated.id) updated else item,
    ];
    notifyListeners();
    return updated;
  }

  Future<bool> joinGame(Game game) async {
    if (game.isFull || game.participants.any((p) => p.isCurrentUser)) {
      return false;
    }

    final api = _api;
    if (api == null) {
      games = [
        for (final item in games)
          if (item.id == game.id)
            item.copyWith(
              participants: [
                ...item.participants,
                const Participant(
                  name: 'Вы',
                  initial: 'В',
                  rating: 4.7,
                  isCurrentUser: true,
                ),
              ],
            )
          else
            item,
      ];
      notifyListeners();
      return true;
    }

    final row = await api.joinGame(game.id);
    final updated = _gameFromJson(
      row,
      venueCatalog: venues,
      currentUserId: userId,
    );
    games = [
      for (final item in games)
        if (item.id == updated.id) updated else item,
    ];
    notifyListeners();
    return true;
  }

  /// Gives up a place in a game. Answers false when there was none to give.
  Future<bool> leaveGame(Game game) async {
    if (!game.participants.any((player) => player.isCurrentUser)) {
      return false;
    }

    final api = _api;
    if (api == null) {
      games = [
        for (final item in games)
          if (item.id == game.id)
            item.copyWith(
              participants: item.participants
                  .where((player) => !player.isCurrentUser)
                  .toList(),
            )
          else
            item,
      ];
      notifyListeners();
      return true;
    }

    final row = await api.leaveGame(game.id);
    final updated = _gameFromJson(
      row,
      venueCatalog: venues,
      currentUserId: userId,
    );
    games = [
      for (final item in games)
        if (item.id == updated.id) updated else item,
    ];
    notifyListeners();
    return true;
  }

  Future<Game> createGame({
    required String sportId,
    required Venue venue,
    required DateTime date,
    required int startHour,
    required int durationMinutes,
    required int capacity,
    required GameType type,
    required GenderFilter genderFilter,
  }) async {
    final api = _api;
    if (api == null) {
      final draft = BookingDraft(
        venue: venue,
        date: date,
        durationMinutes: durationMinutes,
        startHour: startHour,
        players: capacity,
        mode: PaymentMode.split,
      );
      final game = Game(
        id: 'game-${games.length + 1}',
        sportId: sportId,
        venue: venue,
        date: date,
        startHour: startHour,
        durationMinutes: durationMinutes,
        capacity: capacity,
        pricePerPerson: draft.sharePrice,
        type: type,
        genderFilter: genderFilter,
        organizer: const Participant(
          name: 'Вы',
          initial: 'В',
          rating: 4.7,
          isCurrentUser: true,
        ),
        participants: const [
          Participant(
            name: 'Вы',
            initial: 'В',
            rating: 4.7,
            isCurrentUser: true,
          ),
        ],
      );
      games = [game, ...games];
      notifyListeners();
      return game;
    }

    final startsAt = _apiStartTime(date, startHour);
    await api.createSlotLock(
      venue.id,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
    );
    final row = await api.createGame(
      sportId: sportId,
      venueId: venue.id,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      capacity: capacity,
      gameType: type.name,
      genderFilter: genderFilter.name,
    );
    final game = _gameFromJson(
      row,
      venueCatalog: venues,
      currentUserId: userId,
    );
    games = [game, ...games.where((item) => item.id != game.id)];
    notifyListeners();
    return game;
  }

  /// Picks up a session left by a previous run, if the device still has one
  /// and the server still honours it.
  ///
  /// Answers whether the app can go straight to the main screen. A refusal
  /// is not an error to report: an expired or withdrawn session simply means
  /// signing in again, which is what the screen behind the splash is for.
  Future<bool> restoreSession() async {
    final api = _api;
    if (api == null) {
      return false;
    }
    final tokens = await _session.read();
    if (tokens == null) {
      return false;
    }
    api.setTokens(tokens);
    try {
      await _loadRemoteState(api);
    } catch (_) {
      api.clearTokens();
      return false;
    }
    isSignedIn = true;
    notifyListeners();
    return true;
  }

  /// Re-reads everything the screens show. Pull-to-refresh calls this.
  ///
  /// It throws on failure rather than swallowing: the gesture was explicit,
  /// so a server that will not answer is worth saying out loud.
  Future<void> refresh() async {
    final api = _api;
    if (api == null) {
      // Demo mode has no server to ask, but the gesture still has to
      // resolve — an indicator with nothing to wait for never leaves.
      await Future<void>.delayed(const Duration(milliseconds: 420));
      notifyListeners();
      return;
    }
    await _loadRemoteState(api);
    notifyListeners();
  }

  void logout() {
    _api?.clearTokens();
    phone = '';
    userId = null;
    userName = null;
    isSignedIn = false;
    selectedSportIds = {'football', 'padel', 'tennis'};
    if (_api == null) {
      bookings = [MockData.initialBooking(_now)];
      games = MockData.games(_now);
    } else {
      bookings = [];
      games = [];
    }
    notifyListeners();
  }

  /// What went wrong, in terms a screen can put into words.
  ///
  /// The controller classifies; the wording belongs upstairs, where the
  /// reader's language is known. It used to return Russian sentences from
  /// the data layer, which meant the app could never speak anything else.
  static AppErrorKind kindOf(Object error) {
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      if (error.kind == ApiExceptionKind.network) {
        return AppErrorKind.network;
      }
      if (error.kind == ApiExceptionKind.invalidResponse) {
        return AppErrorKind.invalidResponse;
      }
      if (error.isUnauthorized) {
        return AppErrorKind.sessionExpired;
      }
      if (message.contains('slot is unavailable') ||
          message.contains('slot is locked')) {
        return AppErrorKind.slotTaken;
      }
      if (message.contains('game is full')) {
        return AppErrorKind.gameFull;
      }
      if (message.contains('only organizer can cancel booking')) {
        return AppErrorKind.cancelNotOrganizer;
      }
      if (message.contains('phone')) {
        return AppErrorKind.badPhone;
      }
      if (message.contains('invalid call code')) {
        return AppErrorKind.invalidCode;
      }
      if (message.contains('challenge has expired')) {
        return AppErrorKind.challengeExpired;
      }
      if (message.contains('too many code attempts')) {
        return AppErrorKind.tooManyAttempts;
      }
      // Something the server explained in its own words, which is better
      // than a shrug even untranslated.
      return AppErrorKind.serverSaidSo;
    }
    if (error is TimeoutException) {
      return AppErrorKind.timeout;
    }
    return AppErrorKind.unknown;
  }

  @override
  void dispose() {
    if (_closeApiOnDispose) {
      _api?.close();
    }
    super.dispose();
  }
}

List<Venue> _mapVenues(ApiJsonList rows, List<Sport> sports) {
  final colors = {for (final sport in sports) sport.id: sport.color};
  return rows.map((row) {
    final sportIds = row['sport_ids'];
    final firstSportId = sportIds is List
        ? sportIds.whereType<String>().firstOrNull
        : null;
    return Venue.fromJson(
      row,
      accent: colors[firstSportId] ?? const Color(0xFF00A7C4),
    );
  }).toList();
}

Venue _venueFromJson(ApiJsonObject row, {required List<Venue> venueCatalog}) {
  final id = row['id'];
  final existing = venueCatalog.where((venue) => venue.id == id).firstOrNull;
  if (existing != null) {
    return existing;
  }
  return Venue.fromJson(row);
}

Booking _bookingFromJson(
  ApiJsonObject row, {
  required List<Venue> venueCatalog,
  String? currentUserId,
}) {
  final venueRow = _objectField(row, 'venue');
  return Booking.fromJson(
    row,
    venue: _venueFromJson(venueRow, venueCatalog: venueCatalog),
    currentUserId: currentUserId,
  );
}

Game _gameFromJson(
  ApiJsonObject row, {
  required List<Venue> venueCatalog,
  required String? currentUserId,
}) {
  final venueRow = _objectField(row, 'venue');
  return Game.fromJson(
    row,
    venue: _venueFromJson(venueRow, venueCatalog: venueCatalog),
    currentUserId: currentUserId,
  );
}

ApiJsonObject _objectField(ApiJsonObject row, String key) {
  final value = row[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  throw FormatException('Expected "$key" to be an object.');
}

DateTime _apiStartTime(DateTime day, int hour) {
  // The backend currently models Moscow booking hours as UTC wall-clock.
  return DateTime.utc(day.year, day.month, day.day, hour);
}

String? _userDisplayName(ApiJsonObject user) {
  final parts = [
    user['name'] as String?,
    user['last_name'] as String?,
  ].whereType<String>().where((part) => part.trim().isNotEmpty);
  final joined = parts.join(' ').trim();
  return joined.isEmpty ? null : joined;
}
