import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);
  final tomorrow = DateTime(2026, 5, 25);

  AppController controller() {
    final app = AppController(now: now);
    addTearDown(app.dispose);
    return app;
  }

  test(
    'asking to join a game «по одобрению» is a request, not a seat',
    () async {
      final app = controller();
      final open = app.games.first;
      app.games = [
        open.copyWith(type: GameType.approval),
        ...app.games.skip(1),
      ];
      final before = app.games.first.players.length;

      await app.joinGame(app.games.first);

      final game = app.games.first;
      expect(game.readerRequested, isTrue);
      expect(game.readerPlays, isFalse);
      expect(game.players.length, before);
      expect(game.myShare, isNull);
    },
  );

  test('the organiser lets a request in, or turns it down', () async {
    final app = controller();
    final game = await app.createGame(
      sportId: 'football',
      venue: MockData.venues.first,
      date: tomorrow,
      startHour: 20,
      durationMinutes: 60,
      capacity: 4,
      type: GameType.approval,
      genderFilter: GenderFilter.any,
    );
    const ivan = Participant(
      id: 'ivan',
      name: 'Иван',
      initial: 'И',
      rating: 0,
      status: 'pending',
    );
    const olga = Participant(
      id: 'olga',
      name: 'Ольга',
      initial: 'О',
      rating: 0,
      status: 'pending',
    );
    app.games = [
      for (final item in app.games)
        item.id == game.id
            ? item.copyWith(participants: [...item.participants, ivan, olga])
            : item,
    ];
    Game current() => app.games.firstWhere((item) => item.id == game.id);
    expect(current().requests, hasLength(2));

    await app.approveParticipant(current(), ivan);
    await app.rejectParticipant(current(), olga);

    expect(current().requests, isEmpty);
    expect(current().players.any((p) => p.sameAs(ivan)), isTrue);
    expect(current().participants.any((p) => p.sameAs(olga)), isFalse);
  });
}
