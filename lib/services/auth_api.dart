import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Mirrors the backend ExperienceLevel enum.

import 'package:http/http.dart' as http;

enum ExperienceLevel { beginner, intermediate, advanced }

extension ExperienceLevelX on ExperienceLevel {
  String toApiString() => switch (this) {
    ExperienceLevel.beginner     => 'Beginner',
    ExperienceLevel.intermediate => 'Intermediate',
    ExperienceLevel.advanced     => 'Advanced',
  };
}

/// The API base URL.
/// - Override at build time:  flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5209
/// - Web & desktop default:   http://localhost:5209
/// - Android emulator:        http://10.0.2.2:5209  (maps to host's localhost)
const _kEnvApiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get _apiBaseUrl {
  if (_kEnvApiUrl.isNotEmpty) return _kEnvApiUrl;
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5209';
  return 'http://localhost:5209';
}

class AuthApi {
  final String baseUrl;
  final http.Client _client;

  AuthApi({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? _apiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    String? city,
    String? profileImageUrl,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'city': city,
        'profileImageUrl': profileImageUrl,
      }),
    );

    return AuthSession.fromJson(_decodeObject(response));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    return AuthSession.fromJson(_decodeObject(response));
  }

  Future<AuthUser> me(String token) async {
    final response = await _client.get(
      _uri('/api/auth/me'),
      headers: _jsonHeaders(token: token),
    );

    return AuthUser.fromJson(_decodeObject(response));
  }

  Future<RoleStatus> roleStatus(String token) async {
    final response = await _client.get(
      _uri('/api/auth/role-status'),
      headers: _jsonHeaders(token: token),
    );

    return RoleStatus.fromJson(_decodeObject(response));
  }

  /// Calls POST /api/auth/assign-role.
  /// [role] must be one of: "Player", "VenueOwner", "Staff".
  /// [experience] is required when [role] is "Player".
  Future<void> assignRole(
    String token, {
    required String role,
    ExperienceLevel? experience,
  }) async {
    final body = <String, dynamic>{'role': role};
    if (experience != null) {
      body['experience'] = experience.toApiString();
    }

    final response = await _client.post(
      _uri('/api/auth/assign-role'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode(body),
    );

    _decodeObject(response); // throws ApiException on non-2xx
  }

  /// Fetches the current user's lobby card from GET /api/match/lobby-me.
  Future<LobbyMeData> lobbyMe(String token) async {
    final response = await _client.get(
      _uri('/api/match/lobby-me'),
      headers: _jsonHeaders(token: token),
    );
    return LobbyMeData.fromJson(_decodeObject(response));
  }

  /// Fetches venues near [lat]/[lng] within [radiusKm] kilometres.
  /// Calls GET /api/venue/nearby — no auth required.
  Future<List<VenueDto>> fetchNearbyVenues({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final uri = _uri('/api/venue/nearby').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radiusKm': radiusKm.toStringAsFixed(1),
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((e) => VenueDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(
      'Failed to fetch nearby venues (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      _extractMessage(decoded, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  String _extractMessage(Map<String, dynamic> body, int statusCode) {
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return 'Request failed with status $statusCode.';
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthSession {
  final String token;
  final DateTime? expiresAt;
  final AuthUser user;

  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class AuthUser {
  final int userId;
  final String username;
  final String email;
  final String userType;
  final String? profileImageUrl;
  final String? city;

  const AuthUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.userType,
    required this.profileImageUrl,
    required this.city,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      userType: json['userType'] as String? ?? 'User',
      profileImageUrl: json['profileImageUrl'] as String?,
      city: json['city'] as String?,
    );
  }
}

class RoleStatus {
  final bool hasRole;
  final String userType;

  const RoleStatus({required this.hasRole, required this.userType});

  factory RoleStatus.fromJson(Map<String, dynamic> json) {
    return RoleStatus(
      hasRole: json['hasRole'] as bool,
      userType: json['userType'] as String? ?? 'User',
    );
  }
}

// ─── Lobby Me ─────────────────────────────────────────────────────────────────

class LobbyMeData {
  final int userId;
  final String username;
  final String avatarInitials;
  final double skillLevel;
  final String tier;
  final int prestige;
  final String? profileImageUrl;

  const LobbyMeData({
    required this.userId,
    required this.username,
    required this.avatarInitials,
    required this.skillLevel,
    required this.tier,
    required this.prestige,
    this.profileImageUrl,
  });

  factory LobbyMeData.fromJson(Map<String, dynamic> json) {
    return LobbyMeData(
      userId:         json['userId']         as int,
      username:       json['username']       as String,
      avatarInitials: json['avatarInitials'] as String,
      skillLevel:     (json['skillLevel'] as num).toDouble(),
      tier:           json['tier']           as String,
      prestige:       json['prestige']       as int,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}

// ─── Venue Dto ────────────────────────────────────────────────────────────────

/// Mirrors the backend VenueResponse DTO returned by GET /api/venue/nearby.
/// [venueId] is the DB primary key — used as PrefferedVenue in matchmaking.
class VenueDto {
  final int venueId;
  final String venueName;
  final String address;
  final double latitude;
  final double longitude;
  final double overallRating;
  final String openTime;
  final String closeTime;
  final String? phoneNumber;
  final double distanceKm;

  const VenueDto({
    required this.venueId,
    required this.venueName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.overallRating,
    required this.openTime,
    required this.closeTime,
    required this.phoneNumber,
    required this.distanceKm,
  });

  factory VenueDto.fromJson(Map<String, dynamic> json) {
    return VenueDto(
      venueId:       json['venueId']       as int,
      venueName:     json['venueName']     as String,
      address:       json['address']       as String,
      latitude:      (json['latitude']     as num).toDouble(),
      longitude:     (json['longitude']    as num).toDouble(),
      overallRating: (json['overallRating'] as num).toDouble(),
      openTime:      json['openTime']      as String,
      closeTime:     json['closeTime']     as String,
      phoneNumber:   json['phoneNumber']   as String?,
      distanceKm:    (json['distanceKm']   as num).toDouble(),
    );
  }
}

