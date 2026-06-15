import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const googleOAuthClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID',
  defaultValue:
      '1543482023-dphgeq4v2hkah4lmno45436j5bpkf696.apps.googleusercontent.com',
);

class GoogleSignInService {
  GoogleSignInService._();

  static final instance = GoogleSignInService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final _idTokenController = StreamController<String>.broadcast();
  final _errorController = StreamController<Object>.broadcast();

  Future<void>? _initializeFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventSubscription;

  Stream<String> get idTokens {
    unawaited(
      initialize().catchError((Object error, StackTrace stackTrace) {
        if (!kIsWeb) {
          _errorController.add(error);
        }
      }),
    );
    return _idTokenController.stream;
  }

  Stream<Object> get errors => _errorController.stream;

  Future<void> initialize() {
    _initializeFuture ??= _initialize().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _initializeFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
    return _initializeFuture!;
  }

  Future<String> signInAndGetIdToken() async {
    await initialize();

    if (!_googleSignIn.supportsAuthenticate()) {
      if (kIsWeb) {
        throw const GoogleSignInFlowException(
          'Vui lòng dùng nút Google để tiếp tục.',
        );
      }

      throw const GoogleSignInFlowException(
        'Thiết bị này không hỗ trợ đăng nhập bằng Google.',
      );
    }

    final account = await _googleSignIn.authenticate();
    return _idTokenFromAccount(account);
  }

  Future<void> _initialize() async {
    await _googleSignIn.initialize(
      clientId: kIsWeb ? googleOAuthClientId : null,
      serverClientId: kIsWeb ? null : googleOAuthClientId,
    );

    _eventSubscription ??= _googleSignIn.authenticationEvents.listen(
      _handleAuthenticationEvent,
      onError: _errorController.add,
    );
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      _idTokenController.add(_idTokenFromAccount(event.user));
    }
  }

  String _idTokenFromAccount(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInFlowException(
        'Google không trả về mã đăng nhập hợp lệ. Vui lòng thử lại.',
      );
    }

    return idToken;
  }
}

class GoogleSignInFlowException implements Exception {
  final String message;

  const GoogleSignInFlowException(this.message);

  @override
  String toString() => message;
}
