import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/state/session.dart';
import 'package:sirens/ui/menu.dart';

Session staff(List<String> perms) => Session(
  kind: AccountKind.staff,
  token: 't',
  expiresAt: DateTime(2100),
  username: 'u',
  role: 'military',
  level: 'field',
  permissions: perms.toSet(),
);

void main() {
  test('field user sees only field tiles', () {
    final ids = staffMenu(staff(['brief', 'incidents:create', 'incidents:read', 'map']))
        .map((e) => e.id);
    expect(ids, ['new_report', 'incidents', 'brief', 'map']);
  });

  test('commander adds civilian reports and warnings, not admin tiles', () {
    final ids = staffMenu(
      staff([
        'brief',
        'incidents:create',
        'incidents:read',
        'map',
        'review',
        'dashboard',
        'civil_reports',
        'warnings:publish',
      ]),
    ).map((e) => e.id).toList();
    expect(ids, containsAll(['review', 'dashboard', 'civil_reports', 'warnings']));
    expect(ids, isNot(contains('users')));
  });

  test('no permissions, no tiles', () {
    expect(staffMenu(staff([])), isEmpty);
  });

  test('civilians always get the same four tiles', () {
    expect(civilianMenu.map((e) => e.id), ['report', 'my_reports', 'warnings', 'safety']);
  });
}
