import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildPlatformGoogleWebSignInButton({
  required String label,
  required double minimumWidth,
}) {
  final text = label.toLowerCase().contains('sign up')
      ? google_web.GSIButtonText.signupWith
      : google_web.GSIButtonText.continueWith;

  return google_web.renderButton(
    configuration: google_web.GSIButtonConfiguration(
      type: google_web.GSIButtonType.standard,
      theme: google_web.GSIButtonTheme.outline,
      size: google_web.GSIButtonSize.large,
      text: text,
      shape: google_web.GSIButtonShape.rectangular,
      logoAlignment: google_web.GSIButtonLogoAlignment.left,
      minimumWidth: minimumWidth,
    ),
  );
}
