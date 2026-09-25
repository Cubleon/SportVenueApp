import 'package:flutter/material.dart';

import '../models/sport_venue_models.dart';

class MockData {
  const MockData._();

  static const sports = <Sport>[
    Sport(id: 'football', name: 'футбол', icon: '⚽', color: Color(0xFF00C853)),
    Sport(id: 'hockey', name: 'хоккей', icon: '🏒', color: Color(0xFF40C4FF)),
    Sport(
      id: 'basketball',
      name: 'баскетбол',
      icon: '🏀',
      color: Color(0xFFFF9100),
    ),
    Sport(
      id: 'volleyball',
      name: 'волейбол',
      icon: '🏐',
      color: Color(0xFFFFD740),
    ),
    Sport(id: 'tennis', name: 'теннис', icon: '🎾', color: Color(0xFF64DD17)),
    Sport(id: 'padel', name: 'падел', icon: '🎾', color: Color(0xFF2979FF)),
  ];

  static const venues = <Venue>[
    Venue(
      id: 'luzhniki',
      name: 'футбольный центр лужники',
      address: 'ул. Лужники, 24',
      sportIds: ['football', 'basketball'],
      pricePerHour: 1600,
      capacityMin: 2,
      capacityMax: 10,
      rating: 4.8,
      distanceKm: 3.2,
      latitude: 55.7158,
      longitude: 37.5537,
      description: 'крытые поля, душевые и прокат инвентаря',
      gradient: [Color(0xFF0D3A1C), Color(0xFF2D7A3E)],
      reviewCount: 128,
      amenities: ['крытая', 'душевые', 'прокат'],
    ),
    Venue(
      id: 'taganka',
      name: 'академия спорта',
      address: 'ул. Таганская, 12',
      sportIds: ['tennis', 'padel', 'volleyball'],
      pricePerHour: 1400,
      capacityMin: 2,
      capacityMax: 6,
      rating: 4.7,
      distanceKm: 5.7,
      latitude: 55.7417,
      longitude: 37.6558,
      description: 'корты с вечерними слотами и кафе',
      gradient: [Color(0xFF1A3860), Color(0xFF2979FF)],
      reviewCount: 64,
      amenities: ['крытая', 'кафе', 'вечерние слоты'],
    ),
    Venue(
      id: 'north',
      name: 'арена север',
      address: 'Дмитровское ш., 71',
      sportIds: ['hockey', 'football'],
      pricePerHour: 2200,
      capacityMin: 2,
      capacityMax: 12,
      rating: 4.6,
      distanceKm: 8.4,
      latitude: 55.8587,
      longitude: 37.5574,
      description: 'ледовая площадка и мини-футбол',
      gradient: [Color(0xFF0D2540), Color(0xFF40C4FF)],
      reviewCount: 31,
      amenities: ['лёд', 'парковка', 'раздевалки'],
    ),
    Venue(
      id: 'river',
      name: 'центр у реки',
      address: 'Пресненская наб., 10',
      sportIds: ['padel', 'tennis'],
      pricePerHour: 1800,
      capacityMin: 2,
      capacityMax: 4,
      rating: 4.9,
      distanceKm: 2.4,
      latitude: 55.7488,
      longitude: 37.5367,
      description: 'панорамные корты и быстрый вход',
      gradient: [Color(0xFF0D2A3A), Color(0xFF1A6A3A)],
      reviewCount: 92,
      amenities: ['открытый', 'душевые', 'парковка'],
    ),
  ];

  static List<TimeSlot> timeSlots() {
    return const [
      TimeSlot(hour: 8, isAvailable: true),
      TimeSlot(hour: 9, isAvailable: true),
      TimeSlot(hour: 10, isAvailable: false),
      TimeSlot(hour: 11, isAvailable: true),
      TimeSlot(hour: 12, isAvailable: true),
      TimeSlot(hour: 13, isAvailable: false),
      TimeSlot(hour: 18, isAvailable: false),
      TimeSlot(hour: 19, isAvailable: true),
      TimeSlot(hour: 20, isAvailable: true),
      TimeSlot(hour: 21, isAvailable: true),
      TimeSlot(hour: 22, isAvailable: false),
      TimeSlot(hour: 23, isAvailable: true),
    ];
  }

  static List<Game> games(DateTime now) {
    final base = DateTime(now.year, now.month, now.day);
    const organizer = Participant(
      id: 'orlov',
      name: 'Максим Орлов',
      initial: 'М',
      rating: 4.8,
    );

    return [
      Game(
        id: 'game-1',
        sportId: 'football',
        venue: venues[0],
        date: base.add(const Duration(days: 1)),
        startHour: 19,
        durationMinutes: 120,
        capacity: 6,
        pricePerPerson: 600,
        level: 'любой уровень',
        format: '6×6',
        type: GameType.approval,
        genderFilter: GenderFilter.any,
        organizer: organizer,
        participants: const [
          Participant(
            id: 'fedorov',
            name: 'Даниил Фёдоров',
            initial: 'Д',
            rating: 4.2,
          ),
          Participant(
            id: 'parshutin',
            name: 'Антон Паршутин',
            initial: 'А',
            rating: 3.9,
          ),
          Participant(
            id: 'sergeev',
            name: 'Илья Сергеев',
            initial: 'И',
            rating: 4.4,
          ),
        ],
      ),
      Game(
        id: 'game-2',
        sportId: 'padel',
        venue: venues[1],
        date: base.add(const Duration(days: 2)),
        startHour: 20,
        durationMinutes: 90,
        capacity: 4,
        pricePerPerson: 750,
        level: 'с опытом',
        format: 'коньки свои',
        type: GameType.open,
        genderFilter: GenderFilter.any,
        organizer: const Participant(
          id: 'melnik',
          name: 'Саша Мельник',
          initial: 'С',
          rating: 4.6,
        ),
        participants: const [
          Participant(
            id: 'mironov',
            name: 'Олег Миронов',
            initial: 'О',
            rating: 4.1,
          ),
          Participant(
            id: 'volkova',
            name: 'Ника Волкова',
            initial: 'Н',
            rating: 4.5,
          ),
        ],
      ),
      Game(
        id: 'game-3',
        sportId: 'tennis',
        venue: venues[3],
        date: base.add(const Duration(days: 3)),
        startHour: 18,
        durationMinutes: 60,
        capacity: 2,
        pricePerPerson: 900,
        level: 'любой уровень',
        format: 'ракетки в прокате',
        type: GameType.open,
        genderFilter: GenderFilter.any,
        organizer: const Participant(
          name: 'Мария Ким',
          initial: 'М',
          rating: 4.9,
        ),
        participants: const [
          Participant(name: 'Мария Ким', initial: 'М', rating: 4.9),
        ],
      ),
    ];
  }

  static Booking initialBooking(DateTime now) {
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return Booking(
      id: 'booking-demo',
      draft: BookingDraft(
        venue: venues[1],
        date: date,
        durationMinutes: 90,
        startHour: 20,
        players: 4,
        mode: PaymentMode.split,
      ),
      statusCode: 'collecting_shares',
      createdAt: now,
      // Two of the four have paid, so the demo can show what a half-collected
      // booking looks like rather than only that one exists.
      shares: const [
        BookingShare(
          id: 'me',
          name: 'Вы',
          initial: 'В',
          isPaid: true,
          isCurrentUser: true,
        ),
        BookingShare(
          id: 'orlov',
          name: 'Максим Орлов',
          initial: 'М',
          isPaid: true,
        ),
        BookingShare(
          id: 'fedorov',
          name: 'Даниил Фёдоров',
          initial: 'Д',
          isPaid: false,
        ),
        BookingShare(
          id: 'volkova',
          name: 'Ника Волкова',
          initial: 'Н',
          isPaid: false,
        ),
      ],
    );
  }
}
