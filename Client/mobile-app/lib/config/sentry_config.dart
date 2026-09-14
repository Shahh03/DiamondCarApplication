import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void configureSentry(
  SentryFlutterOptions options,
  Map<String, String> environment,
) {
  options.dsn = environment['SENTRY_DSN']?.trim() ?? '';
  options.environment = environment['SENTRY_ENVIRONMENT']?.trim().isNotEmpty == true
      ? environment['SENTRY_ENVIRONMENT']!.trim()
      : (kReleaseMode ? 'production' : 'development');
  options.release = 'diamondcar-mobile@1.0.0+1';
  options.sendDefaultPii = false;
  options.debug = kDebugMode;
  options.diagnosticLevel = SentryLevel.debug;
  options.maxBreadcrumbs = 0;
  options.enablePrintBreadcrumbs = false;
  options.attachScreenshot = false;
  options.attachThreads = false;
  options.enableAutoSessionTracking = false;
  options.enableAutoPerformanceTracing = false;
  options.enableLogs = false;
  options.enableMetrics = false;
  options.tracesSampleRate = 0;
  options.captureFailedRequests = false;
  // Dart beforeSend cannot guarantee filtering of native crash envelopes.
  // Keep this first setup Dart/Flutter-only.
  // Keep native initialization for the SDK's delivery transport, while
  // disabling native crash/hang/request collection.
  options.enableNativeCrashHandling = false;
  options.anrEnabled = false;
  options.enableAppHangTracking = false;
  options.captureNativeFailedRequests = false;
  options.enableAutoNativeBreadcrumbs = false;
 //  options.beforeSend = (event, hint) => sanitizeSentryEvent(event);
}

SentryEvent sanitizeSentryEvent(SentryEvent event) {
  final raw = event.toJson();
  final safe = <String, dynamic>{
    for (final key in [
      'event_id', 'timestamp', 'platform', 'level', 'release', 'environment',
    ])
      if (raw[key] != null) key: raw[key],
  };

  // Do not forward the raw exception message, request, user, extra context,
  // breadcrumbs, threads or source snippets: they may contain personal data.
  final exceptions = raw['exception'];
  if (exceptions is Map && exceptions['values'] is List) {
    safe['exception'] = {
      'values': [
        for (final value in exceptions['values'] as List)
          if (value is Map)
            {
              'type': [
                'Exception', 'StateError', 'TypeError', 'RangeError',
                'FormatException', 'FlutterError', 'NoSuchMethodError',
                'AssertionError', 'ArgumentError',
              ].contains(value['type']) ? value['type'] : 'Exception',
              'value': 'Mobile failure — inspect stack and operation tags',
              if (value['stacktrace'] is Map)
                'stacktrace': cleanStack(value['stacktrace'] as Map),
            },
      ],
    };
  } else {
    safe['message'] = {'formatted': 'Mobile application event'};
  }
  if (raw['stacktrace'] is Map) {
    safe['stacktrace'] = cleanStack(raw['stacktrace'] as Map);
  }
  final tags = raw['tags'];
  if (tags is Map && tags['operation'] == 'setup-test') {
    safe['tags'] = {'operation': 'setup-test'};
  }
  return SentryEvent.fromJson(safe);
}

Map<String, dynamic> cleanStack(Map stack) {
  final frames = stack['frames'];
  return {
    'frames': [
      if (frames is List)
        for (final frame in frames)
          if (frame is Map)
            {
              for (final key in ['function', 'lineno', 'colno', 'in_app'])
                if (frame[key] != null) key: frame[key],
              if (frame['filename'] is String)
                'filename': (frame['filename'] as String).split(RegExp(r'[?#]')).first,
            },
    ],
  };
}
