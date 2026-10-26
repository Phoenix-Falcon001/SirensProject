import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sirens/state/app_state.dart';
import 'package:sirens/ui/app.dart';

import 'fake_server.dart';

Future<AppState> pumpApp(WidgetTester tester, FakeServers server) async {
  final state = server.newState();
  await state.init();
  await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('first run: pick Arabic, layout is right-to-left', (tester) async {
    await pumpApp(tester, FakeServers());
    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();
    expect(find.text('أنا مدني'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byKey(const Key('choose-civilian'))));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('civilian signs up with phone and SMS code (French)', (tester) async {
    final server = FakeServers();
    final state = await pumpApp(tester, server);
    await state.setLanguage('fr');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-civilian')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phone')), '03 123 456');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    expect(find.textContaining('+9613123456'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('code')), '999999');
    await tester.tap(find.byKey(const Key('verify')));
    await tester.pumpAndSettle();
    expect(find.text('Code erroné ou expiré.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tester.tap(find.byKey(const Key('verify')));
    await tester.pumpAndSettle();
    // Civilian home: the four tiles and the emergency reminder.
    expect(find.text('Signaler un objet suspect'), findsOneWidget);
    expect(find.byKey(const Key('tile-safety')), findsOneWidget);
    expect(find.textContaining('ligne d\'urgence'), findsOneWidget);
    expect(find.byKey(const Key('tile-new_report')), findsNothing);
  });

  testWidgets('field user sees field tiles only (English)', (tester) async {
    final state = await pumpApp(tester, FakeServers());
    await state.setLanguage('en');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-staff')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('username')), 'field1');
    await tester.enterText(find.byKey(const Key('password')), 'correct-horse-1');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Sgt. Haddad'), findsOneWidget);
    expect(find.text('Field'), findsOneWidget);
    expect(find.text('Sour'), findsOneWidget);
    expect(find.byKey(const Key('tile-new_report')), findsOneWidget);
    expect(find.byKey(const Key('tile-map')), findsOneWidget);
    expect(find.byKey(const Key('tile-review')), findsNothing);
    expect(find.byKey(const Key('tile-users')), findsNothing);
    // A tile opens its (not yet built) screen.
    await tester.tap(find.byKey(const Key('tile-map')));
    await tester.pumpAndSettle();
    expect(find.text('This part arrives in the next version of the app.'), findsOneWidget);
  });

  testWidgets('admin sees every tile and can sign out', (tester) async {
    final state = await pumpApp(tester, FakeServers());
    await state.setLanguage('en');
    await state.signInStaff('admin', 'correct-horse-1');
    await tester.pumpAndSettle();
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('All regions'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('tile-audit')), 100);
    expect(find.byKey(const Key('tile-users')), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('choose-staff')), findsOneWidget);
  });

  testWidgets('wrong password shows a message in the chosen language', (tester) async {
    final state = await pumpApp(tester, FakeServers());
    await state.setLanguage('ar');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-staff')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('username')), 'field1');
    await tester.enterText(find.byKey(const Key('password')), 'bad');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('اسم المستخدم أو كلمة المرور غير صحيحة.'), findsOneWidget);
  });

  testWidgets('no VPN: staff gets a VPN hint', (tester) async {
    final server = FakeServers()..offline = true;
    final state = await pumpApp(tester, server);
    await state.setLanguage('en');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-staff')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('username')), 'field1');
    await tester.enterText(find.byKey(const Key('password')), 'correct-horse-1');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Cannot reach the Army server. Check that the VPN is on.'), findsOneWidget);
  });

  testWidgets('civilian can delete their account; language can change in settings', (tester) async {
    final server = FakeServers();
    final state = await pumpApp(tester, server);
    await state.setLanguage('en');
    await state.signInCivilian('+9613123456', '123456');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setlang-fr')));
    await tester.pumpAndSettle();
    expect(find.text('Paramètres'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(server.calls, contains('DELETE /gw/v1/me'));
    expect(state.session, isNull);
    expect(find.byKey(const Key('choose-civilian')), findsOneWidget);
  });
}
