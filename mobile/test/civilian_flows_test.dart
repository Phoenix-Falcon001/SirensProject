import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sirens/services/device.dart';
import 'package:sirens/state/app_state.dart';
import 'package:sirens/ui/app.dart';

import 'fake_server.dart';

Future<AppState> civilianHome(WidgetTester tester, FakeServers server, {String lang = 'en'}) async {
  // A tall phone screen, so whole forms are laid out.
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final state = server.newState();
  await state.init();
  await state.setLanguage(lang);
  await state.signInCivilian('+9613123456', '123456');
  await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
  await tester.pumpAndSettle();
  return state;
}

Future<void> openTile(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('tile-$id')));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('report: safety check first, then sent with photo and location', (tester) async {
    final server = FakeServers();
    await civilianHome(tester, server);
    await openTile(tester, 'report');
    expect(find.text('Location added (within about 8 m)'), findsOneWidget);

    await tapVisible(tester, const Key('send-report'));
    expect(
      find.text('Move away first. Only send the report from a safe distance.'),
      findsOneWidget,
    );
    await tapVisible(tester, const Key('safe-distance'));
    await tapVisible(tester, const Key('send-report'));
    expect(find.text('Add a description or a photo.'), findsOneWidget);

    await tapVisible(tester, const Key('cat-unexploded_ordnance'));
    await tester.enterText(find.byKey(const Key('description')), 'Rocket in the olive grove');
    await tapVisible(tester, const Key('take-photo'));
    expect(find.byKey(const Key('remove-photo')), findsOneWidget);
    await tapVisible(tester, const Key('send-report'));
    expect(find.text('Report received'), findsOneWidget);
    expect(find.textContaining('CR-0001'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-report')), findsOneWidget); // back home

    final up = server.uploads.single;
    expect(up, contains('unexploded_ordnance'));
    expect(up, contains('Rocket in the olive grove'));
    expect(up, contains('name="photo"'));
  });

  testWidgets('report offline: saved, shown as waiting, sent later', (tester) async {
    final server = FakeServers();
    await civilianHome(tester, server);
    server.offline = true;
    await openTile(tester, 'report');
    await tapVisible(tester, const Key('safe-distance'));
    await tester.enterText(find.byKey(const Key('description')), 'Wire across the path');
    await tapVisible(tester, const Key('send-report'));
    expect(find.text('Saved on this phone'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report-done')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting to send: 1'), findsOneWidget);

    await openTile(tester, 'my_reports');
    expect(find.text('Waiting to send'), findsWidgets);
    server.offline = false;
    await tester.tap(find.byKey(const Key('send-now')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-CR-0001')), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
  });

  testWidgets('location refused: the report can still be sent', (tester) async {
    final server = FakeServers();
    server.device.problem = LocationProblem.denied;
    await civilianHome(tester, server);
    await openTile(tester, 'report');
    expect(find.text('Location permission was refused.'), findsOneWidget);
    expect(find.text('No location. Describe the place as precisely as you can.'), findsOneWidget);
    await tapVisible(tester, const Key('safe-distance'));
    await tester.enterText(find.byKey(const Key('description')), 'Next to the mosque in Qana');
    await tapVisible(tester, const Key('send-report'));
    expect(find.text('Report received'), findsOneWidget);
    expect(server.uploads.single, isNot(contains('name="lat"')));
  });

  testWidgets('daily limit: told to call the hotline', (tester) async {
    final server = FakeServers()..reportStatus = 429;
    await civilianHome(tester, server);
    await openTile(tester, 'report');
    await tapVisible(tester, const Key('safe-distance'));
    await tester.enterText(find.byKey(const Key('description')), 'x');
    await tapVisible(tester, const Key('send-report'));
    expect(
      find.text('You have sent many reports today. Please call the hotline instead.'),
      findsOneWidget,
    );
  });

  testWidgets('unsupported photo format is refused on the phone', (tester) async {
    final server = FakeServers();
    server.device.photo = PickedPhoto(
      Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65]),
    );
    await civilianHome(tester, server);
    await openTile(tester, 'report');
    await tapVisible(tester, const Key('choose-photo'));
    expect(find.text('This photo format is not supported. Use JPEG or PNG.'), findsOneWidget);
    expect(find.byKey(const Key('remove-photo')), findsNothing);
  });

  testWidgets('my reports in Arabic, with status', (tester) async {
    final server = FakeServers();
    server.reports.add({
      'id': 'CR-ABC',
      'submitted_at': '2026-10-25T10:00:00+00:00',
      'category': 'suspicious_vehicle',
      'status': 'under_review',
      'status_at': '2026-10-25T11:00:00+00:00',
      'delivered': true,
    });
    await civilianHome(tester, server, lang: 'ar');
    await openTile(tester, 'my_reports');
    expect(find.text('مركبة مشبوهة'), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.textContaining('وصل إلى الجيش'), findsOneWidget);
  });

  testWidgets('warnings in French, filter by area, offline copy', (tester) async {
    final server = FakeServers();
    final exp = DateTime.now().add(const Duration(hours: 5)).toUtc().toIso8601String();
    server.warnings = [
      {
        'id': 1,
        'caza': 'Sour',
        'severity': 'danger',
        'expires_at': exp,
        'title': {'en': 'Avoid coast road', 'fr': 'Évitez la route côtière'},
        'body': {'en': 'Operation in progress.'},
      },
      {
        'id': 2,
        'caza': 'Saida',
        'severity': 'info',
        'expires_at': exp,
        'title': {'en': 'Road reopened'},
        'body': {'en': 'Traffic normal.'},
      },
    ];
    await civilianHome(tester, server, lang: 'fr');
    await openTile(tester, 'warnings');
    expect(find.text('Évitez la route côtière'), findsOneWidget); // French text
    expect(find.text('Road reopened'), findsOneWidget); // English fallback
    expect(find.text('Danger · Sour'), findsOneWidget);
    await tester.tap(find.byKey(const Key('area-Saida')));
    await tester.pumpAndSettle();
    expect(find.text('Évitez la route côtière'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    server.offline = true;
    await openTile(tester, 'warnings');
    expect(find.textContaining('Hors ligne'), findsOneWidget);
    expect(find.text('Road reopened'), findsOneWidget);
  });

  testWidgets('no warnings', (tester) async {
    await civilianHome(tester, FakeServers());
    await openTile(tester, 'warnings');
    expect(find.text('No active warnings.'), findsOneWidget);
  });

  testWidgets('safety page: placeholder notice, real numbers can be called', (tester) async {
    final server = FakeServers();
    await civilianHome(tester, server);
    await openTile(tester, 'safety');
    expect(find.byKey(const Key('safety-placeholder')), findsOneWidget);
    expect(find.text('Do not touch it.'), findsOneWidget);
    expect(find.text('Number to be confirmed'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call-112')));
    await tester.pumpAndSettle();
    expect(server.device.dialed, ['112']);
    expect(find.byKey(const Key('call-TO-BE-CONFIRMED')), findsNothing);
  });

  testWidgets('safety page works with no connection at all', (tester) async {
    final server = FakeServers();
    await civilianHome(tester, server, lang: 'ar');
    server.offline = true;
    await openTile(tester, 'safety');
    expect(find.text('لا تلمس الجسم ولا تحرّكه ولا تقترب منه.'), findsOneWidget); // bundled copy
    expect(find.byKey(const Key('call-112')), findsOneWidget);
  });
}
