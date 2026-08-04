import 'package:flutter/material.dart';

import 'api/auth_api.dart';
import 'welcome.dart';

Future<void> logoutAndReturnToWelcome(BuildContext context) async {
  await AuthApi.logout();
  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const WelcomePage()),
    (_) => false,
  );
}
