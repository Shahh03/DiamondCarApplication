import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'authentication/forgot_password.dart';
import 'authentication/login.dart';
import 'authentication/signup.dart';
import 'authentication/welcome.dart';
import 'config/sentry_config.dart';

Future<void> main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final dsn = dotenv.env['SENTRY_DSN']?.trim() ?? '';
  final enabled =
      dotenv.env['SENTRY_ENABLED']?.trim().toLowerCase() == 'true';

  if (!enabled || dsn.isEmpty) {
    await startApplication();
    return;
  }

  await SentryFlutter.init(
    (options) => configureSentry(options, dotenv.env),
    appRunner: () async {
      try {
        await startApplication();
      } catch (error, stackTrace) {
        await Sentry.captureException(
          error,
          stackTrace: stackTrace,
          withScope: (scope) {
            scope.setTag('operation', 'application-startup');
          },
        );

        debugPrint(
          'Application startup failed: ${error.runtimeType}',
        );

        runApp(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not start DiamondCar. '
                    'Please close the app and try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        );

        return;
      }

      if (kDebugMode && const bool.fromEnvironment('SENTRY_TEST')) {
        final eventId = await Sentry.captureException(
          StateError('DiamondCar mobile setup test'),
          stackTrace: StackTrace.current,
          withScope: (scope) {
            scope.setTag('operation', 'setup-test');
          },
        );

        debugPrint('Sentry test captured: $eventId');
      }
    },
  );
}

Future<void> startApplication() async {
  Stripe.publishableKey =
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  Stripe.merchantIdentifier = 'merchant.com.diamondcar';
  Stripe.urlScheme = 'diamondcar';

  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiamondCar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomePage(),
        '/signup': (_) => const SignupPage(),
        '/login': (_) => const LoginPage(),
        '/forgot-password': (_) => const ForgotPasswordPage(),
      },
    );
  }
}