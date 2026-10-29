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
  sharePaid,
  deadlinePassed,
  cancelNotOrganizer,
  badPhone,
  badEmail,
  invalidEmailCode,
  emailChallengeExpired,
  emailAttemptsExceeded,
  emailUnavailable,
  emailTooManyRequests,
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

  /// The demo build: no server, the fixtures as data, and a way in that
  /// asks for nothing.
  ///
  /// The demo used to be made by editing [SportVenueApp] to build a plain
  /// controller and editing it back after the build. Once sign-in became a
  /// real phone call there was no way in without a server at all, so the
  /// demo stopped at the phone field. A build flag chooses this instead,
  /// and only a build made with it has the door.
  factory AppController.demo({DateTime? now}) {
    return AppController._(now: now, isDemo: true);
  }

  AppController._({
    DateTime? now,
    this._api,
    this._closeApiOnDispose = false,
    this._session = const NoSessionStore(),
    this.isDemo = false,
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
    // The demo shows the admin's side too: whoever is shown the pilot is
    // shown both ends of a payment.
    isPaymentAdmin = isDemo;
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

  /// Whether this is the demo build, which signs in without a server.
  final bool isDemo;

  String phone = '';
  String email = '';
  String? userId;
  String? userName;
  bool isSignedIn = false;

  /// Whether the reader checks transfers and makes refunds. Only the
  /// owner of the service, on the pilot; the server says who.
  bool isPaymentAdmin = false;

  /// Where shares are paid to, once asked for. See [loadPaymentInfo].
  PaymentInfo? paymentInfo;

  /// The next share code the fixtures hand out. The server makes its own.
  int _nextShareCode = 5101;
  Set<String> selectedSportIds = {};
  List<Sport> sports = [];
  List<Venue> venues = [];
  List<Booking> bookings = [];

  /// The ones that are still going to happen.
  ///
  /// Every counter in the app read [bookings] and so went on counting a
  /// booking after it was cancelled: the home said «Мои брони 1» over an
  /// empty evening, and the list it opened said «1 бронь» above a row
  /// marked отменена.
  List<Booking> get activeBookings =>
      bookings.where((booking) => booking.isActive).toList();
  List<Game> games = [];
  ApiPhoneChallenge? phoneChallenge;
  String? _confirmedChallengeId;
  int _phoneVerificationVersion = 0;
  ApiEmailChallenge? emailChallenge;
  String? _confirmedEmailChallengeId;
  int _emailVerificationVersion = 0;

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
    if (_api == null) {
      // The demo's own bookings carry no organiser; a friend's does.
      return booking.organizerId == null || booking.organizerId == userId;
    }
    return userId != null && booking.organizerId == userId;
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

  Future<ApiPhoneChallenge> startPhoneVerification(String newPhone) async {
    final api = _api;
    if (api == null) {
      throw StateError('Phone verification requires a server connection');
    }
    cancelPhoneVerification();
    cancelEmailVerification();
    final version = _phoneVerificationVersion;
    final challenge = await api.startPhoneCall(
      phone: newPhone,
      consentAccepted: true,
    );
    if (version == _phoneVerificationVersion) {
      phone = newPhone;
      phoneChallenge = challenge;
    }
    return challenge;
  }

  void cancelPhoneVerification() {
    _phoneVerificationVersion++;
    phoneChallenge = null;
    if (_confirmedChallengeId != null && !isSignedIn) {
      _api?.clearTokens();
    }
    _confirmedChallengeId = null;
  }

  Future<PhoneCallStatus> checkPhoneVerification() async {
    final api = _api;
    final challenge = phoneChallenge;
    if (api == null || challenge == null) {
      throw StateError('Phone verification has not been started');
    }
    final version = _phoneVerificationVersion;
    bool stillCurrent() => version == _phoneVerificationVersion;
    if (_confirmedChallengeId != challenge.id) {
      final result = await api.checkPhoneCall(challengeId: challenge.id);
      if (!stillCurrent()) return PhoneCallStatus.pending;
      if (result.status != PhoneCallStatus.confirmed) {
        return result.status;
      }
      api.setTokens(result.tokens!);
      _confirmedChallengeId = challenge.id;
    }
    // A failed catalog load can retry with the issued tokens; the server
    // challenge is single-use and must not be redeemed a second time.
    await _loadRemoteState(api, stillCurrent: stillCurrent);
    if (!stillCurrent()) return PhoneCallStatus.pending;
    isSignedIn = true;
    notifyListeners();
    return PhoneCallStatus.confirmed;
  }

  /// Signs in the demo build with whatever was typed, and asks for no call
  /// and no code: there is nobody on the other end to confirm them.
  ///
  /// Refused outside the demo build, so the real app cannot be walked into
  /// without the server saying yes.
  void signInDemo({String phone = '', String email = ''}) {
    if (!isDemo) {
      throw StateError('Demo sign-in exists only in the demo build');
    }
    this.phone = phone;
    this.email = email.trim().toLowerCase();
    isSignedIn = true;
    notifyListeners();
  }

  bool get emailCodeAccepted => _confirmedEmailChallengeId != null;

  Future<ApiEmailChallenge> startEmailVerification(String newEmail) async {
    final api = _api;
    if (api == null) {
      throw StateError('Email verification requires a server connection');
    }
    cancelPhoneVerification();
    final version = ++_emailVerificationVersion;
    final challenge = await api.startEmailLogin(
      email: newEmail.trim(),
      consentAccepted: true,
    );
    if (version == _emailVerificationVersion) {
      if (_confirmedEmailChallengeId != null && !isSignedIn) api.clearTokens();
      _confirmedEmailChallengeId = null;
      email = newEmail.trim().toLowerCase();
      emailChallenge = challenge;
    }
    return challenge;
  }

  void cancelEmailVerification() {
    _emailVerificationVersion++;
    emailChallenge = null;
    if (_confirmedEmailChallengeId != null && !isSignedIn) _api?.clearTokens();
    _confirmedEmailChallengeId = null;
  }

  Future<void> verifyEmailCode(String code) async {
    final api = _api;
    final challenge = emailChallenge;
    if (api == null || challenge == null) {
      throw StateError('Email verification has not been started');
    }
    final version = _emailVerificationVersion;
    bool stillCurrent() => version == _emailVerificationVersion;
    if (_confirmedEmailChallengeId != challenge.id) {
      final tokens = await api.verifyEmailCode(
        challengeId: challenge.id,
        code: code,
      );
      if (!stillCurrent()) return;
      api.setTokens(tokens);
      _confirmedEmailChallengeId = challenge.id;
    }
    // Catalog failures retry with the issued tokens; the code is single-use.
    await _loadRemoteState(api, stillCurrent: stillCurrent);
    if (!stillCurrent()) return;
    isSignedIn = true;
    notifyListeners();
  }

  Future<void> _loadRemoteState(
    SportVenueApiClient api, {
    bool Function()? stillCurrent,
  }) async {
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

    if (stillCurrent != null && !stillCurrent()) return;
    sports = nextSports;
    venues = nextVenues;
    userId = nextUserId;
    userName = _userDisplayName(user);
    phone = user['phone'] as String? ?? '';
    email = user['email'] as String? ?? '';
    isPaymentAdmin = user['is_payment_admin'] == true;
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

  /// Saves the sports the reader says they play.
  ///
  /// An empty set is allowed and means "no preference": [preferredVenues]
  /// and [preferredGames] already read it that way. Refusing it would force
  /// onboarding to hold the reader at a greyed-out button until they name a
  /// sport, and the honest answer "I'll play anything" has to be sayable.
  Future<void> completeSports(Set<String> ids) async {
    final next = Set<String>.from(ids);
    if (next.length > 6) {
      throw ArgumentError('Select at most six sports.');
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
      final booking = _fixtureBooking(draft);
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
        ? _withRefunds(booking, statusCode: 'cancelled')
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
      // Joining a paid game is taking one of its booking's shares. The
      // fixtures' own games were made before bookings carried them, so they
      // still let anyone in for nothing.
      final share = game.bookingId == null
          ? null
          : _takeOpenShare(game.bookingId!);
      games = [
        for (final item in games)
          if (item.id == game.id)
            item
                .copyWith(
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
                .withMyShare(share ?? item.myShare)
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
      final bookingId = game.bookingId;
      if (bookingId != null) {
        // Throws, as the server answers, when the place has been paid for.
        _releaseMyShare(bookingId);
      }
      games = [
        for (final item in games)
          if (item.id == game.id)
            item
                .copyWith(
                  participants: item.participants
                      .where((player) => !player.isCurrentUser)
                      .toList(),
                )
                .withMyShare(null)
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
    GamePayment payment = GamePayment.shares,
  }) async {
    final api = _api;
    if (api == null) {
      if (payment == GamePayment.free) {
        // Open courts come later; the server will refuse this too.
        throw StateError('Free games need an open court');
      }
      final draft = BookingDraft(
        venue: venue,
        date: date,
        durationMinutes: durationMinutes,
        startHour: startHour,
        players: capacity,
        mode: payment == GamePayment.organizer
            ? PaymentMode.full
            : PaymentMode.split,
      );
      final gameId = 'game-${games.length + 1}';
      // A paid game stands on a booking, and its places are the booking's
      // shares: the organiser holds the first one from the start.
      final booking = _fixtureBooking(draft, gameId: gameId);
      final game = Game(
        id: gameId,
        payment: payment,
        bookingId: booking.id,
        myShare: booking.myShare,
        deadlineAt: booking.deadline,
        sportId: sportId,
        venue: venue,
        date: date,
        startHour: startHour,
        durationMinutes: durationMinutes,
        capacity: capacity,
        pricePerPerson: payment == GamePayment.organizer
            ? 0
            : booking.shares.first.amount ?? draft.sharePrice,
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
      bookings = [booking, ...bookings];
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
      payment: payment.name,
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

  /// Bookings opened by a link that the reader has no place in yet. Kept
  /// apart so a friend's booking does not show up under «Мои брони» until
  /// the reader takes a place in it.
  final Map<String, Booking> _linkedBookings = {};

  /// The booking with this id: the reader's own, or one opened by a link.
  Booking? bookingById(String id) =>
      bookings.where((booking) => booking.id == id).firstOrNull ??
      _linkedBookings[id];

  /// The game with this id, if it is loaded.
  Game? gameById(String id) => games.where((game) => game.id == id).firstOrNull;

  /// Finds a booking that may not be the reader's: what a link from a
  /// friend arrives at. Asks the server even when the booking is known, so
  /// the shares shown are the current ones; a known booking survives a
  /// failed request. Null when there is no such booking.
  Future<Booking?> openBooking(String id) async {
    final known = bookingById(id);
    final api = _api;
    if (api == null) {
      if (known != null) {
        return known;
      }
      final linked = MockData.friendBooking(_now);
      if (linked.id != id) {
        return null;
      }
      _linkedBookings[id] = linked;
      notifyListeners();
      return linked;
    }
    try {
      final booking = _bookingFromJson(
        await api.getBooking(id),
        venueCatalog: venues,
        currentUserId: userId,
      );
      final mine =
          bookings.any((item) => item.id == id) ||
          booking.myShare != null ||
          (userId != null && booking.organizerId == userId);
      if (mine) {
        _replaceBooking(booking);
      } else {
        _linkedBookings[id] = booking;
      }
      notifyListeners();
      return booking;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      if (known != null) {
        return known;
      }
      rethrow;
    }
  }

  /// Finds a game by its id, the way [openBooking] finds a booking, and the
  /// booking under it as well, so the game screen can say where it stands.
  Future<Game?> openGame(String id) async {
    final known = gameById(id);
    final api = _api;
    if (api == null) {
      return known;
    }
    final Game game;
    try {
      game = _gameFromJson(
        await api.getGame(id),
        venueCatalog: venues,
        currentUserId: userId,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      if (known != null) {
        return known;
      }
      rethrow;
    }
    games = known == null
        ? [game, ...games]
        : [for (final item in games) item.id == id ? game : item];
    notifyListeners();
    final bookingId = game.bookingId;
    if (bookingId != null) {
      // The status card is a nicety on this screen; the game opens without it.
      try {
        await openBooking(bookingId);
      } on Object {
        // Nothing to say: the card simply does not appear.
      }
    }
    return gameById(id);
  }

  /// Takes a free place in a split booking: what following an invite link
  /// to a booking ends in.
  Future<Booking> takeShare(Booking booking) async {
    final api = _api;
    if (api == null) {
      _refuseAfterDeadline(booking);
      _takeOpenShare(booking.id);
      return bookingById(booking.id)!;
    }
    return _storeBooking(await api.joinBookingShare(booking.id));
  }

  /// Gives back the reader's place while nothing has been paid for it.
  Future<Booking> releaseShare(Booking booking) async {
    final api = _api;
    if (api == null) {
      _releaseMyShare(booking.id);
      return bookingById(booking.id)!;
    }
    final share = booking.myShare;
    if (share?.id == null) {
      throw _refusal('not in booking', 409);
    }
    return _storeBooking(await api.releaseShare(booking.id, share!.id!));
  }

  /// «Я оплатил»: the reader says the transfer has gone, and the share joins
  /// the admin's queue. Nothing is paid until the admin finds it.
  ///
  /// [payerName] is the sender's name as the reader's bank shows it.
  Future<Booking> claimSharePaid(
    Booking booking,
    BookingShare share, {
    String? payerName,
  }) async {
    final name = payerName?.trim();
    final api = _api;
    if (api == null) {
      _refuseAfterDeadline(booking);
      if (!share.isCurrentUser) {
        throw _refusal('not your share', 403);
      }
      if (share.status != ShareStatus.unpaid &&
          share.status != ShareStatus.notFound) {
        throw _refusal('share is not awaiting payment', 409);
      }
      return _updateShare(
        share.id!,
        (item) => item.copyWith(
          status: ShareStatus.pendingConfirmation,
          claimedAt: _now,
        ),
      );
    }
    return _storeBooking(
      await api.claimSharePaid(
        booking.id,
        share.id!,
        payerName: name == null || name.isEmpty ? null : name,
      ),
    );
  }

  /// Where shares are paid to. The fixtures answer with test details that
  /// say plainly they are not real.
  Future<PaymentInfo> loadPaymentInfo() async {
    final api = _api;
    final info = api == null
        ? MockData.paymentInfo
        : PaymentInfo.fromJson(await api.getPaymentInfo());
    paymentInfo = info;
    return info;
  }

  /// One of the admin's lists: shares to check (`pendingConfirmation`) or
  /// refunds to make (`refundDue`), the most urgent first.
  Future<List<PaymentQueueItem>> loadPaymentQueue(ShareStatus status) async {
    final api = _api;
    if (api != null) {
      final rows = await api.listAdminShares(status: status.code);
      return rows.map(PaymentQueueItem.fromJson).toList();
    }
    final items = <PaymentQueueItem>[
      for (final booking in bookings)
        for (final share in booking.shares)
          if (share.status == status && share.id != null)
            PaymentQueueItem(
              shareId: share.id!,
              bookingId: booking.id,
              code: share.code ?? '',
              amount: share.amount ?? booking.draft.sharePrice,
              status: share.status,
              userName: share.name,
              venueName: booking.draft.venue.name,
              startsAt: booking.startsAt,
              deadlineAt: booking.deadline,
              claimedAt: share.claimedAt,
              note: share.note,
            ),
    ];
    // The queue goes by what runs out first; refunds by what has waited
    // longest, which the deadline stands in for.
    items.sort((left, right) => left.deadlineAt.compareTo(right.deadlineAt));
    return items;
  }

  /// The admin found the transfer. A share nobody pressed «Я оплатил» for
  /// can be confirmed too: people pay and forget the button.
  Future<void> confirmShare(String shareId) => _adminAction(
    shareId,
    allowed: const {
      ShareStatus.unpaid,
      ShareStatus.pendingConfirmation,
      ShareStatus.notFound,
    },
    apply: (share) =>
        share.copyWith(status: ShareStatus.paid, confirmedAt: _now),
    remote: (api) => api.confirmShare(shareId),
  );

  /// The admin looked and did not find it. [note] is shown to the player.
  Future<void> rejectShare(String shareId, {String? note}) => _adminAction(
    shareId,
    allowed: const {ShareStatus.pendingConfirmation},
    apply: (share) => share.copyWith(status: ShareStatus.notFound, note: note),
    remote: (api) => api.rejectShare(shareId, note: note),
  );

  /// The money went back to the player.
  Future<void> markShareRefunded(String shareId, {String? note}) =>
      _adminAction(
        shareId,
        allowed: const {ShareStatus.refundDue},
        apply: (share) => share.copyWith(
          status: ShareStatus.refunded,
          refundedAt: _now,
          note: note,
        ),
        remote: (api) => api.markShareRefunded(shareId, note: note),
      );

  /// What the server's clock does to bookings, done by the fixtures: at the
  /// deadline a booking is confirmed, waits for the admin, or falls through
  /// with its money owed back. A connected app leaves this to the server.
  void applyDeadlines([DateTime? at]) {
    if (_api != null) {
      return;
    }
    final moment = at ?? _now;
    var changed = false;
    final next = <Booking>[];
    for (final booking in bookings) {
      final settled = _atDeadline(booking, moment);
      changed = changed || !identical(settled, booking);
      next.add(settled);
    }
    if (!changed) {
      return;
    }
    bookings = next;
    for (final booking in next) {
      _syncGame(booking);
    }
    notifyListeners();
  }

  /// Deletes the account and signs out. Places nobody paid for are given
  /// back; money already sent is owed back, which the server takes care of.
  Future<void> deleteAccount() async {
    final api = _api;
    if (api != null) {
      await api.deleteMe();
    }
    logout();
  }

  Future<void> _adminAction(
    String shareId, {
    required Set<ShareStatus> allowed,
    required BookingShare Function(BookingShare share) apply,
    required Future<ApiJsonObject> Function(SportVenueApiClient api) remote,
  }) async {
    if (!isPaymentAdmin) {
      throw _refusal('payments admin only', 403);
    }
    final api = _api;
    if (api != null) {
      final row = await remote(api);
      // The server answers with the booking; one the reader does not hold
      // is the admin's business, not the reader's list.
      if (row['time_slot'] is Map &&
          bookings.any((booking) => booking.id == row['id'])) {
        _storeBooking(row);
      }
      return;
    }
    final share = _shareById(shareId);
    if (share == null) {
      throw _refusal('share not found', 404);
    }
    if (!allowed.contains(share.status)) {
      throw _refusal('share is ${share.status.code}', 409);
    }
    _updateShare(shareId, apply);
  }

  /// A new booking as the server will make it: every place a share of the
  /// total, the reader holding the first one, the rest free to take.
  Booking _fixtureBooking(BookingDraft draft, {String? gameId}) {
    final id = 'booking-${bookings.length + 1}';
    final amounts = draft.mode == PaymentMode.split
        ? splitIntoShares(draft.totalPrice, draft.players)
        : [draft.totalPrice];
    final shares = [
      for (var i = 0; i < amounts.length; i++)
        BookingShare(
          id: '$id-share-${i + 1}',
          userId: i == 0 ? (userId ?? 'me') : null,
          name: i == 0 ? 'Вы' : '',
          initial: i == 0 ? 'В' : '',
          status: i == 0 ? ShareStatus.unpaid : ShareStatus.open,
          amount: amounts.elementAt(i),
          code: 'SV-${_nextShareCode++}',
          isCurrentUser: i == 0,
        ),
    ];
    return Booking(
      id: id,
      draft: draft.copyWith(
        quotedTotalPrice: draft.totalPrice,
        quotedSharePrice: amounts.first,
      ),
      statusCode: 'collecting_shares',
      organizerId: userId,
      createdAt: _now,
      shares: shares,
      gameId: gameId,
      myShareId: shares.first.id,
    );
  }

  /// The booking in a final state, with every share that holds money, or a
  /// claim of it, owed back.
  Booking _withRefunds(Booking booking, {required String statusCode}) {
    return booking.copyWith(
      statusCode: statusCode,
      shares: [
        for (final share in booking.shares)
          share.status.holdsMoney
              ? share.copyWith(status: ShareStatus.refundDue)
              : share,
      ],
    );
  }

  Booking _atDeadline(Booking booking, DateTime moment) {
    if (booking.shares.isEmpty) {
      return booking;
    }
    if (booking.isCollectingShares && !moment.isBefore(booking.deadline)) {
      final missing = booking.shares.any(
        (share) =>
            share.status == ShareStatus.open ||
            share.status == ShareStatus.unpaid ||
            share.status == ShareStatus.notFound,
      );
      if (missing) {
        return _withRefunds(booking, statusCode: 'expired');
      }
      final waiting = booking.shares.any(
        (share) => share.status == ShareStatus.pendingConfirmation,
      );
      return booking.copyWith(
        statusCode: waiting ? 'awaiting_confirmation' : 'confirmed',
      );
    }
    final lastCall = booking.startsAt.subtract(const Duration(hours: 1));
    if (booking.isAwaitingConfirmation && !moment.isBefore(lastCall)) {
      return _withRefunds(booking, statusCode: 'expired');
    }
    return booking;
  }

  /// What a change to one share does to its booking: paid in full is
  /// confirmed at once, and a booking waiting on the admin falls through
  /// the moment one of its transfers is not found.
  Booking _settle(Booking booking) {
    final allPaid =
        booking.shares.isNotEmpty &&
        booking.shares.every((share) => share.isPaid);
    if ((booking.isCollectingShares || booking.isAwaitingConfirmation) &&
        allPaid) {
      return booking.copyWith(statusCode: 'confirmed');
    }
    if (booking.isAwaitingConfirmation &&
        booking.shares.any((share) => share.status == ShareStatus.notFound)) {
      return _withRefunds(booking, statusCode: 'expired');
    }
    return booking;
  }

  BookingShare? _shareById(String shareId) {
    for (final booking in bookings) {
      for (final share in booking.shares) {
        if (share.id == shareId) {
          return share;
        }
      }
    }
    return null;
  }

  /// Changes one share wherever it is, settles its booking, and answers
  /// with the booking as it now stands.
  Booking _updateShare(
    String shareId,
    BookingShare Function(BookingShare share) change,
  ) {
    final booking = bookings.firstWhere(
      (item) => item.shares.any((share) => share.id == shareId),
    );
    final updated = _settle(
      booking.copyWith(
        shares: [
          for (final share in booking.shares)
            share.id == shareId ? change(share) : share,
        ],
      ),
    );
    _replaceBooking(updated);
    return updated;
  }

  BookingShare _takeOpenShare(String bookingId) {
    final booking = bookingById(bookingId);
    if (booking == null) {
      throw _refusal('booking not found', 404);
    }
    if (booking.myShare != null) {
      throw _refusal('already in booking', 409);
    }
    if (!bookings.any((item) => item.id == bookingId)) {
      // Taking a place makes a friend's booking the reader's own.
      _replaceBooking(booking);
    }
    final open = booking.shares
        .where((share) => share.isOpen && share.id != null)
        .firstOrNull;
    if (open == null) {
      throw _refusal('no open shares', 409);
    }
    final updated = _updateShare(
      open.id!,
      (share) => BookingShare(
        id: share.id,
        userId: userId ?? 'me',
        name: 'Вы',
        initial: 'В',
        status: ShareStatus.unpaid,
        amount: share.amount,
        code: share.code,
        isCurrentUser: true,
      ),
    );
    final mine = updated.copyWith(myShareId: open.id);
    _replaceBooking(mine);
    return mine.myShare!;
  }

  void _releaseMyShare(String bookingId) {
    final booking = bookingById(bookingId);
    final share = booking?.myShare;
    if (booking == null || share == null || share.id == null) {
      return;
    }
    if (share.status.holdsMoney) {
      throw _refusal('share is paid, cancel instead', 409);
    }
    // The first share is the organiser's, and an organiser who wants out
    // cancels the booking: walking away would leave the others paying.
    if (booking.shares.first.id == share.id) {
      throw _refusal('organizer cancels the booking instead', 409);
    }
    final updated = _updateShare(
      share.id!,
      (item) => BookingShare(
        id: item.id,
        name: '',
        initial: '',
        status: ShareStatus.open,
        amount: item.amount,
        code: item.code,
      ),
    );
    _replaceBooking(updated.copyWith(clearMyShare: true));
  }

  void _refuseAfterDeadline(Booking booking) {
    if (!_now.isBefore(booking.deadline)) {
      throw _refusal('deadline passed', 409);
    }
  }

  /// The fixtures refuse in the server's own words, so the screens put both
  /// into the same sentences.
  ApiException _refusal(String message, int statusCode) {
    return ApiException(
      kind: ApiExceptionKind.http,
      message: message,
      statusCode: statusCode,
    );
  }

  Booking _storeBooking(ApiJsonObject row) {
    final booking = _bookingFromJson(
      row,
      venueCatalog: venues,
      currentUserId: userId,
    );
    _replaceBooking(booking);
    return booking;
  }

  /// Puts the booking in the list, and the reader's share of it into the
  /// game it carries, so the two screens never disagree.
  void _replaceBooking(Booking booking) {
    _linkedBookings.remove(booking.id);
    final known = bookings.any((item) => item.id == booking.id);
    bookings = known
        ? [
            for (final item in bookings)
              if (item.id == booking.id) booking else item,
          ]
        : [booking, ...bookings];
    _syncGame(booking);
    notifyListeners();
  }

  void _syncGame(Booking booking) {
    final gameId = booking.gameId;
    if (gameId == null) {
      return;
    }
    games = [
      for (final game in games)
        if (game.id == gameId) game.withMyShare(booking.myShare) else game,
    ];
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
      // The demo opens already signed in, the way a returning reader's
      // phone does: whoever is shown the demo is shown the app, not the
      // phone field. Signing out still leads back to it.
      if (isDemo) {
        isSignedIn = true;
        notifyListeners();
        return true;
      }
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
      applyDeadlines();
      notifyListeners();
      return;
    }
    await _loadRemoteState(api);
    notifyListeners();
  }

  void logout() {
    cancelPhoneVerification();
    cancelEmailVerification();
    _api?.clearTokens();
    phone = '';
    email = '';
    userId = null;
    userName = null;
    isSignedIn = false;
    isPaymentAdmin = isDemo;
    paymentInfo = null;
    _linkedBookings.clear();
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
      if (error.statusCode == 422 &&
          error.uri?.path.contains('/auth/email/') == true) {
        return error.uri?.path.endsWith('/verify') == true
            ? AppErrorKind.invalidEmailCode
            : AppErrorKind.badEmail;
      }
      if (message.contains('email')) {
        if (message.contains('delivery')) return AppErrorKind.emailUnavailable;
        if (message.contains('attempts exceeded')) {
          return AppErrorKind.emailAttemptsExceeded;
        }
        if (message.contains('challenge')) {
          return AppErrorKind.emailChallengeExpired;
        }
        if (message.contains('code is invalid')) {
          return AppErrorKind.invalidEmailCode;
        }
        if (error.statusCode == 429) return AppErrorKind.emailTooManyRequests;
        return AppErrorKind.badEmail;
      }
      if (message.contains('slot is unavailable') ||
          message.contains('slot is locked')) {
        return AppErrorKind.slotTaken;
      }
      if (message.contains('game is full') ||
          message.contains('no open shares')) {
        return AppErrorKind.gameFull;
      }
      if (message.contains('share is paid')) {
        return AppErrorKind.sharePaid;
      }
      if (message.contains('deadline passed')) {
        return AppErrorKind.deadlinePassed;
      }
      if (message.contains('only organizer can cancel booking')) {
        return AppErrorKind.cancelNotOrganizer;
      }
      if (message.contains('phone')) {
        return AppErrorKind.badPhone;
      }
      if (message.contains('challenge has expired') ||
          message.contains('challenge is invalid')) {
        return AppErrorKind.challengeExpired;
      }
      if (error.statusCode == 429) {
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
    cancelPhoneVerification();
    cancelEmailVerification();
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
