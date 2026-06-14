import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final response = await _client.post(
      _uri('/api/auth/google'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'idToken': idToken,
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
