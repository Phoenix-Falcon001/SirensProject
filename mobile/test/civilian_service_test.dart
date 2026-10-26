import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/state/civilian.dart';
import 'package:sirens/state/outbox.dart';
import 'package:sirens/state/storage.dart';

import 'fake_server.dart';

PendingReport draft({String phone = '+9613123456', String text = 'box by the wall'}) =>
    PendingReport(
      localId: PendingReport.newId(),
      phone: phone,
      observedAt: DateTime.now(),
      category: 'suspicious_object',
      description: text,
      lat: 33.27,
      lon: 35.2,
      accuracyM: 8,
    );

String iso(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Future<(FakeServers, CivilianService)> signedIn({MemoryStore? prefs}) async {
  final server = FakeServers();
  final state = server.newState(prefs: prefs);
  await state.init();
  await state.signInCivilian('+9613123456', '123456');
  return (server, state.civilian!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // for the bundled safety file

  test('online: report is sent and leaves nothing on the phone', () async {
    final (server, svc) = await signedIn();
    final r = await svc.submit(draft());
    expect(r.outcome, SubmitOutcome.sent);
    expect(r.reportId, 'CR-0001');
    expect(server.outbox.items, isEmpty);
    final up = server.uploads.single;
    expect(up, contains('name="observed_at"'));
    expect(up, contains('33.270000'));
  });

  test('offline: kept on the phone, sent once later, never twice', () async {
    final (server, svc) = await signedIn();
    server.offline = true;
    final d = draft();
    expect((await svc.submit(d)).outcome, SubmitOutcome.queued);
    expect(svc.pending.single.localId, d.localId);
    expect(await svc.flush(), 0); // still offline
    server.offline = false;
    expect(await svc.flush(), 1);
    expect(svc.pending, isEmpty);
    expect(server.reports, hasLength(1));
    // A retry of an already-received report returns the same id.
    server.byRef[d.localId] = 'CR-0001';
    await server.outbox.save(d);
    await svc.flush();
    expect(server.reports, hasLength(1));
  });

  test('server error 5xx also queues', () async {
    final (server, svc) = await signedIn();
    server.reportStatus = 503;
    expect((await svc.submit(draft())).outcome, SubmitOutcome.queued);
  });

  test('refusal (daily limit) is shown, not queued', () async {
    final (server, svc) = await signedIn();
    server.reportStatus = 429;
    await expectLater(
      svc.submit(draft()),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
    );
    expect(svc.pending, isEmpty);
  });

  test('a queued report refused later is marked, not retried forever', () async {
    final (server, svc) = await signedIn();
    server.offline = true;
    await svc.submit(draft());
    server.offline = false;
    server.reportStatus = 400;
    server.reportError = 'that position is outside Lebanon';
    expect(await svc.flush(), 0);
    expect(svc.pending.single.lastError, contains('outside Lebanon'));
    server.reportStatus = null;
    expect(await svc.flush(), 0); // not retried automatically
    await svc.discard(svc.pending.single.localId);
    expect(svc.pending, isEmpty);
  });

  test("another account's queued report is never sent from this account", () async {
    final (server, svc) = await signedIn();
    await server.outbox.save(draft(phone: '+96171999888'));
    expect(await svc.flush(), 0);
    expect(svc.pending, isEmpty); // not even shown
    expect(server.outbox.items, hasLength(1));
  });

  test('warnings: active only, danger first, cached for offline', () async {
    final prefs = MemoryStore();
    final (server, svc) = await signedIn(prefs: prefs);
    Map<String, dynamic> w(int id, String sev, Duration left) => {
      'id': id,
      'caza': 'Sour',
      'severity': sev,
      'title': {'en': 'T$id'},
      'body': {'en': 'B$id'},
      'created_at': iso(Duration.zero),
      'expires_at': iso(left),
    };
    server.warnings = [
      w(1, 'info', const Duration(hours: 2)),
      w(2, 'danger', const Duration(hours: 2)),
      w(3, 'caution', const Duration(hours: -1)), // expired
    ];
    final live = await svc.warnings();
    expect(live.fromCache, isFalse);
    expect(live.value.map((x) => x.id), [2, 1]);
    server.offline = true;
    final cached = await svc.warnings();
    expect(cached.fromCache, isTrue);
    expect(cached.savedAt, isNotNull);
    expect(cached.value.map((x) => x.id), [2, 1]);
  });

  test('safety: online copy, then bundled copy when never online', () async {
    final (server, svc) = await signedIn();
    expect((await svc.safety()).value.hotlines.last.number, '112');
    final (server2, fresh) = await signedIn();
    server2.offline = true;
    final bundled = await fresh.safety();
    expect(bundled.fromCache, isTrue);
    expect(bundled.value.isPlaceholder, isTrue);
    expect(bundled.value.stepsFor('ar'), isNotEmpty);
    expect(bundled.value.stepsFor('fr'), isNotEmpty);
    expect(server.calls, isNotEmpty);
  });

  test('deleting the account clears its queued reports', () async {
    final server = FakeServers();
    final state = server.newState();
    await state.init();
    await state.signInCivilian('+9613123456', '123456');
    server.offline = true;
    await state.civilian!.submit(draft());
    server.offline = false;
    server.outbox.items.values.single.lastError = 'x'; // keep it from flushing
    await state.deleteCivilianAccount();
    expect(server.outbox.items, isEmpty);
  });
}
