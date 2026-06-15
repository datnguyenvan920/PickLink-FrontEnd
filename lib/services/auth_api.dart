import 'dart:convert';

import 'package:http/http.dart' as http;

import 'avatar_picker.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5209',
);

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
    final response = await _postJson('/api/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'city': city,
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
        'KhÃ´ng káº¿t ná»‘i Ä‘Æ°á»£c mÃ¡y chá»§. Vui lÃ²ng kiá»ƒm tra backend Ä‘Ã£ cháº¡y á»Ÿ $baseUrl.',
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

class UpdateProfileRequest {
  final String username;
  final String? city;
  final String? profileImageUrl;
  final double skillLevel;
  final String? playerSubType;
  final String? dominantHand;
  final String? preferredPosition;
  final String? bio;

  const UpdateProfileRequest({
    required this.username,
    required this.city,
    required this.profileImageUrl,
    required this.skillLevel,
    required this.playerSubType,
    required this.dominantHand,
    required this.preferredPosition,
    required this.bio,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'city': city,
      'profileImageUrl': profileImageUrl,
      'skillLevel': skillLevel,
      'playerSubType': playerSubType,
      'dominantHand': dominantHand,
      'preferredPosition': preferredPosition,
      'bio': bio,
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
  final int? playerId;
  final double? skillLevel;
  final int? prestige;
  final String? playerSubType;
  final String? dominantHand;
  final String? preferredPosition;
  final String? bio;
  final int matchesPlayed;
  final List<ProfileMatch> matchHistory;

  const UserProfile({
    required this.userId,
    required this.username,
    required this.email,
    required this.userType,
    required this.profileImageUrl,
    required this.city,
    required this.playerId,
    required this.skillLevel,
    required this.prestige,
    required this.playerSubType,
    required this.dominantHand,
    required this.preferredPosition,
    required this.bio,
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
      playerId: _asInt(json['playerId']),
      skillLevel: _asDouble(json['skillLevel']),
      prestige: _asInt(json['prestige']),
      playerSubType: json['playerSubType'] as String?,
      dominantHand: json['dominantHand'] as String?,
      preferredPosition: json['preferredPosition'] as String?,
      bio: json['bio'] as String?,
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
      playerId: null,
      skillLevel: null,
      prestige: null,
      playerSubType: null,
      dominantHand: null,
      preferredPosition: null,
      bio: null,
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
