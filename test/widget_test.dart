// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../frontend/lib/main.dart';
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

Future<void> _openApp(WidgetTester tester, Size size, {MockPrintRepository? repo}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PullPrintingApp(repository: repo ?? _repo(), fontFamily: 'Roboto'));
  await _settle(tester);
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.text('Sign in with Microsoft'));
  await _settle(tester);
}

void main() {
  setUpAll(loadTestFonts);

  const phone = Size(390, 844);
  const panel = Size(1024, 600);

  group('phone', () {
    testWidgets('sign-in shows only the user\'s own documents, ticked to fit quota',
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

    testWidgets('going over quota disables Print and says by how much', (tester) async {
      await _openApp(tester, phone);
      await _signIn(tester);

      await tester.tap(find.text('Contract draft v4.pdf'));
      await tester.pump(const Duration(milliseconds: 200));

      final blocked = find.text('Over your limit by 5 pages. Untick one.');
      expect(blocked, findsOneWidget);
      expect(tester.widget<FilledButton>(find.ancestor(of: blocked, matching: find.byType(FilledButton))).onPressed,
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
      expect(tester.widget<FilledButton>(find.ancestor(of: blocked, matching: find.byType(FilledButton))).onPressed,
          isNull);
    });

    testWidgets('printing confirms, reduces quota and removes the printed jobs', (tester) async {
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
          const Session(token: 't', userId: 'u1', name: 'Alice Tan'), ['1', '2']);
      await repo.setQuota(
          const Session(token: 't', userId: 'admin', name: 'A', isAdmin: true), 'u1', 500);
      await repo.release(
          const Session(token: 't', userId: 'u1', name: 'Alice Tan'), ['3', '4']);
      await _openApp(tester, phone, repo: repo);
      await _signIn(tester);
      expect(find.text('Nothing waiting to print.'), findsOneWidget);
    });
  });

  group('small screens', () {
    testWidgets('a 360 x 640 phone shows every screen without overflow', (tester) async {
      await _openApp(tester, const Size(360, 640));
      await _signIn(tester);
      expect(find.text('Q3 budget review.pdf'), findsOneWidget);
      await tester.tap(find.textContaining('Print 2 documents'));
      await _settle(tester);
      expect(find.text('Back to my documents'), findsOneWidget);
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

    testWidgets('over quota shows the shortfall and blocks Print', (tester) async {
      await _openApp(tester, panel);
      await _signIn(tester);
      await tester.tap(find.text('Contract draft v4.pdf'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('5 pages over your limit'), findsOneWidget);
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

      await tester.enterText(find.widgetWithText(TextField, 'Search user or file'), 'priya');
      await tester.pump();
      expect(find.text('Safety audit.pdf'), findsOneWidget);
      expect(find.text('Q3 budget review.pdf'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Search user or file'), 'zzz');
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
    const admin = Session(token: 't', userId: 'admin', name: 'A', isAdmin: true);

    test('release rejects jobs that do not fit the quota and changes nothing', () async {
      final repo = _repo();
      expect(
        () => repo.release(alice, ['1', '2', '3']), // 43 pages, 38 left
        throwsA(isA<QuotaExceededException>().having((e) => e.pagesOver, 'over', 5)),
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
      expect(() => repo.setQuota(alice, 'u1', 999), throwsA(isA<PrintException>()));
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
