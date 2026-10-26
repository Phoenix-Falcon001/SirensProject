import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/state/drafts.dart';
import 'package:sirens/state/outbox.dart' show PendingReport;
import 'package:sirens/state/staff.dart';

import 'fake_server.dart';

StaffDraft draft({String user = 'field1'}) => StaffDraft(
  localId: PendingReport.newId(),
  username: user,
  savedAt: DateTime.now(),
  body: {'narrative': 'IED with tripwire', 'caza': 'Sour', 'date': '2026-10-20'},
);

Future<(FakeServers, StaffService)> signedIn() async {
  final server = FakeServers();
  final state = server.newState();
  await state.init();
  await state.signInStaff('field1', 'correct-horse-1');
  return (server, state.staffService!);
}

void main() {
  test('sign-in loads the form lists', () async {
    final (_, svc) = await signedIn();
    expect(svc.regionChoices, contains('Sour'));
    expect(svc.munitions.single['key'], 'ied');
  });

  test('filed online: id and network come back, nothing kept', () async {
    final (server, svc) = await signedIn();
    final r = await svc.file(draft());
    expect(r.outcome, FileOutcome.filed);
    expect(r.incidentId, 'INC-041');
    expect(r.network!.links.single.band, 'strong');
    expect(server.drafts.items, isEmpty);
    expect(server.filed.single['client_ref'], isNotNull);
  });

  test('no VPN: kept on the phone, filed once when back', () async {
    final (server, svc) = await signedIn();
    server.offline = true;
    final d = draft();
    expect((await svc.file(d)).outcome, FileOutcome.queued);
    expect(svc.pending.single.localId, d.localId);
    server.offline = false;
    expect(await svc.flush(), 1);
    expect(svc.pending, isEmpty);
    // A retry with the same reference is answered with the same report.
    await server.drafts.save(d);
    await svc.flush();
    expect(server.filed, hasLength(1));
  });

  test('refused (outside regions): shown, not queued', () async {
    final (server, svc) = await signedIn();
    server.fileStatus = 403;
    await expectLater(
      svc.file(draft()),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );
    expect(svc.pending, isEmpty);
  });

  test("another user's drafts stay put", () async {
    final (server, svc) = await signedIn();
    await server.drafts.save(draft(user: 'someone_else'));
    expect(await svc.flush(), 0);
    expect(server.drafts.items, hasLength(1));
  });

  test('sign-in sends drafts left from before', () async {
    final server = FakeServers();
    await server.drafts.save(draft());
    final state = server.newState();
    await state.init();
    await state.signInStaff('field1', 'correct-horse-1');
    expect(server.filed, hasLength(1));
    expect(server.drafts.items, isEmpty);
  });
}
