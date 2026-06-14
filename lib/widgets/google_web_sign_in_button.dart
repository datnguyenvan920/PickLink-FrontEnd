import 'package:flutter/widgets.dart';

import 'google_web_sign_in_button_stub.dart'
    if (dart.library.html) 'google_web_sign_in_button_web.dart';

Widget buildGoogleWebSignInButton({
  required String label,
  double minimumWidth = 400,
}) {
  return buildPlatformGoogleWebSignInButton(
    label: label,
    minimumWidth: minimumWidth,
  );
}
