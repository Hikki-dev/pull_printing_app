// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../frontend/lib/main.dart';
import '../frontend/lib/models/printer.dart';
import '../frontend/lib/models/session.dart';
import '../frontend/lib/services/api_service.dart';
import '../frontend/lib/services/http_print_repository.dart';
import '../frontend/lib/services/mock_print_repository.dart';
import '../frontend/lib/services/print_repository.dart';
import '../frontend/lib/utils/constants.dart';
import 'test_fonts.dart';

/// A server that signs people in with a work account, as when Microsoft or Google is set up.
class _WorkspaceRepo extends MockPrintRepository {
  _WorkspaceRepo({this.config, this.comeBack, this.turnedAway})
      : super(latency: Duration.zero);

  final AuthConfig? config;

  /// The session the browser returns with, as after signing in at Microsoft or Google.
  final Session? comeBack;
  final String? turnedAway;
  int workspaceSignIns = 0;
  final released = <String?>[];

  @override
  Future<AuthConfig> authConfig() async =>
      config ??
      const AuthConfig(provider: 'google', domain: 'example.com', demo: false);

  @override
  void startWorkspaceSignIn() => workspaceSignIns++;

  @override
  Future<Session?> resumeSignIn() async {
    if (turnedAway != null) throw PrintException(turnedAway!);
    return comeBack;
  }

  @override
  Future<List<String>> release(Session session, List<String> jobIds,
      {String? printerId}) {
    released.add(printerId);
    return super.release(session, jobIds, printerId: printerId);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _open(WidgetTester tester, Size size, PrintRepository repo) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester
      .pumpWidget(PullPrintingApp(repository: repo, fontFamily: 'Roboto'));
  await _settle(tester);
}

const _admin = Session(
    token: 't', userId: 'admin', name: 'Admin', isAdmin: true, demo: false);

void main() {
  setUpAll(loadTestFonts);
  const phone = Size(390, 844);

  group('sign-in options', () {
    testWidgets('a Google workspace offers Google and no demo', (tester) async {
      final repo = _WorkspaceRepo();
      await _open(tester, phone, repo);

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Microsoft'), findsNothing);
      expect(find.textContaining('@example.com'), findsOneWidget);
      expect(find.text('Demo: sign in as administrator'), findsNothing);
      expect(find.text('Demo: nothing is really printed.'), findsNothing);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();
      expect(repo.workspaceSignIns, 1);
    });

    testWidgets('a Microsoft workspace offers Microsoft', (tester) async {
      final repo = _WorkspaceRepo(
          config: const AuthConfig(provider: 'microsoft', demo: false));
      await _open(tester, phone, repo);
      expect(find.text('Sign in with Microsoft'), findsOneWidget);
      expect(
          find.text('Use your work account. No new password.'), findsOneWidget);
    });

    testWidgets('a workspace that keeps the demo on offers both',
        (tester) async {
      final repo = _WorkspaceRepo(
          config: const AuthConfig(provider: 'google', demo: true));
      await _open(tester, phone, repo);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Try the demo instead'), findsOneWidget);

      await tester.tap(find.text('Try the demo instead'));
      await _settle(tester);
      expect(find.text('Alice Tan'), findsOneWidget);
    });

    testWidgets('coming back from sign-in lands on the person\'s documents',
        (tester) async {
      final repo = _WorkspaceRepo(
          comeBack: const Session(
              token: 't', userId: 'u1', name: 'Alice Tan', demo: false));
      await _open(tester, phone, repo);
      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      // A real work account is not told it is a demo.
      expect(find.text('Demo: nothing is really printed.'), findsNothing);
      expect(Constants.demoMode, isFalse);
    });

    testWidgets('a turned-away account sees the reason and can try again',
        (tester) async {
      final repo = _WorkspaceRepo(turnedAway: 'That account is not allowed.');
      await _open(tester, phone, repo);
      expect(find.text('That account is not allowed.'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('when the server cannot be reached the person can try again',
        (tester) async {
      final repo = _OfflineRepo();
      await _open(tester, phone, repo);
      expect(find.text('Cannot reach the print server.'), findsOneWidget);
      repo.online = true;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.text('Sign in with Microsoft'), findsOneWidget);
    });
  });

  group('printers', () {
    testWidgets('the person picks a printer and the confirmation names it',
        (tester) async {
      final repo = _WorkspaceRepo(
          config: const AuthConfig(demo: true),
          comeBack: const Session(
              token: 't', userId: 'u1', name: 'Alice Tan', demo: false));
      await _open(tester, phone, repo);
      expect(find.text('Level 3 East'), findsOneWidget);

      await tester.tap(find.text('Level 3 East'));
      await _settle(tester);
      await tester.tap(find.text('Reception'));
      await _settle(tester);
      await tester.tap(find.textContaining('Print 2 documents'));
      await _settle(tester);

      expect(repo.released, ['p2']);
      expect(find.text('Printing at Reception'), findsOneWidget);
    });

    testWidgets('with no printers set up nobody can print', (tester) async {
      final repo = _NoPrintersRepo(
          comeBack: const Session(
              token: 't', userId: 'u1', name: 'Alice Tan', demo: false));
      await _open(tester, phone, repo);
      expect(find.text('No printer available'), findsOneWidget);
      expect(find.text('None set up yet'), findsOneWidget);
    });
  });

  group('admin setup', () {
    testWidgets('the administrator adds, switches off and removes printers',
        (tester) async {
      final repo = MockPrintRepository(latency: Duration.zero);
      await _open(tester, const Size(1280, 1400), repo);
      await tester.tap(find.text('Demo: sign in as administrator'));
      await _settle(tester);

      expect(find.text('Setup is complete'), findsOneWidget);
      expect(find.text('Reception'), findsOneWidget);

      await tester.tap(find.text('Add a printer'));
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Studio');
      await tester.tap(find.text('Add printer'));
      await _settle(tester);
      expect(find.text('Studio'), findsOneWidget);
      expect((await repo.printers(_admin)).length, 4);

      await tester.tap(find.byType(Switch).first);
      await _settle(tester);
      expect((await repo.printers(_admin)).first.enabled, isFalse);

      await tester.tap(find.byTooltip('Remove Studio'));
      await _settle(tester);
      await tester.tap(find.text('Remove'));
      await _settle(tester);
      expect(find.text('Studio'), findsNothing);
    });

    testWidgets('quota rules: a default for new people and one for everyone',
        (tester) async {
      final repo = MockPrintRepository(latency: Duration.zero);
      await _open(tester, const Size(1280, 1400), repo);
      await tester.tap(find.text('Demo: sign in as administrator'));
      await _settle(tester);

      final fields = find.widgetWithText(TextField, 'Pages per month');
      await tester.enterText(fields.at(0), '120');
      await tester.tap(find.text('Save').first);
      await _settle(tester);
      expect(find.text('New people will start with 120 pages a month.'),
          findsOneWidget);

      await tester.enterText(fields.at(1), '75');
      await tester.tap(find.text('Apply to everyone'));
      await _settle(tester);
      // Asks first, because it replaces every limit.
      expect(find.text('Give everyone 75 pages a month?'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Apply to everyone')));
      await _settle(tester);
      expect(find.text('4 people now have 75 pages.'), findsOneWidget);
      expect(
          (await repo.users(_admin)).every((u) => u.quota.total == 75), isTrue);
    });

    testWidgets('a quota that is not a number is refused', (tester) async {
      final repo = MockPrintRepository(latency: Duration.zero);
      await _open(tester, const Size(1280, 1400), repo);
      await tester.tap(find.text('Demo: sign in as administrator'));
      await _settle(tester);
      await tester.enterText(
          find.widgetWithText(TextField, 'Pages per month').at(1), 'lots');
      await tester.tap(find.text('Apply to everyone'));
      await _settle(tester);
      expect(find.text('Enter a whole number of pages, from 0 to 100000.'),
          findsOneWidget);
    });
  });

  group('browser hand-over', () {
    http.Client noServer() => MockClient((r) async => http.Response('{}', 200));

    HttpPrintRepository repo(String url,
        {List<String>? went, List<int>? cleared, http.Client? client}) {
      return HttpPrintRepository(
        api: ApiService(
            baseUrl: 'https://p.example/api', client: client ?? noServer()),
        location: () => Uri.parse(url),
        navigate: (u) => went?.add(u),
        clearFragment: () => cleared?.add(1),
      );
    }

    test('the sign-in link keeps the printer panel\'s address', () {
      final went = <String>[];
      repo('https://p.example/?printer=p2', went: went).startWorkspaceSignIn();
      expect(went.single,
          'https://p.example/api/auth/login?returnTo=%2F%3Fprinter%3Dp2');
      final plain = <String>[];
      repo('https://p.example/', went: plain).startWorkspaceSignIn();
      expect(plain.single, 'https://p.example/api/auth/login?returnTo=%2F');
    });

    test('the printer in the address is the panel\'s printer', () {
      expect(repo('https://p.example/?printer=p2').panelPrinterId, 'p2');
      expect(repo('https://p.example/').panelPrinterId, isNull);
      expect(repo('https://p.example/?printer=').panelPrinterId, isNull);
    });

    test('the token is read from the address, then removed from it', () async {
      final cleared = <int>[];
      final client = MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer abc.def-ghi_jkl');
        return http.Response(
            jsonEncode({'userId': 'g-1', 'name': 'Pat', 'isAdmin': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      final session = await repo(
              'https://p.example/?printer=p2#token=abc.def-ghi_jkl',
              cleared: cleared,
              client: client)
          .resumeSignIn();
      expect(session!.name, 'Pat');
      expect(session.isAdmin, isTrue);
      expect(session.demo, isFalse);
      expect(cleared, hasLength(1));
    });

    test('nothing to resume when the address has no sign-in result', () async {
      final cleared = <int>[];
      expect(await repo('https://p.example/', cleared: cleared).resumeSignIn(),
          isNull);
      expect(cleared, isEmpty);
    });

    test('every reason for being turned away is explained', () async {
      for (final code in [
        'wrong_account',
        'unverified_email',
        'no_identity',
        'sign_in_failed'
      ]) {
        final cleared = <int>[];
        await expectLater(
          repo('https://p.example/#error=$code', cleared: cleared)
              .resumeSignIn(),
          throwsA(isA<PrintException>().having((e) => e.message, 'message',
              HttpPrintRepository.signInProblem(code))),
        );
        expect(cleared, hasLength(1));
      }
      expect(HttpPrintRepository.signInProblem('wrong_account'),
          isNot(HttpPrintRepository.signInProblem('sign_in_failed')));
    });
  });

  group('server calls', () {
    final requests = <http.Request>[];
    ApiService api(Object body) => ApiService(
        baseUrl: 'https://p.example/api',
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode(body), 200,
              headers: {'content-type': 'application/json'});
        }));

    setUp(requests.clear);

    test('the sign-in options are read before anyone signs in', () async {
      final config = await api({
        'provider': 'google',
        'providerName': 'Google',
        'domain': 'example.com',
        'demo': false
      }).authConfig();
      expect(requests.single.url.path, '/api/auth/config');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(config.provider, 'google');
      expect(config.domain, 'example.com');
      expect(config.demo, isFalse);
      expect(config.hasWorkspace, isTrue);
    });

    test('releasing names the printer', () async {
      await api({
        'printed': ['1']
      }).release('t', ['1'], printerId: 'p2');
      expect(jsonDecode(requests.single.body), {
        'jobIds': ['1'],
        'printerId': 'p2'
      });
      requests.clear();
      await api({
        'printed': ['1']
      }).release('t', ['1']);
      expect(jsonDecode(requests.single.body), {
        'jobIds': ['1']
      });
    });

    test('printers are listed', () async {
      final list = await api([
        {'id': 'p1', 'name': 'Level 3', 'location': 'East', 'enabled': true},
        {'id': 'p2', 'name': 'Old', 'location': '', 'enabled': false}
      ]).printers('t');
      expect(list.map((p) => p.name), ['Level 3', 'Old']);
      expect(list.last.enabled, isFalse);
    });

    test('setup and quota rules go to the right places', () async {
      final setup = await api({
        'provider': 'Google',
        'domain': 'example.com',
        'demoEnabled': false,
        'defaultQuota': 50,
        'people': 3,
        'printers': 0,
        'redirectUri': 'https://p.example/api/auth/callback',
        'warnings': ['No printers yet.']
      }).setup('t');
      expect(requests.single.url.path, '/api/admin/setup');
      expect(setup.warnings, ['No printers yet.']);
      expect(setup.hasWorkspace, isTrue);

      requests.clear();
      await api({}).setDefaultQuota('t', 80);
      expect(requests.single.url.path, '/api/admin/default-quota');
      expect(jsonDecode(requests.single.body), {'quota': 80});

      requests.clear();
      final changed = await api({'changed': 7}).setQuotaForAll('t', 30);
      expect(requests.single.url.path, '/api/admin/set-quota-all');
      expect(changed, 7);
    });

    test('printers are added, changed and removed', () async {
      final added = await api(
              {'id': 'p9', 'name': 'Studio', 'location': 'L1', 'enabled': true})
          .addPrinter('t', 'Studio', 'L1');
      expect(requests.single.method, 'POST');
      expect(added.id, 'p9');

      requests.clear();
      await api({}).updatePrinter('t', added);
      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, '/api/admin/printers/p9');
      expect(jsonDecode(requests.single.body),
          {'name': 'Studio', 'location': 'L1', 'enabled': true});

      requests.clear();
      await api({}).deletePrinter('t', 'p9');
      expect(requests.single.method, 'DELETE');
    });
  });
}

class _OfflineRepo extends MockPrintRepository {
  _OfflineRepo() : super(latency: Duration.zero);
  bool online = false;

  @override
  Future<AuthConfig> authConfig() async {
    if (!online) throw const PrintException('Cannot reach the print server.');
    return AuthConfig.demoOnly;
  }
}

class _NoPrintersRepo extends _WorkspaceRepo {
  _NoPrintersRepo({super.comeBack});

  @override
  Future<List<Printer>> printers(Session session) async => const [];
}
