import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/state/session.dart';
import 'package:sirens/state/storage.dart';

import 'fake_server.dart';

void main() {
  test('session survives a restart, token stays in the secure store', () async {
    final server = FakeServers();
    final secure = MemoryStore(), prefs = MemoryStore();
    final a = server.newState(secure: secure, prefs: prefs);
    await a.init();
    await a.setLanguage('fr');
    await a.signInStaff('field1', 'correct-horse-1');
    expect(secure.data['session'], contains('tok-field1'));
    expect(prefs.data.values.join(), isNot(contains('tok-field1')));

    final b = server.newState(secure: secure, prefs: prefs);
    await b.init();
    expect(b.lang, 'fr');
    expect(b.session!.kind, AccountKind.staff);
    expect(b.session!.can('incidents:create'), isTrue);
    expect(server.calls, contains('GET /api/v1/me'));
  });

  test('admin changes are picked up on refresh', () async {
    final server = FakeServers();
    final s = server.newState();
    await s.init();
    await s.signInStaff('field1', 'correct-horse-1');
    server.users['field1']!['level'] = 'analyst';
    server.users['field1']!['permissions'] = [
      'brief',
      'incidents:create',
      'incidents:read',
      'map',
      'review',
      'dashboard',
    ];
    await s.refreshStaff();
    expect(s.session!.level, 'analyst');
    expect(s.session!.can('review'), isTrue);
  });

  test('offline keeps the saved session', () async {
    final server = FakeServers();
    final secure = MemoryStore();
    final a = server.newState(secure: secure);
    await a.init();
    await a.signInStaff('field1', 'correct-horse-1');
    server.offline = true;
    final b = server.newState(secure: secure);
    await b.init();
    expect(b.session, isNotNull);
  });

  test('a 401 from the server signs out and flags it', () async {
    final server = FakeServers();
    final secure = MemoryStore();
    final s = server.newState(secure: secure);
    await s.init();
    await s.signInStaff('field1', 'correct-horse-1');
    server.expireSessions = true;
    await s.refreshStaff();
    expect(s.session, isNull);
    expect(s.sessionExpired, isTrue);
    expect(secure.data.containsKey('session'), isFalse);
  });

  test('wrong password is an error, not an expired session', () async {
    final s = FakeServers().newState();
    await s.init();
    await expectLater(
      s.signInStaff('field1', 'nope'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(s.sessionExpired, isFalse);
  });

  test('civilian sign-in sends the chosen language; sign-out works offline', () async {
    final server = FakeServers();
    final s = server.newState();
    await s.init();
    await s.setLanguage('en');
    await s.signInCivilian(await s.requestCode('03 123 456'), '123456');
    expect(server.lastCodeLang, 'en');
    expect(s.session!.phone, '+9613123456');
    expect(s.gatewayClient.token, 'civ-token');
    expect(s.internalClient.token, isNull); // never sent to the Army server
    server.offline = true;
    await s.signOut();
    expect(s.session, isNull);
  });

  test('expired saved session is dropped at start-up', () async {
    final secure = MemoryStore();
    final old = Session(
      kind: AccountKind.civilian,
      token: 'x',
      expiresAt: DateTime(2000),
      phone: '+961',
    );
    await secure.write(
      'session',
      '{"kind":"civilian","token":"x","expires_at":"${old.expiresAt.toIso8601String()}","phone":"+961"}',
    );
    final s = FakeServers().newState(secure: secure);
    await s.init();
    expect(s.session, isNull);
  });
}
