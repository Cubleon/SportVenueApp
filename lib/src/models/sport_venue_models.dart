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
    required this.status,
    required this.createdAt,
    this.statusCode = 'confirmed',
    this.organizerId,
  });

  final String id;
  final BookingDraft draft;
  final String status;
  final DateTime createdAt;
  final String statusCode;
  final String? organizerId;

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

  Booking copyWith({String? status, String? statusCode}) {
    return Booking(
      id: id,
      draft: draft,
      status: status ?? this.status,
      createdAt: createdAt,
      statusCode: statusCode ?? this.statusCode,
      organizerId: organizerId,
    );
  }

  factory Booking.fromJson(Map<String, dynamic> json, {required Venue venue}) {
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
      status: _bookingStatusLabel(status),
      createdAt: _requiredDateTime(json, 'created_at'),
      statusCode: status,
      organizerId: _requiredString(json, 'organizer_id'),
    );
  }
}

class Participant {
  const Participant({
    required this.name,
    required this.initial,
    required this.rating,
    this.status = 'joined',
    this.isCurrentUser = false,
  });

  final String name;
  final String initial;
  final double rating;
  final String status;
  final bool isCurrentUser;

  factory Participant.fromJson(
    Map<String, dynamic> json, {
    required String? currentUserId,
  }) {
    final name = json['name'] as String?;
    return Participant(
      name: name == null || name.trim().isEmpty ? 'Игрок' : name,
      initial: _requiredString(json, 'initial'),
      rating: 0,
      status: _requiredString(json, 'status'),
      isCurrentUser: json['user_id'] == currentUserId,
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

String _bookingStatusLabel(String status) {
  return switch (status) {
    'collecting_shares' => 'сбор долей',
    'confirmed' => 'подтверждена',
    'cancelled' => 'отменена',
    'expired' => 'истекла',
    _ => status,
  };
}
