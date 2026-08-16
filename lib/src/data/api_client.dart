import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef ApiJsonObject = Map<String, dynamic>;
typedef ApiJsonList = List<ApiJsonObject>;
typedef ApiTokensChanged = void Function(ApiTokenPair? tokens);

const String _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Resolves the API root used by [SportVenueApiClient].
///
/// Override it at build/run time with:
/// `--dart-define=API_BASE_URL=https://example.com/api/v1`.
String resolveApiBaseUrl({
  String configuredUrl = _configuredApiBaseUrl,
  bool? isWeb,
  TargetPlatform? targetPlatform,
}) {
  final override = configuredUrl.trim();
  if (override.isNotEmpty) {
    return _withoutTrailingSlashes(override);
  }

  final web = isWeb ?? kIsWeb;
  final platform = targetPlatform ?? defaultTargetPlatform;
  final host = !web && platform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
  return 'http://$host:8000/api/v1';
}

enum ApiExceptionKind { authentication, http, invalidResponse, network }

/// A failure reported by the API transport layer.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.details,
    this.uri,
    this.responseBody,
    this.cause,
  });

  final ApiExceptionKind kind;
  final String message;
  final int? statusCode;
  final Object? details;
  final Uri? uri;
  final String? responseBody;
  final Object? cause;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$status: $message';
  }
}

/// The rotating access/refresh token pair returned by the API.
class ApiTokenPair {
  const ApiTokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
  });

  factory ApiTokenPair.fromJson(ApiJsonObject json) {
    final accessToken = _requiredString(json, 'access_token');
    final refreshToken = _requiredString(json, 'refresh_token');
    final tokenType = _requiredString(json, 'token_type');
    final expiresAtText = _requiredString(json, 'expires_at');
    final expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null) {
      throw const FormatException('expires_at must be an ISO-8601 date-time');
    }

    return ApiTokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresAt: expiresAt,
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;

  ApiJsonObject toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_at': expiresAt.toIso8601String(),
  };
}

class ApiPhoneChallenge {
  const ApiPhoneChallenge({required this.id, required this.expiresAt});

  factory ApiPhoneChallenge.fromJson(ApiJsonObject json) {
    final id = _requiredString(json, 'challenge_id');
    final expiresAt = DateTime.tryParse(_requiredString(json, 'expires_at'));
    if (expiresAt == null) {
      throw const FormatException('expires_at must be an ISO-8601 date-time');
    }
    return ApiPhoneChallenge(id: id, expiresAt: expiresAt);
  }

  final String id;
  final DateTime expiresAt;
}

/// HTTP transport for the SportVenue FastAPI service.
///
/// Tokens are kept in memory. Use [onTokensChanged] to persist rotated tokens,
/// and pass them back through [initialTokens] when rebuilding the client.
class SportVenueApiClient {
  SportVenueApiClient({
    String? baseUrl,
    http.Client? httpClient,
    ApiTokenPair? initialTokens,
    this.onTokensChanged,
    this.requestTimeout = const Duration(seconds: 20),
    Map<String, String> defaultHeaders = const {},
  }) : _baseUri = _parseBaseUrl(baseUrl ?? resolveApiBaseUrl()),
       _httpClient = httpClient ?? http.Client(),
       _tokens = initialTokens,
       _defaultHeaders = Map.unmodifiable(defaultHeaders);

  final Uri _baseUri;
  final http.Client _httpClient;
  final Map<String, String> _defaultHeaders;
  final ApiTokensChanged? onTokensChanged;
  final Duration requestTimeout;

  ApiTokenPair? _tokens;
  Future<ApiTokenPair>? _refreshInFlight;
  bool _isClosed = false;

  Uri get baseUri => _baseUri;
  ApiTokenPair? get tokens => _tokens;
  bool get isAuthenticated => _tokens != null;

  void setTokens(ApiTokenPair tokens) {
    _ensureOpen();
    _replaceTokens(tokens);
  }

  void clearTokens() {
    _ensureOpen();
    _replaceTokens(null);
  }

  Future<ApiPhoneChallenge> startPhoneCall({
    required String phone,
    required bool consentAccepted,
  }) async {
    final response = await _send(
      'POST',
      const ['auth', 'call', 'start'],
      body: {'phone': phone, 'consent_accepted': consentAccepted},
    );
    return ApiPhoneChallenge.fromJson(_parseObject(response));
  }

  Future<ApiTokenPair> verifyPhoneCall({
    required String challengeId,
    required String code,
  }) async {
    final response = await _send(
      'POST',
      const ['auth', 'call', 'verify'],
      body: {'challenge_id': challengeId, 'code': code},
    );
    final pair = _parseTokenPair(response);
    _replaceTokens(pair);
    return pair;
  }

  /// Rotates both tokens. A failed refresh with a 401 clears local tokens.
  Future<ApiTokenPair> refreshTokens() {
    _ensureOpen();
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }

    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<ApiJsonList> listSports() async {
    final response = await _send('GET', const ['sports']);
    return _parseObjectList(response);
  }

  Future<ApiJsonList> listVenues({
    String cityId = 'moscow',
    String? sportId,
    String? query,
  }) async {
    final response = await _send(
      'GET',
      const ['venues'],
      query: {'city_id': cityId, 'sport_id': sportId, 'q': query},
    );
    return _parseObjectList(response);
  }

  Future<ApiJsonObject> getVenue(String venueId) async {
    final response = await _send('GET', ['venues', venueId]);
    return _parseObject(response);
  }

  Future<ApiJsonList> listVenueSlots(
    String venueId, {
    DateTime? day,
    int durationMinutes = 60,
  }) async {
    final response = await _send(
      'GET',
      ['venues', venueId, 'slots'],
      query: {
        'day': day == null ? null : _dateOnly(day),
        'duration_minutes': '$durationMinutes',
      },
    );
    return _parseObjectList(response);
  }

  Future<ApiJsonObject> createSlotLock(
    String venueId, {
    required DateTime startsAt,
    required int durationMinutes,
  }) async {
    final response = await _send(
      'POST',
      ['venues', venueId, 'locks'],
      authenticated: true,
      body: {
        'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
    );
    return _parseObject(response);
  }

  Future<ApiJsonObject> getMe() async {
    final response = await _send('GET', const ['me'], authenticated: true);
    return _parseObject(response);
  }

  Future<ApiJsonObject> updateMe({
    String? name,
    String? lastName,
    String? avatarUrl,
    DateTime? birthDate,
    String? gender,
    String? cityId,
    double? latitude,
    double? longitude,
    Iterable<String>? preferredSportIds,
  }) async {
    final body = <String, Object?>{
      'name': ?name,
      'last_name': ?lastName,
      'avatar_url': ?avatarUrl,
      if (birthDate != null) 'birth_date': _dateOnly(birthDate),
      'gender': ?gender,
      'city_id': ?cityId,
      'geo_lat': ?latitude,
      'geo_lng': ?longitude,
      if (preferredSportIds != null)
        'preferred_sport_ids': preferredSportIds.toList(growable: false),
    };
    final response = await _send(
      'PATCH',
      const ['me'],
      authenticated: true,
      body: body,
    );
    return _parseObject(response);
  }

  Future<ApiJsonObject> updatePreferences(Iterable<String> preferredSportIds) {
    return updateMe(preferredSportIds: preferredSportIds);
  }

  Future<ApiJsonList> listBookings() async {
    final response = await _send('GET', const [
      'bookings',
    ], authenticated: true);
    return _parseObjectList(response);
  }

  Future<ApiJsonObject> getBooking(String bookingId) async {
    final response = await _send('GET', [
      'bookings',
      bookingId,
    ], authenticated: true);
    return _parseObject(response);
  }

  Future<ApiJsonObject> createBooking({
    required String venueId,
    required DateTime startsAt,
    required int durationMinutes,
    required int players,
    required String paymentMode,
  }) async {
    final response = await _send(
      'POST',
      const ['bookings'],
      authenticated: true,
      body: {
        'venue_id': venueId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'players': players,
        'payment_mode': paymentMode,
      },
    );
    return _parseObject(response);
  }

  Future<ApiJsonObject> joinBookingShare(
    String bookingId, {
    String? inviteToken,
  }) async {
    final response = await _send(
      'POST',
      ['bookings', bookingId, 'shares'],
      authenticated: true,
      body: {'invite_token': ?inviteToken},
    );
    return _parseObject(response);
  }

  Future<ApiJsonObject> cancelBooking(String bookingId) async {
    final response = await _send('POST', [
      'bookings',
      bookingId,
      'cancel',
    ], authenticated: true);
    return _parseObject(response);
  }

  Future<ApiJsonList> listGames({
    String? sportId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? gameType,
    String? genderFilter,
    bool availableOnly = true,
  }) async {
    final response = await _send(
      'GET',
      const ['games'],
      query: {
        'sport_id': sportId,
        'date_from': dateFrom == null ? null : _dateOnly(dateFrom),
        'date_to': dateTo == null ? null : _dateOnly(dateTo),
        'type': gameType,
        'gender_filter': genderFilter,
        'available_only': '$availableOnly',
      },
    );
    return _parseObjectList(response);
  }

  Future<ApiJsonObject> getGame(String gameId) async {
    final response = await _send('GET', ['games', gameId]);
    return _parseObject(response);
  }

  Future<ApiJsonObject> createGame({
    required String sportId,
    required String venueId,
    required DateTime startsAt,
    required int durationMinutes,
    required int capacity,
    required String gameType,
    String genderFilter = 'any',
  }) async {
    final response = await _send(
      'POST',
      const ['games'],
      authenticated: true,
      body: {
        'sport_id': sportId,
        'venue_id': venueId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'capacity': capacity,
        'type': gameType,
        'gender_filter': genderFilter,
      },
    );
    return _parseObject(response);
  }

  Future<ApiJsonObject> joinGame(String gameId, {String? inviteToken}) async {
    final response = await _send(
      'POST',
      ['games', gameId, 'join'],
      authenticated: true,
      body: {'invite_token': ?inviteToken},
    );
    return _parseObject(response);
  }

  Future<ApiJsonObject> approveGameParticipant(
    String gameId,
    String participantId,
  ) async {
    final response = await _send('POST', [
      'games',
      gameId,
      'participants',
      participantId,
      'approve',
    ], authenticated: true);
    return _parseObject(response);
  }

  Future<ApiJsonObject> rejectGameParticipant(
    String gameId,
    String participantId,
  ) async {
    final response = await _send('POST', [
      'games',
      gameId,
      'participants',
      participantId,
      'reject',
    ], authenticated: true);
    return _parseObject(response);
  }

  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _httpClient.close();
  }

  Future<ApiTokenPair> _performRefresh() async {
    final refreshToken = _tokens?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ApiException(
        kind: ApiExceptionKind.authentication,
        message: 'No refresh token is available',
        statusCode: 401,
      );
    }

    try {
      final response = await _send(
        'POST',
        const ['auth', 'refresh'],
        body: {'refresh_token': refreshToken},
        retryAfterUnauthorized: false,
      );
      final pair = _parseTokenPair(response);
      _replaceTokens(pair);
      return pair;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _replaceTokens(null);
      }
      rethrow;
    }
  }

  Future<http.Response> _send(
    String method,
    List<String> pathSegments, {
    Map<String, String?> query = const {},
    Map<String, Object?>? body,
    bool authenticated = false,
    bool retryAfterUnauthorized = true,
  }) async {
    _ensureOpen();
    final uri = _buildUri(pathSegments, query);
    final request = http.Request(method, uri);
    request.headers.addAll(_defaultHeaders);
    request.headers['Accept'] = 'application/json';

    if (authenticated) {
      final accessToken = _tokens?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw ApiException(
          kind: ApiExceptionKind.authentication,
          message: 'Authentication is required',
          statusCode: 401,
          uri: uri,
        );
      }
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    late http.Response response;
    try {
      final streamed = await _httpClient.send(request).timeout(requestTimeout);
      response = await http.Response.fromStream(
        streamed,
      ).timeout(requestTimeout);
    } on TimeoutException catch (error) {
      throw ApiException(
        kind: ApiExceptionKind.network,
        message: 'The API request timed out',
        uri: uri,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        kind: ApiExceptionKind.network,
        message: error.message,
        uri: uri,
        cause: error,
      );
    }

    if (response.statusCode == 401 &&
        authenticated &&
        retryAfterUnauthorized &&
        _tokens?.refreshToken.isNotEmpty == true) {
      await refreshTokens();
      return _send(
        method,
        pathSegments,
        query: query,
        body: body,
        authenticated: true,
        retryAfterUnauthorized: false,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorFromResponse(response, uri);
    }
    return response;
  }

  ApiTokenPair _parseTokenPair(http.Response response) {
    final object = _parseObject(response);
    try {
      return ApiTokenPair.fromJson(object);
    } on FormatException catch (error) {
      throw _invalidResponse(
        response,
        message: 'The API returned an invalid token payload: ${error.message}',
        cause: error,
      );
    }
  }

  ApiJsonObject _parseObject(http.Response response) {
    final decoded = _decodeSuccess(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw _invalidResponse(
      response,
      message: 'Expected a JSON object from the API',
      details: decoded,
    );
  }

  ApiJsonList _parseObjectList(http.Response response) {
    final decoded = _decodeSuccess(response);
    if (decoded is! List<dynamic>) {
      throw _invalidResponse(
        response,
        message: 'Expected a JSON array from the API',
        details: decoded,
      );
    }

    final result = <ApiJsonObject>[];
    for (var index = 0; index < decoded.length; index++) {
      final item = decoded[index];
      if (item is! Map<String, dynamic>) {
        throw _invalidResponse(
          response,
          message: 'Expected a JSON object at array index $index',
          details: item,
        );
      }
      result.add(item);
    }
    return result;
  }

  Object? _decodeSuccess(http.Response response) {
    final body = _responseText(response);
    if (body.trim().isEmpty) {
      throw _invalidResponse(
        response,
        message: 'The API returned an empty response',
      );
    }
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw _invalidResponse(
        response,
        message: 'The API returned invalid JSON',
        cause: error,
      );
    }
  }

  ApiException _invalidResponse(
    http.Response response, {
    required String message,
    Object? details,
    Object? cause,
  }) {
    return ApiException(
      kind: ApiExceptionKind.invalidResponse,
      message: message,
      statusCode: response.statusCode,
      details: details,
      uri: response.request?.url,
      responseBody: _responseText(response),
      cause: cause,
    );
  }

  ApiException _errorFromResponse(http.Response response, Uri uri) {
    final body = _responseText(response);
    Object? decoded;
    if (body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        decoded = null;
      }
    }

    Object? details = decoded;
    String? message;
    if (decoded is Map<String, dynamic>) {
      details = decoded['detail'] ?? decoded;
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail;
      } else {
        final apiMessage = decoded['message'];
        if (apiMessage is String && apiMessage.trim().isNotEmpty) {
          message = apiMessage;
        }
      }
    }

    return ApiException(
      kind: response.statusCode == 401
          ? ApiExceptionKind.authentication
          : ApiExceptionKind.http,
      message: message ?? 'API request failed',
      statusCode: response.statusCode,
      details: details,
      uri: uri,
      responseBody: body,
    );
  }

  Uri _buildUri(
    List<String> pathSegments,
    Map<String, String?> queryParameters,
  ) {
    final baseSegments = _baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: true);
    baseSegments.addAll(pathSegments);

    final query = <String, String>{
      for (final entry in queryParameters.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return _baseUri.replace(
      pathSegments: baseSegments,
      queryParameters: query.isEmpty ? null : query,
    );
  }

  void _replaceTokens(ApiTokenPair? tokens) {
    _tokens = tokens;
    onTokensChanged?.call(tokens);
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('SportVenueApiClient has been closed');
    }
  }
}

Uri _parseBaseUrl(String value) {
  final normalized = _withoutTrailingSlashes(value.trim());
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw ArgumentError.value(
      value,
      'baseUrl',
      'Must be an absolute HTTP(S) URL without a query or fragment',
    );
  }
  return uri;
}

String _withoutTrailingSlashes(String value) {
  return value.replaceFirst(RegExp(r'/+$'), '');
}

String _requiredString(ApiJsonObject json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _responseText(http.Response response) {
  try {
    return utf8.decode(response.bodyBytes);
  } on FormatException {
    return response.body;
  }
}
