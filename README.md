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

For the MVP login flow, enter the demo OTP `1111`. The app then calls
`POST /api/v1/auth/login` and uses the returned Bearer/refresh tokens for
protected requests.

## Verification

```bash
flutter analyze
flutter test
```
