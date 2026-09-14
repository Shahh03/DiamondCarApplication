import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/config/sentry_config.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('removes private data while preserving stack locations', () {
    final event = SentryEvent.fromJson({
      ...SentryEvent().toJson(),
      'user': {'email': 'PRIVATE_EMAIL'},
      'request': {'data': 'PRIVATE_BODY', 'headers': {'Authorization': 'PRIVATE_TOKEN'}},
      'extra': {'password': 'PRIVATE_PASSWORD'},
      'breadcrumbs': [{'message': 'PRIVATE_BREADCRUMB'}],
      'tags': {'operation': 'setup-test', 'customer': 'PRIVATE_CUSTOMER'},
      'exception': {
        'values': [{
          'type': 'StateError', 'value': 'PRIVATE_ERROR',
          'stacktrace': {
            'frames': [{
              'filename': 'package:project/main.dart?token=PRIVATE_QUERY',
              'function': 'main', 'lineno': 42,
              'vars': {'secret': 'PRIVATE_LOCAL'},
              'context_line': 'PRIVATE_SOURCE',
            }],
          },
        }],
      },
    });
    final result = sanitizeSentryEvent(event).toJson();
    expect(jsonEncode(result), isNot(contains('PRIVATE')));
    final frame = result['exception']['values'][0]['stacktrace']['frames'][0];
    expect(frame['lineno'], 42);
    expect(frame['filename'], 'package:project/main.dart');
    expect(result['tags']['operation'], 'setup-test');
  });

  test('raw messages are replaced for manual events', () {
    final event = SentryEvent(message: SentryMessage('PRIVATE_MESSAGE'));
    final result = jsonEncode(sanitizeSentryEvent(event).toJson());
    expect(result, isNot(contains('PRIVATE_MESSAGE')));
    expect(result, contains('Mobile application event'));
  });
}
