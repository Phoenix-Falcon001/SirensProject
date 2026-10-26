// Commander and admin calls against a running internal server holding at
// least one civilian report. Skipped unless SIRENS_LIVE_INTERNAL,
// SIRENS_LIVE_USER and SIRENS_LIVE_PASSWORD (an admin) are set.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/api/staff_api.dart';
import 'package:sirens/ui/staff/users_screen.dart' show generatePassword;

void main() {
  final env = Platform.environment;
  final url = env['SIRENS_LIVE_INTERNAL'];

  test('civilian reports, warnings, accounts and audit parse from the real server', () async {
    final api = StaffApi(ApiClient(url!));
    final login = await api.login(env['SIRENS_LIVE_USER']!, env['SIRENS_LIVE_PASSWORD']!);
    api.client.token = login['token'] as String;

    final reports = await api.civilReports();
    expect(reports, isNotEmpty);
    final r = await api.civilReport(reports.first.id);
    if (r.hasPhoto) expect(await api.civilPhoto(r.id), isNotEmpty);
    final updated = await api.setCivilStatus(r.id, 'under_review', 'live check');
    expect(updated.status, 'under_review');
    expect(updated.statusBy, env['SIRENS_LIVE_USER']);

    final w = await api.publishWarning(
      caza: 'Sour',
      severity: 'caution',
      title: {'en': 'Live check', 'ar': 'فحص'},
      body: {'en': 'Keep away.', 'ar': 'ابتعد.'},
      expiresAt: DateTime.now().add(const Duration(hours: 6)),
    );
    expect(w.isLive, isTrue);
    expect((await api.warnings()).any((x) => x.id == w.id), isTrue);
    expect((await api.withdrawWarning(w.id)).withdrawn, isTrue);

    final name = 'live${DateTime.now().millisecondsSinceEpoch}';
    final u = await api.createUser({
      'username': name, 'password': generatePassword(), 'role': 'military',
      'level': 'field', 'regions': ['Sour'],
    });
    expect(u.regions, ['Sour']);
    final changed = await api.updateUser(u.id, {'level': 'commander', 'active': false});
    expect(changed.level, 'commander');
    expect(changed.active, isFalse);
    expect((await api.users()).any((x) => x.username == name), isTrue);

    final audit = await api.audit();
    expect(audit.map((e) => e.action), containsAll(['user.create', 'warning.publish']));
  }, skip: url == null ? 'set SIRENS_LIVE_INTERNAL to run' : null);
}
