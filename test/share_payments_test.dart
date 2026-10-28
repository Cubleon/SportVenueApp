import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';

/// The payment rules the fixtures follow are the ones the server will:
/// these tests are the description of the pilot's API, run.
void main() {
  final now = DateTime(2026, 5, 24, 12);
  final tomorrow = DateTime(2026, 5, 25);

  BookingDraft draft({int players = 4, PaymentMode mode = PaymentMode.split}) {
    return BookingDraft(
      venue: MockData.venues.first,
      date: tomorrow,
      durationMinutes: 60,
      startHour: 20,
      players: players,
      mode: mode,
    );
  }

  AppController controller({bool admin = false}) {
    final value = AppController(now: now);
    addTearDown(value.dispose);
    value.isPaymentAdmin = admin;
    return value;
  }

  /// Gives the open places to other players, as if they had followed the
  /// link, so a booking can be paid in full.
  Booking fillOpenPlaces(AppController app, Booking booking) {
    final filled = booking.copyWith(
      shares: [
        for (final share in booking.shares)
          share.isOpen
              ? BookingShare(
                  id: share.id,
                  userId: 'friend-${share.id}',
                  name: 'Друг',
                  initial: 'Д',
                  status: ShareStatus.unpaid,
                  amount: share.amount,
                  code: share.code,
                )
              : share,
      ],
    );
    app.bookings = [
      for (final item in app.bookings)
        if (item.id == booking.id) filled else item,
    ];
    return filled;
  }

  test('a total splits into whole roubles that add up to it exactly', () {
    expect(splitIntoShares(1700, 3), [567, 567, 566]);
    expect(splitIntoShares(1600, 4), [400, 400, 400, 400]);
    expect(splitIntoShares(1601, 4).reduce((a, b) => a + b), 1601);
    expect(splitIntoShares(100, 0), isEmpty);
  });

  test(
    'a split booking is one share per place, the first the reader\'s',
    () async {
      final app = controller();
      final booking = await app.addBooking(draft(players: 3));

      expect(booking.statusCode, 'collecting_shares');
      expect(booking.shares, hasLength(3));
      expect(booking.myShare, same(booking.shares.first));
      expect(booking.myShare!.status, ShareStatus.unpaid);
      expect(booking.shares.skip(1).every((share) => share.isOpen), isTrue);
      expect(
        booking.shares.map((share) => share.amount).reduce((a, b) => a! + b!),
        booking.draft.totalPrice,
      );
      expect(booking.shares.map((share) => share.code).toSet(), hasLength(3));
      expect(booking.othersUnpaid, 2);
      expect(booking.deadline, DateTime(2026, 5, 25, 18));
    },
  );

  test(
    'a booking paid by the organiser is one share for the whole sum',
    () async {
      final app = controller();
      final booking = await app.addBooking(draft(mode: PaymentMode.full));

      expect(booking.shares, hasLength(1));
      expect(booking.shares.single.amount, booking.draft.totalPrice);
    },
  );

  test(
    '«Я оплатил» queues the share; the admin decides whether it is paid',
    () async {
      final app = controller(admin: true);
      var booking = await app.addBooking(draft());

      booking = await app.claimSharePaid(booking, booking.myShare!);
      expect(booking.myShare!.status, ShareStatus.pendingConfirmation);
      expect(booking.myShare!.claimedAt, now);
      expect(booking.myShare!.isPaid, isFalse);

      final queue = await app.loadPaymentQueue(ShareStatus.pendingConfirmation);
      final item = queue.singleWhere((row) => row.bookingId == booking.id);
      expect(item.code, booking.myShare!.code);
      expect(item.amount, booking.myShare!.amount);

      await app.confirmShare(item.shareId);
      booking = app.bookingById(booking.id)!;
      expect(booking.myShare!.status, ShareStatus.paid);
      expect(booking.myShare!.confirmedAt, now);
    },
  );

  test('a transfer not found can be claimed again', () async {
    final app = controller(admin: true);
    var booking = await app.addBooking(draft());
    booking = await app.claimSharePaid(booking, booking.myShare!);

    await app.rejectShare(booking.myShare!.id!, note: 'сумма 400 вместо 425');
    booking = app.bookingById(booking.id)!;
    expect(booking.myShare!.status, ShareStatus.notFound);
    expect(booking.myShare!.note, 'сумма 400 вместо 425');

    booking = await app.claimSharePaid(booking, booking.myShare!);
    expect(booking.myShare!.status, ShareStatus.pendingConfirmation);
  });

  test('every share paid confirms the booking at once', () async {
    final app = controller(admin: true);
    final booking = fillOpenPlaces(app, await app.addBooking(draft()));

    for (final share in booking.shares) {
      await app.confirmShare(share.id!);
    }

    expect(app.bookingById(booking.id)!.statusCode, 'confirmed');
  });

  test(
    'unpaid at the deadline: the booking falls through, money is owed back',
    () async {
      final app = controller(admin: true);
      var booking = await app.addBooking(draft());
      await app.confirmShare(booking.myShare!.id!);

      app.applyDeadlines(DateTime(2026, 5, 25, 17, 59));
      expect(app.bookingById(booking.id)!.statusCode, 'collecting_shares');

      app.applyDeadlines(DateTime(2026, 5, 25, 18));
      booking = app.bookingById(booking.id)!;
      expect(booking.statusCode, 'expired');
      expect(booking.isActive, isFalse);
      expect(booking.myShare!.status, ShareStatus.refundDue);
      expect(booking.shares.skip(1).every((share) => share.isOpen), isTrue);

      // The demo booking the fixtures start with falls through at the same
      // hour, so the list holds its refunds too.
      final refunds = await app.loadPaymentQueue(ShareStatus.refundDue);
      final mine = refunds.singleWhere((row) => row.bookingId == booking.id);
      await app.markShareRefunded(mine.shareId, note: 'СБП 25.05');
      booking = app.bookingById(booking.id)!;
      expect(booking.myShare!.status, ShareStatus.refunded);
      expect(booking.myShare!.refundedAt, now);
    },
  );

  test(
    'claims still unchecked at the deadline wait for the admin, then fall through',
    () async {
      final app = controller(admin: true);
      var booking = fillOpenPlaces(app, await app.addBooking(draft()));
      for (final share in booking.shares.skip(1)) {
        await app.confirmShare(share.id!);
      }
      booking = await app.claimSharePaid(
        app.bookingById(booking.id)!,
        booking.myShare!,
      );

      app.applyDeadlines(DateTime(2026, 5, 25, 18));
      booking = app.bookingById(booking.id)!;
      expect(booking.statusCode, 'awaiting_confirmation');
      expect(booking.isActive, isTrue);

      // Nobody checked by an hour before the start: everything goes back.
      app.applyDeadlines(DateTime(2026, 5, 25, 19));
      booking = app.bookingById(booking.id)!;
      expect(booking.statusCode, 'expired');
      expect(
        booking.shares.every((share) => share.status == ShareStatus.refundDue),
        isTrue,
      );
    },
  );

  test(
    'a claim not found while waiting for the admin ends the booking',
    () async {
      final app = controller(admin: true);
      var booking = fillOpenPlaces(app, await app.addBooking(draft()));
      for (final share in booking.shares.skip(1)) {
        await app.confirmShare(share.id!);
      }
      booking = await app.claimSharePaid(
        app.bookingById(booking.id)!,
        booking.myShare!,
      );
      app.applyDeadlines(DateTime(2026, 5, 25, 18));

      await app.rejectShare(booking.myShare!.id!);

      booking = app.bookingById(booking.id)!;
      expect(booking.statusCode, 'expired');
      expect(
        booking.shares.skip(1).every((s) => s.status == ShareStatus.refundDue),
        isTrue,
      );
    },
  );

  test('cancelling owes back every share that holds money', () async {
    final app = controller(admin: true);
    var booking = await app.addBooking(draft());
    await app.confirmShare(booking.myShare!.id!);

    booking = await app.cancelBooking(app.bookingById(booking.id)!);

    expect(booking.statusCode, 'cancelled');
    expect(booking.myShare!.status, ShareStatus.refundDue);
  });

  test('a free place is taken by following the link, and given back', () async {
    final app = controller();
    final theirs = (await app.addBooking(
      draft(),
    )).copyWith(clearMyShare: true, shares: const []);
    // Somebody else's booking: their share paid, one place free.
    final booking = theirs.copyWith(
      shares: const [
        BookingShare(
          id: 'their-1',
          userId: 'orlov',
          name: 'Максим Орлов',
          initial: 'М',
          status: ShareStatus.paid,
          amount: 800,
          code: 'SV-9001',
        ),
        BookingShare(
          id: 'their-2',
          name: '',
          initial: '',
          status: ShareStatus.open,
          amount: 800,
          code: 'SV-9002',
        ),
      ],
    );
    app.bookings = [booking];

    var taken = await app.takeShare(booking);
    expect(taken.myShare!.id, 'their-2');
    expect(taken.myShare!.status, ShareStatus.unpaid);
    expect(taken.openShares, 0);

    taken = await app.releaseShare(taken);
    expect(taken.myShare, isNull);
    expect(taken.openShares, 1);
  });

  test('a place with money on it cannot be walked away from', () async {
    final app = controller();
    final game = await app.createGame(
      sportId: 'football',
      venue: MockData.venues.first,
      date: tomorrow,
      startHour: 20,
      durationMinutes: 60,
      capacity: 4,
      type: GameType.open,
      genderFilter: GenderFilter.any,
    );
    final booking = app.bookingById(game.bookingId!)!;

    // The organiser cancels; they do not leave.
    await expectLater(app.releaseShare(booking), throwsA(isA<ApiException>()));

    // A player who has claimed payment does not leave either.
    app.bookings = [
      booking.copyWith(
        clearMyShare: true,
        shares: [
          booking.shares.first.copyWith(isCurrentUser: false),
          booking.shares[1].copyWith(
            status: ShareStatus.pendingConfirmation,
            userId: 'me',
            name: 'Вы',
            initial: 'В',
            isCurrentUser: true,
          ),
          ...booking.shares.skip(2),
        ],
      ),
    ];
    Object? refusal;
    try {
      await app.releaseShare(app.bookings.single);
    } catch (error) {
      refusal = error;
    }
    expect(AppController.kindOf(refusal!), AppErrorKind.sharePaid);
  });

  test(
    'a paid game stands on a booking, and its organiser holds a share',
    () async {
      final app = controller();
      final game = await app.createGame(
        sportId: 'football',
        venue: MockData.venues.first,
        date: tomorrow,
        startHour: 20,
        durationMinutes: 60,
        capacity: 4,
        type: GameType.open,
        genderFilter: GenderFilter.any,
      );

      expect(game.payment, GamePayment.shares);
      final booking = app.bookingById(game.bookingId!)!;
      expect(booking.gameId, game.id);
      expect(booking.shares, hasLength(4));
      expect(game.myShare!.id, booking.myShare!.id);
      expect(game.pricePerPerson, booking.shares.first.amount);

      // Claiming payment on the booking shows on the game as well.
      await app.claimSharePaid(booking, booking.myShare!);
      final current = app.games.firstWhere((item) => item.id == game.id);
      expect(current.myShare!.status, ShareStatus.pendingConfirmation);
    },
  );

  test('a game the organiser pays for costs the players nothing', () async {
    final app = controller();
    final game = await app.createGame(
      sportId: 'football',
      venue: MockData.venues.first,
      date: tomorrow,
      startHour: 20,
      durationMinutes: 60,
      capacity: 4,
      type: GameType.open,
      genderFilter: GenderFilter.any,
      payment: GamePayment.organizer,
    );

    expect(game.pricePerPerson, 0);
    expect(app.bookingById(game.bookingId!)!.shares, hasLength(1));
  });

  test('only the payments admin confirms', () async {
    final app = controller();
    final booking = await app.addBooking(draft());

    await expectLater(
      app.confirmShare(booking.myShare!.id!),
      throwsA(isA<ApiException>()),
    );
  });

  test('the demo build is its own payments admin', () {
    final demo = AppController.demo(now: now);
    addTearDown(demo.dispose);
    expect(demo.isPaymentAdmin, isTrue);
  });

  test('test payment details say they are not real', () async {
    final app = controller();
    final info = await app.loadPaymentInfo();
    expect(info.isTest, isTrue);
    expect(app.paymentInfo, same(info));
  });

  group('reading the server', () {
    test('a server with only is_paid still reads', () {
      expect(ShareStatus.fromJson({'is_paid': true}), ShareStatus.paid);
      expect(ShareStatus.fromJson({'status': 'mystery'}), ShareStatus.unpaid);
      expect(
        ShareStatus.fromJson({'status': 'pending_confirmation'}),
        ShareStatus.pendingConfirmation,
      );
    });

    test('a free place is nobody\'s, even when the reader is unknown', () {
      final share = BookingShare.fromJson({
        'id': 's1',
        'user_id': null,
        'status': 'open',
        'amount': 425,
        'code': null,
      }, currentUserId: null);
      expect(share.isOpen, isTrue);
      expect(share.isCurrentUser, isFalse);
      expect(share.name, isEmpty);
      expect(share.amount, 425);
    });

    test('a game reads how it is paid and the reader\'s share', () {
      final game = Game.fromJson(
        {
          'id': 'g1',
          'sport_id': 'football',
          'time_slot': {
            'starts_at': '2026-05-25T20:00:00Z',
            'duration_minutes': 60,
          },
          'capacity': 4,
          'price_per_person': 400,
          'type': 'open',
          'gender_filter': 'any',
          'organizer_id': 'u1',
          'participants': const [],
          'payment': 'organizer',
          'booking_id': 'b1',
          'deadline_at': '2026-05-25T18:00:00Z',
          'my_share': {
            'id': 's2',
            'user_id': 'u2',
            'name': 'Вы',
            'status': 'unpaid',
            'amount': 400,
            'code': 'SV-1234',
          },
        },
        venue: MockData.venues.first,
        currentUserId: 'u2',
      );
      expect(game.payment, GamePayment.organizer);
      expect(game.bookingId, 'b1');
      expect(game.myShare!.code, 'SV-1234');
      expect(game.myShare!.isCurrentUser, isTrue);
      // Moscow hours kept as UTC wall clock, like the start.
      expect(game.deadline, DateTime(2026, 5, 25, 18));
    });
  });
}
