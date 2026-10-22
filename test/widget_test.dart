// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../frontend/lib/main.dart';
import '../frontend/lib/models/print_job.dart';
import '../frontend/lib/models/session.dart';
import '../frontend/lib/services/mock_print_repository.dart';
import '../frontend/lib/services/print_repository.dart';
import '../frontend/lib/utils/format.dart';
import 'test_fonts.dart';

MockPrintRepository _repo() => MockPrintRepository(latency: Duration.zero);

/// The printer illustration animates forever, so pumpAndSettle would time out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openApp(WidgetTester tester, Size size,
    {MockPrintRepository? repo}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      PullPrintingApp(repository: repo ?? _repo(), fontFamily: 'Roboto'));
  await _settle(tester);
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text('Sign in with Microsoft'));
  await _settle(tester);
}

/// Signs in fine, then the server rejects the token, as after a restart.
class _ExpiredAfterSignIn extends MockPrintRepository {
  _ExpiredAfterSignIn() : super(latency: Duration.zero);

  @override
  Future<List<PrintJob>> myHeldJobs(Session session) async =>
      throw const SessionExpiredException();
}

/// Prints only the first document that was asked for, as when the printer rejects the rest.
class _PartialRepo extends MockPrintRepository {
  _PartialRepo() : super(latency: Duration.zero);

  @override
  Future<List<String>> release(Session session, List<String> jobIds) =>
      super.release(session, [jobIds.first]);
}

/// The printer rejects everything.
class _NothingPrintsRepo extends MockPrintRepository {
  _NothingPrintsRepo() : super(latency: Duration.zero);

  @override
  Future<List<String>> release(Session session, List<String> jobIds) async =>
      [];
}

/// The list on screen is out of date, so the server says the documents are not waiting.
class _StaleListRepo extends MockPrintRepository {
  _StaleListRepo() : super(latency: Duration.zero);

  @override
  Future<List<String>> release(Session session, List<String> jobIds) async =>
      throw const PrintException('Those documents are not waiting to print.');
}

Future<MockPrintRepository> _withQuota(int total) async {
  final repo = _repo();
  await repo.setQuota(
      const Session(token: 't', userId: 'admin', name: 'A', isAdmin: true),
      'u1',
      total);
  return repo;
}

void main() {
  setUpAll(loadTestFonts);

  const phone = Size(390, 844);
  const panel = Size(1024, 600);

  group('phone', () {
    testWidgets(
        'sign-in shows only the user\'s own documents, ticked to fit quota',
        (tester) async {
      await _openApp(tester, phone);
      expect(find.text('Print now.\nCollect at any printer.'), findsOneWidget);

      await _signIn(tester);

      expect(find.text('Alice Tan'), findsOneWidget);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      expect(find.text('Site visit notes.docx'), findsOneWidget);
      expect(find.text('Contract draft v4.pdf'), findsOneWidget);
      expect(find.text('Floor plan.png'), findsOneWidget);
      // Other people's files must never appear.
      expect(find.text('Safety audit.pdf'), findsNothing);
      expect(find.text('report.docx'), findsNothing);

      expect(find.text('Print 2 documents · 15 pages'), findsOneWidget);
      expect(find.text('38'), findsOneWidget); // pages-left ring
    });

    testWidgets('going over quota disables Print and says by how much',
        (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);

      await tester.tap(find.text('Contract draft v4.pdf'));
      await tester.pump(const Duration(milliseconds: 200));

      final blocked = find.text('Over your limit by 5 pages. Untick one.');
      expect(blocked, findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.ancestor(
                  of: blocked, matching: find.byType(FilledButton)))
              .onPressed,
          isNull);

      await tester.tap(find.text('Contract draft v4.pdf'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Print 2 documents · 15 pages'), findsOneWidget);
    });

    testWidgets('unticking everything disables Print', (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);

      await tester.tap(find.text('Q3 budget review.pdf'));
      await tester.tap(find.text('Site visit notes.docx'));
      await tester.pump(const Duration(milliseconds: 200));

      final blocked = find.text('Select a document to print');
      expect(blocked, findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.ancestor(
                  of: blocked, matching: find.byType(FilledButton)))
              .onPressed,
          isNull);
    });

    testWidgets('printing confirms, reduces quota and removes the printed jobs',
        (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);

      await tester.tap(find.text('Print 2 documents · 15 pages'));
      await _settle(tester);

      expect(find.text('Printing at Level 3 East'), findsOneWidget);
      expect(find.text('23 of 50'), findsOneWidget);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);

      await tester.tap(find.text('Back to my documents'));
      await _settle(tester);

      expect(find.text('Q3 budget review.pdf'), findsNothing);
      expect(find.text('Site visit notes.docx'), findsNothing);
      expect(find.text('Contract draft v4.pdf'), findsOneWidget);
      expect(find.text('23'), findsOneWidget); // ring now shows 23 left
    });

    testWidgets('signing out returns to the sign-in screen', (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);
      await tester.tap(find.byTooltip('Sign out'));
      await _settle(tester);
      expect(find.text('Sign in with Microsoft'), findsOneWidget);
    });

    testWidgets('empty state when nothing is waiting', (tester) async {
      final repo = _repo();
      await repo.release(
          const Session(token: 't', userId: 'u1', name: 'Alice Tan'),
          ['1', '2']);
      await repo.setQuota(
          const Session(token: 't', userId: 'admin', name: 'A', isAdmin: true),
          'u1',
          500);
      await repo.release(
          const Session(token: 't', userId: 'u1', name: 'Alice Tan'),
          ['3', '4']);
      await _openApp(tester, phone, repo: repo);
      await _signIn(tester);
      expect(find.text('Nothing waiting to print.'), findsOneWidget);
    });
  });

  group('demo', () {
    testWidgets('the banner explains the demo and its dialog can be opened',
        (tester) async {
      await _openApp(tester, phone);
      expect(find.text('Demo: nothing is really printed.'), findsOneWidget);

      await tester.tap(find.text('What is this?'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Print does not use a real printer'),
          findsOneWidget);
      expect(find.textContaining('Other visitors cannot see them'),
          findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Print does not use a real printer'),
          findsNothing);
    });

    testWidgets(
        'an empty list offers sample documents, and sending them fills it',
        (tester) async {
      final repo = _repo();
      const alice = Session(token: 't', userId: 'u1', name: 'Alice Tan');
      await repo.setQuota(
          const Session(token: 't', userId: 'admin', name: 'A', isAdmin: true),
          'u1',
          500);
      await repo.release(alice, ['1', '2', '3', '4']);

      await _openApp(tester, phone, repo: repo);
      await _signIn(tester);
      expect(find.text('Nothing waiting to print.'), findsOneWidget);

      await tester.tap(find.text('Send sample documents'));
      await _settle(tester);

      expect(find.text('Nothing waiting to print.'), findsNothing);
      expect(find.text('Meeting agenda.docx'), findsOneWidget);
      expect(find.text('Safety checklist.pdf'), findsOneWidget);
    });

    testWidgets('"Send another sample document" adds one to a non-empty list',
        (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);
      expect(find.text('Meeting agenda.docx'), findsNothing);

      await tester.tap(find.text('Send another sample document'));
      await _settle(tester);

      expect(find.text('Meeting agenda.docx'), findsOneWidget);
    });

    testWidgets(
        'a session that has ended sends the user back to sign-in with a message',
        (tester) async {
      await _openApp(tester, phone, repo: _ExpiredAfterSignIn());
      await _signIn(tester);

      expect(find.text('Sign in with Microsoft'), findsOneWidget);
      expect(find.text('Your session has ended. Please sign in again.'),
          findsOneWidget);
    });
  });

  group('small screens', () {
    testWidgets('a 360 x 640 phone shows every screen without overflow',
        (tester) async {
      await _openApp(tester, const Size(360, 640));
      await _signIn(tester);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      await tester.tap(find.textContaining('Print 2 documents'));
      await _settle(tester);
      expect(find.text('Back to my documents'), findsOneWidget);
    });
  });

  group('mistakes people make', () {
    testWidgets('Select all and Clear change every document at once',
        (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);
      expect(find.text('Print 2 documents · 15 pages'), findsOneWidget);

      await tester.tap(find.text('Select all'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Over your limit by 6 pages. Untick one.'),
          findsOneWidget); // 44 pages, 38 left

      await tester.tap(find.text('Clear')); // the button now unticks everything
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Select a document to print'), findsOneWidget);
    });

    testWidgets('one long document says what it needs and what is left',
        (tester) async {
      await _openApp(tester, phone, repo: await _withQuota(20)); // 8 pages left
      await _signIn(tester);
      expect(find.text('Select a document to print'),
          findsOneWidget); // nothing fits, so nothing is ticked

      await tester.tap(find.text('Contract draft v4.pdf'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('This document needs 28 pages. You have 8 left.'),
          findsOneWidget);
      expect(find.textContaining('Demo tip'), findsOneWidget);
    });

    testWidgets('no pages left is said plainly', (tester) async {
      await _openApp(tester, phone, repo: await _withQuota(12)); // 0 left
      await _signIn(tester);
      await tester.tap(find.text('Floor plan.png'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No pages left this month.'), findsOneWidget);
    });

    testWidgets(
        'when only some documents print, the rest are named as still waiting',
        (tester) async {
      await _openApp(tester, phone, repo: _PartialRepo());
      await _signIn(tester);
      await tester.tap(find.text('Print 2 documents · 15 pages'));
      await _settle(tester);

      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      expect(find.text('Site visit notes.docx'), findsNothing);
      expect(find.text('1 document could not be printed and is still waiting.'),
          findsOneWidget);
      expect(find.text('26 of 50'),
          findsOneWidget); // only the 12 printed pages were used
    });

    testWidgets(
        'if nothing prints the person stays on their list with a message',
        (tester) async {
      await _openApp(tester, phone, repo: _NothingPrintsRepo());
      await _signIn(tester);
      await tester.tap(find.text('Print 2 documents · 15 pages'));
      await _settle(tester);

      expect(find.textContaining('The printer could not print your documents'),
          findsOneWidget);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      expect(find.text('Print 2 documents · 15 pages'), findsOneWidget);
    });

    testWidgets(
        'an out-of-date list is refreshed when the server says the documents are gone',
        (tester) async {
      await _openApp(tester, phone, repo: _StaleListRepo());
      await _signIn(tester);
      await tester.tap(find.text('Print 2 documents · 15 pages'));
      await _settle(tester);

      expect(
          find.textContaining('Your list has been refreshed.'), findsOneWidget);
    });

    testWidgets(
        'Start over gives fresh sample documents after everything was printed',
        (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);
      await tester.tap(find.text('Print 2 documents · 15 pages'));
      await _settle(tester);
      await tester.tap(find.text('Back to my documents'));
      await _settle(tester);
      expect(find.text('Q3 budget review.pdf'), findsNothing);

      await tester.tap(find.text('What is this?'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Start over'));
      await _settle(tester);
      expect(find.text('Started over with fresh sample documents.'),
          findsOneWidget);

      await _signIn(tester);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      expect(find.text('Print 2 documents · 15 pages'), findsOneWidget);
    });

    testWidgets('the printer panel signs out someone who walks away',
        (tester) async {
      await _openApp(tester, panel);
      await _signIn(tester);
      expect(find.text('Your documents'), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));
      await _settle(tester);
      expect(find.text('Sign in to collect your prints'), findsOneWidget);
      expect(find.text('You were signed out because the screen was idle.'),
          findsOneWidget);
    });

    testWidgets('touching the printer panel keeps the person signed in',
        (tester) async {
      await _openApp(tester, panel);
      await _signIn(tester);

      await tester.pump(const Duration(seconds: 45));
      await tester.tap(
          find.text('Contract draft v4.pdf')); // a touch restarts the countdown
      await tester.pump(const Duration(seconds: 45));
      expect(find.text('Your documents'), findsOneWidget);

      await tester.pump(const Duration(seconds: 20));
      await _settle(tester);
      expect(find.text('Sign in to collect your prints'), findsOneWidget);
    });

    testWidgets('a phone does not sign anyone out for being idle',
        (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);
      await tester.pump(const Duration(seconds: 120));
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
    });
  });

  group('large text and small screens', () {
    for (final scale in [1.5, 2.0]) {
      testWidgets('every phone screen copes with text at ${scale}x',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await _openApp(tester, phone);
        expect(find.textContaining('Collect at any printer'), findsOneWidget);
        await _signIn(tester);
        expect(find.text('Q3 budget review.pdf'), findsOneWidget);

        await tester.tap(find.textContaining('Print 2 documents'));
        await _settle(tester);
        expect(find.text('Back to my documents'), findsOneWidget);
      });
    }

    testWidgets('the printer panel copes with larger text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openApp(tester, panel);
      await _signIn(tester);
      expect(find.text('Your documents'), findsOneWidget);
      await tester.tap(find.text('Print'));
      await _settle(tester);
      expect(find.textContaining('Printing 15 pages'), findsOneWidget);
    });

    testWidgets('the admin screen works on a phone', (tester) async {
      await _openApp(tester, phone);
      await tester.tap(find.text('Demo: sign in as administrator'));
      await _settle(tester);
      expect(find.text('Pull Print Admin'), findsOneWidget);
      expect(find.text('All jobs'), findsOneWidget);
    });
  });

  group('printer panel', () {
    testWidgets('sign in, print, then sign out automatically', (tester) async {
      await _openApp(tester, panel);
      expect(find.text('Sign in to collect your prints'), findsOneWidget);

      await _signIn(tester);
      expect(find.text('Your documents'), findsOneWidget);
      expect(find.text('2 documents · 15 pages'), findsOneWidget);
      expect(find.text('23 pages left after printing'), findsOneWidget);

      await tester.tap(find.text('Print'));
      await _settle(tester);
      expect(find.text('Printing 15 pages'), findsOneWidget);

      await tester.pump(const Duration(seconds: 21));
      await _settle(tester);
      expect(find.text('Sign in to collect your prints'), findsOneWidget);
    });

    testWidgets('over quota shows the shortfall and blocks Print',
        (tester) async {
      await _openApp(tester, panel);
      await _signIn(tester);
      await tester.tap(find.text('Contract draft v4.pdf'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
          find.text('Over your limit by 5 pages. Untick one.'), findsOneWidget);
      expect(find.text('Over your limit'), findsOneWidget);
    });
  });

  group('admin', () {
    testWidgets('lists jobs, filters, and saves a quota', (tester) async {
      final repo = _repo();
      await _openApp(tester, const Size(1280, 1000), repo: repo);
      await tester.tap(find.text('Demo: sign in as administrator'));
      await _settle(tester);

      expect(find.text('Pull Print Admin'), findsOneWidget);
      expect(find.text('Safety audit.pdf'), findsOneWidget);
      expect(find.text('Failed: printer offline'), findsOneWidget);
      expect(find.text('Waiting to print'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Search user or file'), 'priya');
      await tester.pump();
      expect(find.text('Safety audit.pdf'), findsOneWidget);
      expect(find.text('Q3 budget review.pdf'), findsNothing);

      await tester.enterText(
          find.widgetWithText(TextField, 'Search user or file'), 'zzz');
      await tester.pump();
      expect(find.text('No jobs match.'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);

      // Bob is out of quota; give him 80 pages.
      final bobField = find.widgetWithText(TextField, 'Pages per month').at(1);
      await tester.ensureVisible(bobField);
      await tester.enterText(bobField, '80');
      await tester.tap(find.text('Save').at(1));
      await _settle(tester);
      expect(find.text('Quota for Bob Reyes set to 80 pages.'), findsOneWidget);

      final bob = (await repo.users(const Session(
              token: 't', userId: 'admin', name: 'A', isAdmin: true)))
          .firstWhere((u) => u.userId == 'u2');
      expect(bob.quota.total, 80);
    });
  });

  group('repository', () {
    const alice = Session(token: 't', userId: 'u1', name: 'Alice Tan');
    const admin =
        Session(token: 't', userId: 'admin', name: 'A', isAdmin: true);

    test('release rejects jobs that do not fit the quota and changes nothing',
        () async {
      final repo = _repo();
      expect(
        () => repo.release(alice, ['1', '2', '3']), // 43 pages, 38 left
        throwsA(isA<QuotaExceededException>()
            .having((e) => e.pagesOver, 'over', 5)),
      );
      expect((await repo.myHeldJobs(alice)).length, 4);
      expect((await repo.myQuota(alice)).used, 12);
    });

    test('release marks jobs printed and uses up pages', () async {
      final repo = _repo();
      await repo.release(alice, ['1', '2']);
      expect((await repo.myHeldJobs(alice)).map((j) => j.id), ['3', '4']);
      expect((await repo.myQuota(alice)).left, 23);
    });

    test('a user cannot release someone else\'s job', () async {
      final repo = _repo();
      expect(() => repo.release(alice, ['6']), throwsA(isA<PrintException>()));
    });

    test('admin endpoints refuse non-admins', () async {
      final repo = _repo();
      expect(() => repo.allJobs(alice), throwsA(isA<PrintException>()));
      expect(() => repo.setQuota(alice, 'u1', 999),
          throwsA(isA<PrintException>()));
      expect((await repo.allJobs(admin)).length, 7);
    });
  });

  group('format', () {
    test('whenLabel', () {
      final now = DateTime(2026, 10, 22, 12);
      expect(whenLabel(DateTime(2026, 10, 22, 9, 2), now: now), 'Today 9:02');
      expect(whenLabel(DateTime(2026, 10, 21, 23), now: now), 'Yesterday');
      expect(whenLabel(DateTime(2026, 10, 3), now: now), '3 Oct');
    });

    test('initials and greeting', () {
      expect(initials('Alice Tan'), 'AT');
      expect(initials('Madonna'), 'M');
      expect(greeting(now: DateTime(2026, 1, 1, 8)), 'Good morning');
      expect(greeting(now: DateTime(2026, 1, 1, 20)), 'Good evening');
    });
  });
}
