import 'dart:math' as math;

import 'package:flutter/material.dart';

enum GameType { open, approval, closed }

enum GenderFilter { any, men, women }

enum PaymentMode { full, split }

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
  });

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

  bool get isActive => switch (statusCode) {
    'collecting_shares' || 'confirmed' => true,
    _ => false,
  };

  Booking copyWith({String? statusCode, List<BookingShare>? shares}) {
    return Booking(
      id: id,
      draft: draft,
      createdAt: createdAt,
      statusCode: statusCode ?? this.statusCode,
      organizerId: organizerId,
      shares: shares ?? this.shares,
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
    required this.isPaid,
    this.id,
    this.isCurrentUser = false,
  });

  factory BookingShare.fromJson(
    Map<String, dynamic> json, {
    required String? currentUserId,
  }) {
    final name = json['name'] as String?;
    final status = (json['status'] as String? ?? '').toLowerCase();
    final initial = json['initial'] as String?;
    final resolved = name == null || name.trim().isEmpty ? 'Игрок' : name;
    return BookingShare(
      id: json['user_id'] as String?,
      name: resolved,
      initial: initial == null || initial.isEmpty
          ? resolved.characters.first.toUpperCase()
          : initial,
      // Anything the server does not call paid is treated as not yet paid:
      // saying a share is outstanding when it is not is the safer mistake.
      isPaid: status == 'paid' || json['is_paid'] == true,
      isCurrentUser: json['user_id'] == currentUserId,
    );
  }

  final String? id;
  final String name;
  final String initial;
  final bool isPaid;
  final bool isCurrentUser;
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

  Game copyWith({
    List<Participant>? participants,
    GameType? type,
    GenderFilter? genderFilter,
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
