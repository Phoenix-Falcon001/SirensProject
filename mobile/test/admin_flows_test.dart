import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sirens/ui/app.dart';
import 'package:sirens/ui/staff/users_screen.dart';

import 'fake_server.dart';

Future<void> signIn(WidgetTester tester, FakeServers server, {String lang = 'en'}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final state = server.newState();
  await state.init();
  await state.setLanguage(lang);
  await state.signInStaff('admin', 'correct-horse-1');
  await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('generated passwords are long enough and unambiguous', () {
    final p = generatePassword();
    expect(p.length, 14);
    expect(p, isNot(matches(RegExp('[0O1lI]'))));
    expect(generatePassword(), isNot(p));
  });

  testWidgets('civilian report: photo, MGRS, call, status change', (tester) async {
    final server = FakeServers();
    await signIn(tester, server);
    await tapKey(tester, 'tile-civil_reports');
    expect(find.byKey(const Key('civil-CR-1')), findsOneWidget);
    await tapKey(tester, 'civil-CR-1');
    expect(find.text('Rocket in the olive grove'), findsOneWidget);
    expect(find.byKey(const Key('civil-photo')), findsOneWidget);
    expect(find.text('MGRS 36S YB 049 833'), findsOneWidget);
    await tapKey(tester, 'call-reporter');
    expect(server.device.dialed, ['+9613123456']);

    await tapKey(tester, 'set-status');
    await tapKey(tester, 'status-under_review');
    await tester.enterText(find.byKey(const Key('status-note')), 'Patrol sent');
    await tapKey(tester, 'status-save');
    expect(server.civil['CR-1']!['status'], 'under_review');
    expect(server.civil['CR-1']!['status_note'], 'Patrol sent');
    expect(find.text('Status saved. The civilian sees it after the next sync.'), findsOneWidget);
  });

  testWidgets('civilian report becomes a pre-filled military report', (tester) async {
    final server = FakeServers();
    await signIn(tester, server);
    await tapKey(tester, 'tile-civil_reports');
    await tapKey(tester, 'civil-CR-1');
    await tapKey(tester, 'to-report');
    expect(find.textContaining('From civilian report CR-1'), findsOneWidget);
    expect(find.text('MGRS 36S YB 049 833'), findsOneWidget);
    await tapKey(tester, 'file-report');
    final body = server.filed.single;
    expect(body['caza'], 'Sour');
    expect(body['narrative'], contains('Rocket in the olive grove'));
    expect(body['lat'], 33.27);
  });

  testWidgets('status filter hides handled reports', (tester) async {
    final server = FakeServers();
    server.civil['CR-1']!['status'] = 'closed';
    await signIn(tester, server);
    await tapKey(tester, 'tile-civil_reports');
    expect(find.byKey(const Key('civil-CR-1')), findsNothing); // default: received only
    expect(find.text('No civilian reports in your regions.'), findsOneWidget);
    await tapKey(tester, 'civil-filter-all');
    expect(find.byKey(const Key('civil-CR-1')), findsOneWidget);
  });

  testWidgets('publish a warning in two languages, then withdraw it', (tester) async {
    final server = FakeServers();
    await signIn(tester, server);
    await tapKey(tester, 'tile-warnings');
    expect(find.text('No warnings.'), findsOneWidget);
    await tapKey(tester, 'new-warning');
    await tester.tap(find.byKey(const Key('warn-caza')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sour').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'warn-sev-danger');
    await tapKey(tester, 'warn-hours-72');
    // Title without text in English: refused.
    await tester.enterText(find.byKey(const Key('warn-title-en')), 'Avoid the coast road');
    await tapKey(tester, 'warn-publish');
    expect(
      find.text('Write the title and text in at least one language, the same one.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('warn-body-en')),
      'Keep away until further notice.',
    );
    await tester.enterText(find.byKey(const Key('warn-title-ar')), 'تجنّب الطريق الساحلي');
    await tester.enterText(find.byKey(const Key('warn-body-ar')), 'ابتعد حتى إشعار آخر.');
    await tapKey(tester, 'warn-publish');
    final w = server.staffWarnings.single;
    expect(w['caza'], 'Sour');
    expect(w['severity'], 'danger');
    expect((w['title'] as Map).keys, unorderedEquals(['en', 'ar']));
    final hours = DateTime.parse(w['expires_at'] as String).difference(DateTime.now()).inHours;
    expect(hours, inInclusiveRange(71, 72));
    expect(find.byKey(const Key('staff-warning-1')), findsOneWidget);

    await tapKey(tester, 'withdraw-1');
    await tapKey(tester, 'withdraw-confirm');
    expect(w['withdrawn'], isTrue);
    expect(find.byKey(const Key('withdraw-1')), findsNothing);
    expect(find.text('Expired or withdrawn'), findsOneWidget);
  });

  testWidgets('create a military account with level and regions', (tester) async {
    final server = FakeServers();
    await signIn(tester, server);
    await tapKey(tester, 'tile-users');
    expect(find.byKey(const Key('user-field1')), findsOneWidget);
    await tapKey(tester, 'new-user');
    await tester.enterText(find.byKey(const Key('new-username')), 'lt_nader');
    await tester.enterText(find.byKey(const Key('new-display-name')), 'Lt. Nader');
    await tapKey(tester, 'level-commander');
    await tapKey(tester, 'user-save');
    expect(find.text('Regions (at least one)'), findsWidgets); // none picked yet
    await tapKey(tester, 'region-Saida');
    await tapKey(tester, 'region-Sour');
    await tapKey(tester, 'user-save');
    final u = server.adminUsers.last;
    expect(u['username'], 'lt_nader');
    expect(u['level'], 'commander');
    expect(u['regions'], ['Saida', 'Sour']);
    expect((u['password_sent'] as String).length, 14);
    expect(find.byKey(const Key('user-lt_nader')), findsOneWidget);
  });

  testWidgets('change level, disable, reset password; cannot disable self', (tester) async {
    final server = FakeServers();
    await signIn(tester, server);
    await tapKey(tester, 'tile-users');
    await tapKey(tester, 'user-field1');
    await tapKey(tester, 'level-analyst');
    await tapKey(tester, 'user-active');
    await tapKey(tester, 'user-save');
    expect(server.userPatches.last['level'], 'analyst');
    expect(server.userPatches.last['active'], false);
    expect(find.text('Disabled'), findsOneWidget);

    await tapKey(tester, 'user-field1');
    await tapKey(tester, 'reset-password');
    final shown = tester.widget<SelectableText>(find.byKey(const Key('reset-password-value'))).data;
    await tapKey(tester, 'reset-confirm');
    expect(server.userPatches.last['password'], shown);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tapKey(tester, 'user-admin');
    final sw = tester.widget<SwitchListTile>(find.byKey(const Key('user-active')));
    expect(sw.onChanged, isNull);
    expect(find.text('You cannot disable your own account.'), findsOneWidget);
  });

  testWidgets('duplicate username: the server reason is shown', (tester) async {
    final server = FakeServers();
    await signIn(tester, server);
    await tapKey(tester, 'tile-users');
    await tapKey(tester, 'new-user');
    await tester.enterText(find.byKey(const Key('new-username')), 'field1');
    await tapKey(tester, 'role-admin');
    await tapKey(tester, 'user-save');
    expect(find.text('Not accepted: that username is already taken'), findsOneWidget);
  });

  testWidgets('audit log in French', (tester) async {
    await signIn(tester, FakeServers(), lang: 'fr');
    await tapKey(tester, 'tile-audit');
    expect(find.text("Journal d'audit"), findsOneWidget);
    expect(find.text('field1 · login.ok'), findsOneWidget);
    expect(find.textContaining('user: field1'), findsOneWidget);
  });
}
