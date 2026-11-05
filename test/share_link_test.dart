import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/router.dart';

void main() {
  test('with a domain, a link is the domain plus the path', () {
    expect(
      shareLinkFor(Routes.game('g7'), base: 'https://example.ru'),
      'https://example.ru/game/g7',
    );
    expect(
      shareLinkFor(Routes.booking('b1'), base: 'https://example.ru/'),
      'https://example.ru/booking/b1',
    );
  });

  test('without one, the web page shares itself with a fragment', () {
    expect(
      shareLinkFor(
        Routes.game('g7'),
        base: '',
        page: Uri.parse('https://cubleon.github.io/SportVenueApp/'),
      ),
      'https://cubleon.github.io/SportVenueApp/#/game/g7',
    );
  });
}
