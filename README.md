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

## Verification

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
