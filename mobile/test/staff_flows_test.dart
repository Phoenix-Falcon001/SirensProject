import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sirens/state/app_state.dart';
import 'package:sirens/ui/app.dart';

import 'fake_server.dart';

Future<AppState> staffHome(
  WidgetTester tester,
  FakeServers server, {
  String user = 'admin',
  String lang = 'en',
}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final state = server.newState();
  await state.init();
  await state.setLanguage(lang);
  await state.signInStaff(user, 'correct-horse-1');
  await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
  await tester.pumpAndSettle();
  return state;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('file a report with grid reference; network shown', (tester) async {
    final server = FakeServers();
    await staffHome(tester, server, user: 'field1');
    await tapKey(tester, 'tile-new_report');
    // A field user with one region gets it preselected.
    expect(find.text('Sour'), findsOneWidget);
    await tapKey(tester, 'file-report');
    expect(find.text('Required'), findsOneWidget); // narrative missing
    await tester.enterText(find.byKey(const Key('narrative')), 'IED with a tripwire at Qana');
    await tester.enterText(find.byKey(const Key('street')), 'Qana main road');
    await tapKey(tester, 'grid');
    expect(find.text('MGRS 36S YB 049 833'), findsOneWidget);
    await tapKey(tester, 'file-report');
    expect(find.text('Report filed as INC-041'), findsOneWidget);
    expect(find.byKey(const Key('network-card')), findsOneWidget);
    expect(
      find.text('Every link is a lead for a human analyst, never a conclusion.'),
      findsOneWidget,
    );
    final body = server.filed.single;
    expect(body['caza'], 'Sour');
    expect(body['street'], 'Qana main road');
    expect(body['lat'], 33.27);
  });

  testWidgets('report without the VPN is kept and sent later', (tester) async {
    final server = FakeServers();
    final state = await staffHome(tester, server, user: 'field1');
    server.offline = true;
    await tapKey(tester, 'tile-new_report');
    await tester.enterText(find.byKey(const Key('narrative')), 'Wire found');
    await tapKey(tester, 'file-report');
    expect(
      find.text('Saved on this phone. It will be filed when the Army VPN is back.'),
      findsOneWidget,
    );
    await tapKey(tester, 'queued-ok');
    await tapKey(tester, 'tile-new_report');
    expect(find.text('Reports waiting for the VPN: 1'), findsOneWidget);
    server.offline = false;
    await tapKey(tester, 'drafts-send-now');
    expect(server.filed, hasLength(1));
    expect(state.staffService!.pending, isEmpty);
  });

  testWidgets('incidents list, detail and network', (tester) async {
    await staffHome(tester, FakeServers());
    await tapKey(tester, 'tile-incidents');
    expect(find.byKey(const Key('incident-INC-001')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('incident-search')), 'srifa');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('incident-INC-001')), findsNothing);
    await tester.enterText(find.byKey(const Key('incident-search')), '');
    await tester.pumpAndSettle();
    await tapKey(tester, 'incident-INC-001');
    expect(find.text('On 20 an IED with a tripwire was found near Qana.'), findsOneWidget);
    expect(find.text('trigger: tripwire'), findsWidgets);
    expect(find.byKey(const Key('net-INC-002')), findsOneWidget);
  });

  testWidgets('brief: record-based notice and results', (tester) async {
    await staffHome(tester, FakeServers());
    await tapKey(tester, 'tile-brief');
    expect(find.byKey(const Key('brief-note')), findsOneWidget);
    await tapKey(tester, 'brief-run');
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('brief-location')), 'Qana');
    await tapKey(tester, 'brief-run');
    expect(find.text('2 past reports in this area'), findsOneWidget);
    expect(find.text('unexploded ordnance'), findsOneWidget);
  });

  testWidgets('review: confirm, undo, note', (tester) async {
    final server = FakeServers();
    await staffHome(tester, server);
    await tapKey(tester, 'tile-review');
    expect(find.byKey(const Key('link-INC-001--INC-002')), findsOneWidget);
    await tapKey(tester, 'INC-001--INC-002-confirm');
    expect(server.decisions['INC-001--INC-002'], 'confirm');
    // Default filter is "not reviewed": the decided link leaves the list.
    expect(find.byKey(const Key('link-INC-001--INC-002')), findsNothing);
    await tapKey(tester, 'filter-confirm');
    expect(find.text('Confirmed'), findsWidgets);
    await tapKey(tester, 'INC-001--INC-002-undo');
    expect(server.decisions['INC-001--INC-002'], isNull);
    await tapKey(tester, 'filter-all');
    await tapKey(tester, 'INC-001--INC-002-note');
    await tester.enterText(find.byKey(const Key('note-text')), 'Same wiring');
    await tapKey(tester, 'note-save');
    expect(find.text('analyst1: Same wiring'), findsOneWidget);
  });

  testWidgets('dashboard in Arabic, filter by caza', (tester) async {
    await staffHome(tester, FakeServers(), lang: 'ar');
    await tapKey(tester, 'tile-dashboard');
    expect(find.text('3 بلاغات'), findsOneWidget);
    expect(find.text('شبكات محتملة'), findsOneWidget);
    await tapKey(tester, 'dash-caza-Saida');
    expect(find.text('1 بلاغات'), findsOneWidget);
  });

  testWidgets('map: markers, MGRS at centre, copy, download offer', (tester) async {
    final server = FakeServers();
    await staffHome(tester, server);
    await tapKey(tester, 'tile-map');
    expect(find.textContaining('Centre 36S'), findsOneWidget);
    expect(find.text('Street map not on this phone: showing caza outlines only.'), findsOneWidget);
    expect(find.text('Download street map (50 MB)'), findsOneWidget);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tapKey(tester, 'copy-centre');
    expect(copied, startsWith('36S'));

    await tapKey(tester, 'marker-INC-001');
    expect(find.text('MGRS 36S YB 049 833'), findsOneWidget);
    expect(find.text('Filed grid reference'), findsOneWidget);
    await tapKey(tester, 'marker-open');
    expect(find.text('On 20 an IED with a tripwire was found near Qana.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tapKey(tester, 'map-download');
    expect(server.maps.downloads.single, 'https://int.test/api/v1/map/lebanon.pmtiles tok-admin');
  });

  testWidgets('map download failure is explained and can be resumed', (tester) async {
    final server = FakeServers();
    server.maps.fail = true;
    await staffHome(tester, server);
    await tapKey(tester, 'tile-map');
    await tapKey(tester, 'map-download');
    expect(find.text('Download stopped: connection lost. Try again to resume.'), findsOneWidget);
  });

  testWidgets('map when the server has no street map', (tester) async {
    final server = FakeServers()..mapOnServer = false;
    await staffHome(tester, server);
    await tapKey(tester, 'tile-map');
    expect(find.text('The street map is not installed on the server yet.'), findsOneWidget);
  });

  testWidgets('no VPN: screens explain and offer a retry', (tester) async {
    final server = FakeServers();
    await staffHome(tester, server);
    server.offline = true;
    await tapKey(tester, 'tile-incidents');
    expect(find.text('Cannot reach the Army server. Check that the VPN is on.'), findsOneWidget);
    server.offline = false;
    await tapKey(tester, 'retry');
    expect(find.byKey(const Key('incident-INC-001')), findsOneWidget);
  });
}
