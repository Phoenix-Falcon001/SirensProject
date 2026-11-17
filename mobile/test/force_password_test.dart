import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sirens/ui/app.dart';

import 'fake_server.dart';

void main() {
  testWidgets('a password set by an admin must be replaced before anything else', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final server = FakeServers();
    server.users['field1']!['must_change'] = true;
    final state = server.newState();
    await state.init();
    await state.setLanguage('en');
    await state.signInStaff('field1', 'correct-horse-1');
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
    await tester.pumpAndSettle();

    expect(find.text('Choose your own password'), findsOneWidget);
    expect(find.byKey(const Key('tile-new_report')), findsNothing); // no home screen yet

    await tester.enterText(find.byKey(const Key('force-current')), 'correct-horse-1');
    await tester.enterText(find.byKey(const Key('force-new')), 'short');
    await tester.enterText(find.byKey(const Key('force-again')), 'short');
    await tester.tap(find.byKey(const Key('force-save')));
    await tester.pumpAndSettle();
    expect(find.text('At least 10 characters.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('force-new')), 'correct-horse-1');
    await tester.enterText(find.byKey(const Key('force-again')), 'correct-horse-1');
    await tester.tap(find.byKey(const Key('force-save')));
    await tester.pumpAndSettle();
    expect(find.text('The new password must be different from the temporary one.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('force-new')), 'my-own-password-1');
    await tester.enterText(find.byKey(const Key('force-again')), 'something-else-1');
    await tester.tap(find.byKey(const Key('force-save')));
    await tester.pumpAndSettle();
    expect(find.text('The two passwords are different.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('force-again')), 'my-own-password-1');
    await tester.tap(find.byKey(const Key('force-save')));
    await tester.pumpAndSettle();
    expect(state.session!.mustChange, isFalse);
    expect(find.byKey(const Key('tile-new_report')), findsOneWidget); // home screen now
  });

  testWidgets('they can sign out instead', (tester) async {
    final server = FakeServers();
    server.users['field1']!['must_change'] = true;
    final state = server.newState();
    await state.init();
    await state.setLanguage('en');
    await state.signInStaff('field1', 'correct-horse-1');
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('force-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('choose-staff')), findsOneWidget);
  });
}
