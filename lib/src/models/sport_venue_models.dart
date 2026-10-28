import 'dart:math' as math;

import 'package:flutter/material.dart';

enum GameType { open, approval, closed }

enum GenderFilter { any, men, women }

enum PaymentMode { full, split }

/// How the places in a game are paid for.
///
/// A paid game always stands on a booking, and its places are that
/// booking's shares: joining is taking a share, and the booking's deadline
/// is the game's. A free game, on an open court, has no booking at all.
enum GamePayment {
  /// Every player pays their own share.
  shares,

  /// The organiser pays for the whole slot; joining costs nothing.
  organizer,

  /// An open court: no booking, no money.
  free;

  static GamePayment fromCode(Object? code) => switch (code) {
    'organizer' => GamePayment.organizer,
    'free' => GamePayment.free,
    _ => GamePayment.shares,
  };
}

/// Where one share of a booking stands.
///
/// The player's button only puts a share in the queue; it becomes paid when
/// the payments admin has found the transfer in the bank, and later when
/// the bank says so itself. The codes are the server's.
enum ShareStatus {
  /// A place nobody has taken yet.
  open('open'),

  /// Taken, and no money yet.
  unpaid('unpaid'),

  /// The player says they have paid; the admin has not checked yet.
  pendingConfirmation('pending_confirmation'),

  /// The admin found the transfer.
  paid('paid'),

  /// The admin looked and did not find it.
  notFound('not_found'),

  /// The booking fell through and this share had money, or a claim of it.
  refundDue('refund_due'),

  /// The money went back.
  refunded('refunded');

  const ShareStatus(this.code);

  final String code;

  /// Money has arrived, or may have: the shares a cancellation must refund.
  bool get holdsMoney => this == paid || this == pendingConfirmation;

  /// Reads the server's word. A server that predates statuses sends only
  /// `is_paid`; a word this build does not know is read as not paid, which
  /// is the safer mistake.
  static ShareStatus fromJson(Map<String, dynamic> json) {
    final code = (json['status'] as String? ?? '').toLowerCase();
    for (final status in values) {
      if (status.code == code) {
        return status;
      }
    }
    return json['is_paid'] == true ? paid : unpaid;
  }
}

/// The amounts a booking's total splits into, in whole roubles, adding up
/// to the total exactly: every share gets the floor, and the roubles left
/// over go one each to the first shares. 1700 over three is 567, 567, 566.
List<int> splitIntoShares(int total, int count) {
  if (count <= 0) {
    return const [];
  }
  final base = total ~/ count;
  final rest = total - base * count;
  return [for (var i = 0; i < count; i++) base + (i < rest ? 1 : 0)];
}

/// Where the money for a share goes, as the server tells it.
///
/// It lives on the server rather than in the build, so a new bank or a new
/// QR does not wait for a release in the stores.
class PaymentInfo {
  const PaymentInfo({
    required this.method,
    required this.sbpLink,
    required this.qrPayload,
    required this.recipientName,
    required this.bankName,
    this.commentHint,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      method: _requiredString(json, 'method'),
      sbpLink: _requiredString(json, 'sbp_link'),
      qrPayload: _requiredString(json, 'qr_payload'),
      recipientName: _requiredString(json, 'recipient_name'),
      bankName: _requiredString(json, 'bank_name'),
      commentHint: _optionalString(json, 'comment_hint'),
    );
  }

  /// `sbp_static` for real money; `test` while there is no account yet, so
  /// the screen can say the payment is not real.
  final String method;
  final String sbpLink;
  final String qrPayload;
  final String recipientName;
  final String bankName;
  final String? commentHint;

  bool get isTest => method == 'test';
}

/// One share waiting for the payments admin: everything needed to find the
/// transfer in a bank statement without opening the booking.
class PaymentQueueItem {
  const PaymentQueueItem({
    required this.shareId,
    required this.bookingId,
    required this.code,
    required this.amount,
    required this.status,
    required this.userName,
    required this.venueName,
    required this.startsAt,
    required this.deadlineAt,
    this.payerName,
    this.phone,
    this.claimedAt,
    this.note,
  });

  factory PaymentQueueItem.fromJson(Map<String, dynamic> json) {
    final user = _requiredMap(json, 'user');
    final booking = _requiredMap(json, 'booking');
    final venue = _requiredMap(json, 'venue');
    return PaymentQueueItem(
      shareId: _requiredString(json, 'share_id'),
      bookingId: _requiredString(booking, 'id'),
      code: _requiredString(json, 'code'),
      amount: _requiredInt(json, 'amount'),
      status: ShareStatus.fromJson(json),
      userName: _optionalString(user, 'name') ?? 'Игрок',
      phone: _optionalString(user, 'phone'),
      venueName: _requiredString(venue, 'name'),
      startsAt: _wallClock(_requiredDateTime(json, 'starts_at')),
      deadlineAt: _wallClock(_requiredDateTime(booking, 'deadline_at')),
      payerName: _optionalString(json, 'payer_name'),
      claimedAt: _optionalDateTime(json, 'claimed_at'),
      note: _optionalString(json, 'note'),
    );
  }

  final String shareId;
  final String bookingId;
  final String code;
  final int amount;
  final ShareStatus status;
  final String userName;
  final String? phone;

  /// The sender's name as the player says the bank shows it.
  final String? payerName;
  final String venueName;
  final DateTime startsAt;
  final DateTime deadlineAt;
  final DateTime? claimedAt;
  final String? note;
}

class Sport {
  const Sport({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String icon;
  final Color color;

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      icon: _requiredString(json, 'icon'),
      color: _colorFromHex(_requiredString(json, 'color')),
    );
  }
}

/// Which of a club's sports to draw for it.
///
/// The home read `venue.sportIds.first` and the search walked the sport
/// catalogue in its own order, so «Арена север» was a hockey rink on one
/// screen and a football pitch on the other — the same club, and no way for
/// a reader to know it was the same club. Under a filter the filtered sport
/// wins, because a club listed under hockey drawing a football pitch is
/// just as wrong; with no filter, the club's own first sport decides, and
/// it decides everywhere.
String primarySportId(Venue venue, {String? filterId}) {
  if (filterId != null && venue.sportIds.contains(filterId)) {
    return filterId;
  }
  return venue.sportIds.first;
}

class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.sportIds,
    required this.pricePerHour,
    required this.capacityMin,
    required this.capacityMax,
    required this.rating,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.gradient,
    this.reviewCount,
    this.amenities = const [],
  });

  final String id;
  final String name;
  final String address;
  final List<String> sportIds;
  final int pricePerHour;
  final int capacityMin;
  final int capacityMax;
  final double rating;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final String description;
  final List<Color> gradient;

  /// How many ratings the club's score is made of. Null when the server does
  /// not say — a rating with no count behind it is shown bare rather than
  /// with a number nobody counted.
  final int? reviewCount;

  /// What the club has: indoors, showers, hire, parking. Short words, in the
  /// server's own wording, and empty when it says nothing.
  final List<String> amenities;

  factory Venue.fromJson(
    Map<String, dynamic> json, {
    Color accent = const Color(0xFF00A7C4),
  }) {
    final latitude = _requiredDouble(json, 'geo_lat');
    final longitude = _requiredDouble(json, 'geo_lng');
    return Venue(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      address: _requiredString(json, 'address'),
      sportIds: _stringList(json, 'sport_ids'),
      pricePerHour: _requiredInt(json, 'base_price_per_hour'),
      capacityMin: _requiredInt(json, 'capacity_min'),
      capacityMax: _requiredInt(json, 'capacity_max'),
      rating: _requiredDouble(json, 'rating'),
      distanceKm: _distanceFromMoscow(latitude, longitude),
      latitude: latitude,
      longitude: longitude,
      description: _requiredString(json, 'description'),
      gradient: [
        Color.alphaBlend(Colors.black.withValues(alpha: 0.58), accent),
        Color.alphaBlend(Colors.white.withValues(alpha: 0.08), accent),
      ],
      reviewCount: _optionalInt(json, 'review_count'),
      amenities: _optionalStringList(json, 'amenities'),
    );
  }
}

class TimeSlot {
  const TimeSlot({
    required this.hour,
    required this.isAvailable,
    this.startsAt,
    this.endsAt,
    this.price,
    this.status,
  });

  final int hour;
  final bool isAvailable;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? price;
  final String? status;

  String get label => '${hour.toString().padLeft(2, '0')}:00';

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    final startsAt = _requiredDateTime(json, 'starts_at');
    return TimeSlot(
      // The backend currently publishes Moscow booking hours as UTC wall-clock
      // values. Keep the API hour stable instead of shifting it to the device
      // timezone.
      hour: startsAt.toUtc().hour,
      isAvailable: _requiredBool(json, 'is_available'),
      startsAt: startsAt,
      endsAt: _requiredDateTime(json, 'ends_at'),
      price: _requiredInt(json, 'price'),
      status: _requiredString(json, 'status'),
    );
  }
}

class BookingDraft {
  const BookingDraft({
    required this.venue,
    required this.date,
    required this.durationMinutes,
    required this.startHour,
    required this.players,
    required this.mode,
    this.quotedTotalPrice,
    this.quotedSharePrice,
  });

  final Venue venue;
  final DateTime date;
  final int durationMinutes;
  final int startHour;
  final int players;
  final PaymentMode mode;
  final int? quotedTotalPrice;
  final int? quotedSharePrice;

  int get totalPrice =>
      quotedTotalPrice ?? (venue.pricePerHour * durationMinutes / 60).round();

  int get sharePrice => quotedSharePrice ?? (totalPrice / players).ceil();

  String get timeRange {
    final end = startHour + durationMinutes ~/ 60;
    final half = durationMinutes % 60 == 30;
    final endLabel = half
        ? '${end.toString().padLeft(2, '0')}:30'
        : '${end.toString().padLeft(2, '0')}:00';
    return '${startHour.toString().padLeft(2, '0')}:00 - $endLabel';
  }

  BookingDraft copyWith({
    DateTime? date,
    int? durationMinutes,
    int? startHour,
    int? players,
    PaymentMode? mode,
    int? quotedTotalPrice,
    int? quotedSharePrice,
  }) {
    return BookingDraft(
      venue: venue,
      date: date ?? this.date,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startHour: startHour ?? this.startHour,
      players: players ?? this.players,
      mode: mode ?? this.mode,
      quotedTotalPrice: quotedTotalPrice ?? this.quotedTotalPrice,
      quotedSharePrice: quotedSharePrice ?? this.quotedSharePrice,
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.draft,
    required this.createdAt,
    this.statusCode = 'confirmed',
    this.organizerId,
    this.shares = const [],
    this.deadlineAt,
    this.gameId,
    this.myShareId,
  });

  /// When the shares must all be paid: two hours before the start, unless
  /// the server says otherwise.
  final DateTime? deadlineAt;

  /// The game this booking carries, when it carries one.
  final String? gameId;

  /// The share that belongs to the reader, if any.
  final String? myShareId;

  DateTime get deadline =>
      deadlineAt ?? startsAt.subtract(const Duration(hours: 2));

  BookingShare? get myShare {
    final id = myShareId;
    for (final share in shares) {
      if (share.isCurrentUser && (id == null || share.id == id)) {
        return share;
      }
    }
    return null;
  }

  /// Shares with no owner yet: places still free to take.
  int get openShares => shares.where((share) => share.isOpen).length;

  /// Shares someone else still has to pay for: free places included, the
  /// reader's own left out. This is what "позовите игроков" is about.
  int get othersUnpaid =>
      shares.where((share) => !share.isCurrentUser && !share.isPaid).length;

  final String id;
  final BookingDraft draft;
  final DateTime createdAt;

  /// The server's own word for the state, put into the reader's language
  /// where it is shown. It used to be stored here already translated, which
  /// is how a data class ends up speaking one language for ever.
  final String statusCode;
  final String? organizerId;

  /// Who owes what, when the booking is being split. Empty when the server
  /// sent none, which is not the same as nobody having paid — so the counts
  /// below only mean anything when this is not empty.
  final List<BookingShare> shares;

  int get paidShares => shares.where((share) => share.isPaid).length;

  bool get isCollectingShares => statusCode == 'collecting_shares';

  DateTime get startsAt => DateTime(
    draft.date.year,
    draft.date.month,
    draft.date.day,
    draft.startHour,
  );

  /// Past the deadline with every share claimed, while the admin is still
  /// checking some of the transfers.
  bool get isAwaitingConfirmation => statusCode == 'awaiting_confirmation';

  bool get isActive => switch (statusCode) {
    'collecting_shares' || 'awaiting_confirmation' || 'confirmed' => true,
    _ => false,
  };

  Booking copyWith({
    String? statusCode,
    List<BookingShare>? shares,
    String? gameId,
    String? myShareId,
    bool clearMyShare = false,
  }) {
    return Booking(
      id: id,
      draft: draft,
      createdAt: createdAt,
      statusCode: statusCode ?? this.statusCode,
      organizerId: organizerId,
      shares: shares ?? this.shares,
      deadlineAt: deadlineAt,
      gameId: gameId ?? this.gameId,
      myShareId: clearMyShare ? null : myShareId ?? this.myShareId,
    );
  }

  factory Booking.fromJson(
    Map<String, dynamic> json, {
    required Venue venue,
    String? currentUserId,
  }) {
    final slot = _requiredMap(json, 'time_slot');
    final startsAt = _requiredDateTime(slot, 'starts_at').toUtc();
    final players = _requiredInt(json, 'players_count');
    final status = _requiredString(json, 'status');
    final paymentMode = json['payment_mode'];
    return Booking(
      id: _requiredString(json, 'id'),
      draft: BookingDraft(
        venue: venue,
        date: DateTime(startsAt.year, startsAt.month, startsAt.day),
        durationMinutes: _requiredInt(slot, 'duration_minutes'),
        startHour: startsAt.hour,
        players: players,
        mode: paymentMode is String
            ? PaymentMode.values.byName(paymentMode)
            : status == 'confirmed'
            ? PaymentMode.full
            : PaymentMode.split,
        quotedTotalPrice: _requiredInt(json, 'total_price'),
        quotedSharePrice: _requiredInt(json, 'share_price'),
      ),
      createdAt: _requiredDateTime(json, 'created_at'),
      statusCode: status,
      organizerId: _requiredString(json, 'organizer_id'),
      shares: switch (json['shares']) {
        final List<dynamic> rows =>
          rows
              .whereType<Map<String, dynamic>>()
              .map(
                (row) =>
                    BookingShare.fromJson(row, currentUserId: currentUserId),
              )
              .toList(),
        _ => const [],
      },
      deadlineAt: switch (_optionalDateTime(json, 'deadline_at')) {
        final DateTime at => _wallClock(at),
        null => null,
      },
      gameId: _optionalString(json, 'game_id'),
      myShareId: _optionalString(json, 'my_share_id'),
    );
  }
}

class Participant {
  const Participant({
    required this.name,
    required this.initial,
    required this.rating,
    this.id,
    this.status = 'joined',
    this.isCurrentUser = false,
  });

  /// The player, as the server knows them. Null for a fixture, and for a
  /// server that did not send one — which is why anything matching players
  /// across games falls back to the name.
  final String? id;
  final String name;
  final String initial;

  /// Zero when nobody has rated them, or when the server did not say.
  final double rating;
  final String status;
  final bool isCurrentUser;

  bool get hasRating => rating > 0;

  /// Whether this is the same player as [other], by id where there is one.
  bool sameAs(Participant other) {
    if (id != null && other.id != null) {
      return id == other.id;
    }
    return name == other.name;
  }

  factory Participant.fromJson(
    Map<String, dynamic> json, {
    required String? currentUserId,
  }) {
    final name = json['name'] as String?;
    return Participant(
      id: json['user_id'] as String?,
      name: name == null || name.trim().isEmpty ? 'Игрок' : name,
      initial: _requiredString(json, 'initial'),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      status: _requiredString(json, 'status'),
      isCurrentUser: json['user_id'] == currentUserId,
    );
  }
}

/// One person's part of a split booking.
///
/// The server has been sending these all along and the app was dropping
/// them, so "сбор долей" could say that money was being collected but never
/// how much of it had arrived.
class BookingShare {
  const BookingShare({
    required this.name,
    required this.initial,
    required this.status,
    this.id,
    this.userId,
    this.amount,
    this.code,
    this.claimedAt,
    this.confirmedAt,
    this.refundedAt,
    this.note,
    this.isCurrentUser = false,
  });

  factory BookingShare.fromJson(
    Map<String, dynamic> json, {
    required String? currentUserId,
  }) {
    final userId = json['user_id'] as String?;
    final name = json['name'] as String?;
    final initial = json['initial'] as String?;
    final status = ShareStatus.fromJson(json);
    // A free place has nobody's name on it; the screen says what it is.
    final resolved = name == null || name.trim().isEmpty
        ? (status == ShareStatus.open ? '' : 'Игрок')
        : name;
    return BookingShare(
      // Servers that predate share ids keyed the share by its player.
      id: json['id'] as String? ?? userId,
      userId: userId,
      name: resolved,
      initial: initial != null && initial.isNotEmpty
          ? initial
          : resolved.isEmpty
          ? ''
          : resolved.characters.first.toUpperCase(),
      status: status,
      amount: _optionalInt(json, 'amount'),
      code: _optionalString(json, 'code'),
      claimedAt: _optionalDateTime(json, 'claimed_at'),
      confirmedAt: _optionalDateTime(json, 'confirmed_at'),
      refundedAt: _optionalDateTime(json, 'refunded_at'),
      note: _optionalString(json, 'note'),
      // A free place has no owner, and no owner is not the reader even
      // when the reader's id is unknown too.
      isCurrentUser: userId != null && userId == currentUserId,
    );
  }

  final String? id;
  final String? userId;
  final String name;
  final String initial;
  final ShareStatus status;

  /// In whole roubles. Null from a server that does not split the total.
  final int? amount;

  /// What the player writes in the transfer's comment, so the admin can
  /// find it in the statement. Only its owner, the organiser and the admin
  /// are sent it.
  final String? code;
  final DateTime? claimedAt;
  final DateTime? confirmedAt;
  final DateTime? refundedAt;

  /// The admin's word on a share they could not find, or on a refund.
  final String? note;
  final bool isCurrentUser;

  bool get isPaid => status == ShareStatus.paid;
  bool get isOpen => status == ShareStatus.open;

  BookingShare copyWith({
    ShareStatus? status,
    String? userId,
    String? name,
    String? initial,
    DateTime? claimedAt,
    DateTime? confirmedAt,
    DateTime? refundedAt,
    String? note,
    bool? isCurrentUser,
  }) {
    return BookingShare(
      id: id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      initial: initial ?? this.initial,
      status: status ?? this.status,
      amount: amount,
      code: code,
      claimedAt: claimedAt ?? this.claimedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      refundedAt: refundedAt ?? this.refundedAt,
      note: note ?? this.note,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}

class Game {
  const Game({
    required this.id,
    required this.sportId,
    required this.venue,
    required this.date,
    required this.startHour,
    required this.durationMinutes,
    required this.capacity,
    required this.pricePerPerson,
    required this.type,
    required this.genderFilter,
    required this.organizer,
    required this.participants,
    this.level,
    this.format,
    this.payment = GamePayment.shares,
    this.bookingId,
    this.myShare,
    this.deadlineAt,
  });

  final String id;
  final String sportId;
  final Venue venue;
  final DateTime date;
  final int startHour;
  final int durationMinutes;
  final int capacity;
  final int pricePerPerson;
  final GameType type;
  final GenderFilter genderFilter;
  final Participant organizer;
  final List<Participant> participants;

  /// Who the game is for — "любой уровень", "с опытом". The organiser's own
  /// words, or null when they said nothing.
  final String? level;

  /// How it is played and what to bring — "6×6", "коньки свои". Also the
  /// organiser's words.
  final String? format;

  /// How its places are paid for.
  final GamePayment payment;

  /// The booking the game stands on. Null for a free game on an open court.
  final String? bookingId;

  /// The reader's share of that booking: what they owe, and where it stands.
  final BookingShare? myShare;

  /// When every share must be paid, or the game is called off.
  final DateTime? deadlineAt;

  DateTime get deadline =>
      deadlineAt ?? startsAt.subtract(const Duration(hours: 2));

  /// The moment play begins, which is what a countdown needs — the date and
  /// the hour are stored apart.
  DateTime get startsAt => DateTime(date.year, date.month, date.day, startHour);

  int get freePlaces => capacity - participants.length;

  bool get isFull => freePlaces <= 0;

  String get timeRange {
    final endHour = startHour + durationMinutes ~/ 60;
    final half = durationMinutes % 60 == 30;
    final endLabel = half
        ? '${endHour.toString().padLeft(2, '0')}:30'
        : '${endHour.toString().padLeft(2, '0')}:00';
    return '${startHour.toString().padLeft(2, '0')}:00 - $endLabel';
  }

  /// Everything but [myShare], which [withMyShare] sets: it has to be
  /// clearable, and a null here means "keep".
  Game copyWith({
    List<Participant>? participants,
    GameType? type,
    GenderFilter? genderFilter,
    String? bookingId,
  }) {
    return Game(
      id: id,
      sportId: sportId,
      venue: venue,
      date: date,
      startHour: startHour,
      durationMinutes: durationMinutes,
      capacity: capacity,
      pricePerPerson: pricePerPerson,
      type: type ?? this.type,
      genderFilter: genderFilter ?? this.genderFilter,
      organizer: organizer,
      participants: participants ?? this.participants,
      // These were left behind before, so a game lost its level and format
      // the first time anyone joined it.
      level: level,
      format: format,
      payment: payment,
      bookingId: bookingId ?? this.bookingId,
      myShare: myShare,
      deadlineAt: deadlineAt,
    );
  }

  /// The same game with the reader's share replaced, or removed.
  Game withMyShare(BookingShare? share) {
    return Game(
      id: id,
      sportId: sportId,
      venue: venue,
      date: date,
      startHour: startHour,
      durationMinutes: durationMinutes,
      capacity: capacity,
      pricePerPerson: pricePerPerson,
      type: type,
      genderFilter: genderFilter,
      organizer: organizer,
      participants: participants,
      level: level,
      format: format,
      payment: payment,
      bookingId: bookingId,
      myShare: share,
      deadlineAt: deadlineAt,
    );
  }

  factory Game.fromJson(
    Map<String, dynamic> json, {
    required Venue venue,
    required String? currentUserId,
  }) {
    final slot = _requiredMap(json, 'time_slot');
    final startsAt = _requiredDateTime(slot, 'starts_at').toUtc();
    final participantMaps = _mapList(json, 'participants');
    final participants = participantMaps
        .map((item) => Participant.fromJson(item, currentUserId: currentUserId))
        .toList();
    final organizerId = _requiredString(json, 'organizer_id');
    final organizerIndex = participantMaps.indexWhere(
      (item) => item['user_id'] == organizerId,
    );
    final organizer = organizerIndex >= 0
        ? participants[organizerIndex]
        : const Participant(name: 'Организатор', initial: 'О', rating: 0);
    return Game(
      id: _requiredString(json, 'id'),
      sportId: _requiredString(json, 'sport_id'),
      venue: venue,
      date: DateTime(startsAt.year, startsAt.month, startsAt.day),
      startHour: startsAt.hour,
      durationMinutes: _requiredInt(slot, 'duration_minutes'),
      capacity: _requiredInt(json, 'capacity'),
      pricePerPerson: _requiredInt(json, 'price_per_person'),
      type: GameType.values.byName(_requiredString(json, 'type')),
      genderFilter: GenderFilter.values.byName(
        _requiredString(json, 'gender_filter'),
      ),
      organizer: organizer,
      participants: participants,
      level: _optionalString(json, 'level'),
      format: _optionalString(json, 'format'),
      payment: GamePayment.fromCode(json['payment']),
      bookingId: _optionalString(json, 'booking_id'),
      myShare: switch (json['my_share']) {
        final Map<String, dynamic> row => BookingShare.fromJson(
          row,
          currentUserId: currentUserId,
        ),
        _ => null,
      },
      deadlineAt: switch (_optionalDateTime(json, 'deadline_at')) {
        final DateTime at => _wallClock(at),
        null => null,
      },
    );
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  throw FormatException('Expected "$key" to be an object.');
}

List<Map<String, dynamic>> _mapList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }
  return value.map((item) {
    if (item is Map<String, dynamic>) {
      return item;
    }
    if (item is Map) {
      return item.cast<String, dynamic>();
    }
    throw FormatException('Expected an object in "$key".');
  }).toList();
}

/// Reads a field the server may not send at all. Absent and empty are the
/// same thing here: both mean "nothing to show", and the screen leaves the
/// line out rather than printing a blank.
String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _optionalStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Expected "$key" to be a string list.');
  }
  return value.cast<String>();
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException('Expected "$key" to be a number.');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected "$key" to be a number.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected "$key" to be a boolean.');
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? DateTime.tryParse(value) : null;
}

/// The server keeps Moscow hours as UTC wall-clock values, and the app reads
/// every start that way (see `TimeSlot.fromJson`). A deadline is read the
/// same way, or it would land three hours off the start it belongs to.
DateTime _wallClock(DateTime value) {
  final utc = value.toUtc();
  return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Expected "$key" to be an ISO-8601 date-time.');
  }
  return parsed;
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null || normalized.length != 6) {
    throw FormatException('Expected a six-digit hex color.');
  }
  return Color(0xFF000000 | parsed);
}

double _distanceFromMoscow(double latitude, double longitude) {
  const centerLatitude = 55.755864;
  const centerLongitude = 37.617698;
  const earthRadiusKm = 6371.0;
  final lat1 = centerLatitude * math.pi / 180;
  final lat2 = latitude * math.pi / 180;
  final deltaLat = (latitude - centerLatitude) * math.pi / 180;
  final deltaLng = (longitude - centerLongitude) * math.pi / 180;
  final a =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
