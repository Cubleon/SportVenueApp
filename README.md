# SportVenue Flutter app

Flutter client for the SportVenue FastAPI service.

## Local run

Start `SportVenueServer` first, then:

```bash
flutter pub get
flutter run
```

The API base URL is selected automatically:

- Android emulator: `http://10.0.2.2:8000/api/v1`
- iOS simulator, desktop, and web: `http://localhost:8000/api/v1`

Override it for a physical device, staging, or production:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://YOUR-DEVELOPMENT-MACHINE-IP:8000/api/v1
```

Use HTTPS for production. Android cleartext access is enabled only for debug
and profile builds; iOS permits local-network development.

Phone login uses [SMS.ru call checks](https://sms.ru/docs/api/api_group_call/call).
Configure `SMS_RU_API_ID` on the server, enter your phone, and accept the consent
checkbox. The app requests `/auth/call/start`, shows the returned number, and
opens the dialer when you tap «Позвонить». Call from the entered phone, using
the correct SIM, and return to the app. You can copy or manually dial the number
on devices without a dialer.

The app polls `/auth/call/status` every three seconds while active and checks
immediately when you return from the dialer. Only a server-confirmed call
creates a session. The screen shows a countdown and offers a new challenge
after expiry. There is no demo code or SMS-code entry. Navigating away cancels
polling and ignores late confirmation responses.

Deploy this client with the updated backend; the old `/auth/call/verify`
endpoint is no longer used. See the server README for the database migration.

## Demo build

The demo runs on built-in fixtures, needs no server, and opens already
signed in. Signing out leads to the phone field, where any number (or any
email) signs straight back in — there is no call and no code.

```bash
flutter run --dart-define=DEMO=true
flutter build web --release --no-web-resources-cdn --dart-define=DEMO=true
```

Without the flag the app is the real one: the demo sign-in is refused, and
nothing needs editing before or after a build.

## Verification

Club owners choose «Я клуб» and enter the login and password issued by the
SportVenue team. The local test account is `club` / `password`. The app sends
credentials to `POST /auth/club/login`; club phone/email verification and
developer shortcuts are not available. Accounts cannot register themselves.
After the first login, clubs enter only their club name, saved through
`PATCH /club/account`. No personal-name or sport-selection form is shown.
Server-issued account type and saved `club_name` determine the route after
login and session restore. Completed names are not requested again; the name
is prefilled when creating the club's first public map location.

The club cabinet supports creating and editing clubs (including a map pin),
creating and editing venues, and publishing/removing bookable time intervals.
The schedule uses Moscow time regardless of the device timezone. Player slot
selection retains half-hour start times and the exact server timestamp through
booking/game confirmation. New club venues have no bookable slots until their
owner publishes them. Already booked intervals cannot be withdrawn.

Club and venue cards provide deletion actions with confirmation. Deleting a
club also removes all its venues from the owner cabinet and the public map;
deleting a venue removes only that venue. The club account and its saved name
remain available. Upcoming active bookings/games and live reservation holds
block deletion with an explanatory message. Past and cancelled booking/game
records remain readable in the player's history. The API archives these
entities instead of removing the historical records.

Debug builds connected to the API show «Войти как разработчик» on the sign-in
screen. One click opens the main screen with the server's dedicated developer
account, skipping phone/email verification and sport selection. Accounts with
an incomplete name first fill in the same name form as regular users. Sessions use
the same storage, refresh, and logout as regular sign-in. Start the local API
as usual; its `ENVIRONMENT` must be `local`, `development`, or `dev` with
`DEV_AUTH_ENABLED=true` (the default). No SMS.ru or SMTP setup is needed.
The button is absent in profile/release builds. To hide it in debug too, run
`flutter run --dart-define=DEV_AUTH_ENABLED=false`.

After the first successful phone or email verification, accounts without a
saved first name and surname complete «Давайте познакомимся» before sport
selection. First name and surname are required; patronymic is optional. The
form saves through `PATCH /me` and is skipped on subsequent sign-ins and
session restores once those names are present. Closing the app before saving
resumes the form next time. The form also applies to existing incomplete
profiles and cannot be skipped by navigating to another route. Profile name
editing remains available in the profile screen.

Email sign-in is available from «Войти по почте». Enter an address, accept
consent, request the code, and enter all six digits from the message. Codes
expire after five minutes, allow five wrong attempts, and can be resent after
60 seconds. Pasting and leading zeros are supported. The verified email is
shown in the profile; sessions use the same secure storage and refresh flow
as phone sign-in. Configure Gmail SMTP only on the server (see its README).

Functional tests can run independently of platform-specific screenshots:
`flutter test --exclude-tags golden`.

```bash
flutter analyze
flutter test
```

## Public venue submissions and moderator access

The create sheet offers «Добавить площадку»; the profile also links to
«Общественные площадки». Players can submit a free public facility in Moscow
with its name, address, map location, sports, surface and lighting. A public
access confirmation is required. An optional description explains the location
and access. Authors see their requests and their current moderation statuses.

The sign-in screen has a separate «Вход для модераторов» button. The local
account is `moderator` / `password`. Moderators see only the pending queue,
request details, map preview, approval/rejection actions, refresh and logout.
Their role is restored from `/me` and cannot enter the player or club screens.

Approved facilities appear in the existing map and catalogue with
`venue_kind: "public"` and «Бесплатно». They do not belong to clubs, have no
paid booking action, and are excluded from venue selection for paid games and
bookings. The club workflow is unchanged. Deploy with the matching server and
migration 007; see the server README for local seed configuration.
