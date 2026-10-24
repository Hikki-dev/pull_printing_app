// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../frontend/lib/services/api_service.dart';
import '../frontend/lib/services/print_repository.dart';

/// Builds an [ApiService] whose server is [handler], and records what was asked.
class _Server {
  _Server(this.handler);
  final http.Response Function(http.Request request) handler;
  final requests = <http.Request>[];

  ApiService get api => ApiService(
        baseUrl: 'https://demo.example/api',
        client: MockClient((request) async {
          requests.add(request);
          return handler(request);
        }),
      );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('demo sign-in sends the admin flag and reads the session from the reply',
      () async {
    final server = _Server((r) => _json({
          'token': 't0k3n',
          'userId': 'demo-1',
          'name': 'Alice Tan',
          'isAdmin': false,
        }));

    final session = await server.api.demoLogin(admin: true);

    expect(server.requests.single.url.toString(),
        'https://demo.example/api/auth/demo-login');
    expect(jsonDecode(server.requests.single.body), {'admin': true});
    expect(session.token, 't0k3n');
    expect(session.name, 'Alice Tan');
    expect(session.isAdmin, isFalse);
  });

  test(
      'held jobs are read from the server\'s JSON, including the offset in the date',
      () async {
    final server = _Server((r) => _json([
          {
            'id': 'a1',
            'userId': 'demo-1',
            'userName': 'Alice Tan',
            'fileName': 'Q3 budget review.pdf',
            'pages': 12,
            'submittedAt': '2026-10-22T09:00:00+00:00',
            'status': 'Held',
            'failureReason': null,
          }
        ]));

    final jobs = await server.api.heldJobs('tok');

    expect(server.requests.single.headers['Authorization'], 'Bearer tok');
    expect(jobs.single.fileName, 'Q3 budget review.pdf');
    expect(jobs.single.pages, 12);
    expect(jobs.single.isHeld, isTrue);
    expect(jobs.single.submittedAt.toUtc(), DateTime.utc(2026, 10, 22, 9));
  });

  test('quota and user list parse the server\'s shape', () async {
    final quota =
        await _Server((r) => _json({'used': 12, 'total': 50, 'left': 38}))
            .api
            .quota('tok');
    expect((quota.used, quota.total, quota.left), (12, 50, 38));

    final users = await _Server((r) => _json([
          {
            'userId': 'u2',
            'name': 'Bob Reyes',
            'quota': {'used': 50, 'total': 50, 'left': 0},
          }
        ])).api.users('tok');
    expect(users.single.name, 'Bob Reyes');
    expect(users.single.quota.left, 0);
  });

  test('printing posts the chosen ids', () async {
    final server = _Server((r) => _json({
          'printed': ['a1'],
          'pages': 12
        }));
    await server.api.release('tok', ['a1', 'b2']);
    expect(server.requests.single.url.path, '/api/jobs/release');
    expect(jsonDecode(server.requests.single.body), {
      'jobIds': ['a1', 'b2']
    });
  });

  test('a 409 quota_exceeded becomes QuotaExceededException with the shortfall',
      () async {
    final server = _Server((r) => _json({
          'error': 'quota_exceeded',
          'message': 'Over your limit by 6 pages.',
          'pagesOver': 6,
        }, 409));
    await expectLater(
      server.api.release('tok', ['a1']),
      throwsA(isA<QuotaExceededException>()
          .having((e) => e.pagesOver, 'pagesOver', 6)),
    );
  });

  test('a 401 becomes SessionExpiredException', () async {
    final server = _Server((r) => http.Response('', 401));
    await expectLater(
        server.api.heldJobs('old'), throwsA(isA<SessionExpiredException>()));
  });

  test('the server\'s own message is passed on for other errors', () async {
    final server = _Server((r) => _json({
          'error': 'bad_request',
          'message': 'Quota must be between 0 and 10000 pages.'
        }, 400));
    await expectLater(
      server.api.setQuota('tok', 'u1', -5),
      throwsA(isA<PrintException>().having(
          (e) => e.message, 'message', contains('between 0 and 10000'))),
    );
  });

  test('a 403 and an unexpected 500 give plain messages', () async {
    await expectLater(
      _Server((r) => http.Response('', 403)).api.allJobs('tok'),
      throwsA(isA<PrintException>()
          .having((e) => e.message, 'message', contains('permission'))),
    );
    await expectLater(
      _Server((r) => http.Response('<html>oops</html>', 500))
          .api
          .allJobs('tok'),
      throwsA(isA<PrintException>()
          .having((e) => e.message, 'message', contains('500'))),
    );
  });

  test('a network failure says the server cannot be reached', () async {
    final api = ApiService(
      baseUrl: 'https://demo.example/api',
      client: MockClient((r) async => throw http.ClientException('offline')),
    );
    await expectLater(
      api.heldJobs('tok'),
      throwsA(isA<PrintException>()
          .having((e) => e.message, 'message', contains('Cannot reach'))),
    );
  });
}
