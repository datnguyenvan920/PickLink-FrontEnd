import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Mirrors the backend ExperienceLevel enum.

import 'package:http/http.dart' as http;
import 'avatar_picker.dart';

// ─── Experience Level ─────────────────────────────────────────────────────────

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
    String? commune,
    String? profileImageUrl,
  }) async {
    final response = await _postJson('/api/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'city': city,
      'commune': commune,
      'profileImageUrl': profileImageUrl,
    });

    return AuthSession.fromJson(_decodeObject(response));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _postJson('/api/auth/login', {
      'email': email,
      'password': password,
    });

    return AuthSession.fromJson(_decodeObject(response));
  }

  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final response = await _postJson('/api/auth/google', {
      'idToken': idToken,
    });

    return AuthSession.fromJson(_decodeObject(response));
  }

  Future<ForgotPasswordResult> forgotPassword({required String email}) async {
    final response = await _postJson('/api/auth/forgot-password', {
      'email': email,
    });

    return ForgotPasswordResult.fromJson(_decodeObject(response));
  }

  Future<String> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final response = await _postJson('/api/auth/reset-password', {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });

    final decoded = _decodeObject(response);
    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return 'Đặt lại mật khẩu thành công.';
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

  Future<UserProfile> profile(String token) async {
    try {
      final response = await _client.get(
        _uri('/api/profile/me'),
        headers: _jsonHeaders(token: token),
      );

      return UserProfile.fromJson(_decodeObject(response));
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được máy chủ. Vui lòng kiểm tra backend đã chạy ở $baseUrl.',
      );
    }
  }

  Future<UserProfile> updateProfile({
    required String token,
    required UpdateProfileRequest request,
  }) async {
    try {
      final response = await _client.put(
        _uri('/api/profile/me'),
        headers: _jsonHeaders(token: token),
        body: jsonEncode(request.toJson()),
      );

      return UserProfile.fromJson(_decodeObject(response));
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được máy chủ. Vui lòng kiểm tra backend đã chạy ở $baseUrl.',
      );
    }
  }

  Future<UserProfile> uploadAvatar({
    required String token,
    required PickedAvatar avatar,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/profile/me/avatar'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        avatar.bytes,
        filename: avatar.fileName,
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return UserProfile.fromJson(_decodeObject(response));
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được máy chủ. Vui lòng kiểm tra backend đã chạy ở $baseUrl.',
      );
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> _postJson(
      String path, Map<String, dynamic> body) async {
    try {
      return await _client.post(
        _uri(path),
        headers: _jsonHeaders(),
        body: jsonEncode(body),
      );
    } on http.ClientException {
      throw ApiException(
        'Không kết nối được máy chủ. Vui lòng kiểm tra backend đã chạy ở $baseUrl.',
      );
    }
  }

  Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Máy chủ trả về phản hồi không hợp lệ. Vui lòng kiểm tra backend.',
        statusCode: response.statusCode,
      );
    }

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

    final errorsMessage = _extractValidationError(body['errors']);
    if (errorsMessage != null) {
      return errorsMessage;
    }

    final detail = body['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }

    final title = body['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title;
    }

    return 'Yêu cầu thất bại với mã trạng thái $statusCode.';
  }

  String? _extractValidationError(Object? errors) {
    if (errors is! Map<String, dynamic>) {
      return null;
    }

    for (final value in errors.values) {
      if (value is List) {
        for (final item in value) {
          if (item is String && item.trim().isNotEmpty) {
            return item;
          }
        }
      }

      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ForgotPasswordResult {
  final String message;
  final DateTime? expiresAt;

  const ForgotPasswordResult({
    required this.message,
    required this.expiresAt,
  });

  factory ForgotPasswordResult.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResult(
      message: json['message'] as String? ??
          'Mã đặt lại mật khẩu đã được gửi qua email.',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }
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
  final String? commune;

  const AuthUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.userType,
    required this.profileImageUrl,
    required this.city,
    required this.commune,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      userType: json['userType'] as String? ?? 'User',
      profileImageUrl: json['profileImageUrl'] as String?,
      city: json['city'] as String?,
      commune: json['commune'] as String?,
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

// ─── Profile ──────────────────────────────────────────────────────────────────

class UpdateProfileRequest {
  final String username;
  final String? city;
  final String? commune;
  final String? profileImageUrl;
  final double skillLevel;
  final String? playerSubType;
  final String? playFrequency;
  final String? preferredTimeSlot;
  final String? bio;
  final DateTime? birthDate;
  final String? gender;
  final double? heightCm;
  final double? weightKg;

  const UpdateProfileRequest({
    required this.username,
    required this.city,
    required this.commune,
    required this.profileImageUrl,
    required this.skillLevel,
    required this.playerSubType,
    required this.playFrequency,
    required this.preferredTimeSlot,
    required this.bio,
    required this.birthDate,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'city': city,
      'commune': commune,
      'profileImageUrl': profileImageUrl,
      'skillLevel': skillLevel,
      'playerSubType': playerSubType,
      'playFrequency': playFrequency,
      'preferredTimeSlot': preferredTimeSlot,
      'bio': bio,
      'birthDate': birthDate == null ? null : _dateOnly(birthDate!),
      'gender': gender,
      'heightCm': heightCm,
      'weightKg': weightKg,
    };
  }
}

class UserProfile {
  final int userId;
  final String username;
  final String email;
  final String userType;
  final String? profileImageUrl;
  final String? city;
  final String? commune;
  final int? playerId;
  final double? skillLevel;
  final int? prestige;
  final String? playerSubType;
  final String? playFrequency;
  final String? preferredTimeSlot;
  final String? bio;
  final DateTime? birthDate;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final int matchesPlayed;
  final List<ProfileMatch> matchHistory;

  const UserProfile({
    required this.userId,
    required this.username,
    required this.email,
    required this.userType,
    required this.profileImageUrl,
    required this.city,
    required this.commune,
    required this.playerId,
    required this.skillLevel,
    required this.prestige,
    required this.playerSubType,
    required this.playFrequency,
    required this.preferredTimeSlot,
    required this.bio,
    required this.birthDate,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.matchesPlayed,
    required this.matchHistory,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final matchesJson = json['matchHistory'];

    return UserProfile(
      userId: _asInt(json['userId']) ?? 0,
      username: json['username'] as String? ?? 'Người chơi',
      email: json['email'] as String? ?? '',
      userType: json['userType'] as String? ?? 'User',
      profileImageUrl: json['profileImageUrl'] as String?,
      city: json['city'] as String?,
      commune: json['commune'] as String?,
      playerId: _asInt(json['playerId']),
      skillLevel: _asDouble(json['skillLevel']),
      prestige: _asInt(json['prestige']),
      playerSubType: json['playerSubType'] as String?,
      playFrequency: json['playFrequency'] as String?,
      preferredTimeSlot: json['preferredTimeSlot'] as String?,
      bio: json['bio'] as String?,
      birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
      gender: json['gender'] as String?,
      heightCm: _asDouble(json['heightCm']),
      weightKg: _asDouble(json['weightKg']),
      matchesPlayed: _asInt(json['matchesPlayed']) ?? 0,
      matchHistory: matchesJson is List
          ? matchesJson
              .whereType<Map<String, dynamic>>()
              .map(ProfileMatch.fromJson)
              .toList()
          : const [],
    );
  }

  factory UserProfile.fromAuthUser(AuthUser? user) {
    return UserProfile(
      userId: user?.userId ?? 0,
      username: user?.username ?? 'Người chơi',
      email: user?.email ?? '',
      userType: user?.userType ?? 'User',
      profileImageUrl: user?.profileImageUrl,
      city: user?.city,
      commune: user?.commune,
      playerId: null,
      skillLevel: null,
      prestige: null,
      playerSubType: null,
      playFrequency: null,
      preferredTimeSlot: null,
      bio: null,
      birthDate: null,
      gender: null,
      heightCm: null,
      weightKg: null,
      matchesPlayed: 0,
      matchHistory: const [],
    );
  }
}

class ProfileMatch {
  final int matchId;
  final String matchType;
  final int matchSkillLevel;
  final DateTime? matchTime;
  final String status;
  final String? participantClass;
  final String? venueName;
  final int? courtNumber;
  final String? scoreInfo;
  final String? checkInStatus;

  const ProfileMatch({
    required this.matchId,
    required this.matchType,
    required this.matchSkillLevel,
    required this.matchTime,
    required this.status,
    required this.participantClass,
    required this.venueName,
    required this.courtNumber,
    required this.scoreInfo,
    required this.checkInStatus,
  });

  factory ProfileMatch.fromJson(Map<String, dynamic> json) {
    return ProfileMatch(
      matchId: _asInt(json['matchId']) ?? 0,
      matchType: json['matchType'] as String? ?? 'Match',
      matchSkillLevel: _asInt(json['matchSkillLevel']) ?? 0,
      matchTime: DateTime.tryParse(json['matchTime'] as String? ?? ''),
      status: json['status'] as String? ?? 'Scheduled',
      participantClass: json['participantClass'] as String?,
      venueName: json['venueName'] as String?,
      courtNumber: _asInt(json['courtNumber']),
      scoreInfo: json['scoreInfo'] as String?,
      checkInStatus: json['checkInStatus'] as String?,
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _dateOnly(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
