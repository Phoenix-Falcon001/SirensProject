// Runs the app's real military code against a running internal server.
// Skipped unless SIRENS_LIVE_INTERNAL (base URL) and SIRENS_LIVE_USER /
// SIRENS_LIVE_PASSWORD (an analyst or admin account) are set.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/api/staff_api.dart';

void main() {
  final env = Platform.environment;
  final url = env['SIRENS_LIVE_INTERNAL'];

  test('every military screen\'s data parses from the real server', () async {
    final api = StaffApi(ApiClient(url!));
    final login = await api.login(env['SIRENS_LIVE_USER']!, env['SIRENS_LIVE_PASSWORD']!);
    api.client.token = login['token'] as String;

    final incidents = await api.incidents();
    expect(incidents, isNotEmpty);
    final first = incidents.last;
    final detail = await api.incident(first.id);
    expect(detail.narrative, isNotEmpty);
    await api.network(first.id);

    final filed = await api.fileIncident({
      'narrative': 'IED with a tripwire and pressure plate found by the road.',
      'caza': first.caza,
      'date': '2026-10-20',
      'client_ref': 'live-test-${DateTime.now().microsecondsSinceEpoch}',
      'lat': 33.27,
      'lon': 35.2,
    });
    expect(filed['incident_id'], startsWith('INC-'));

    final brief = await api.brief(first.location!.split(',').first, 'tripwire');
    expect(brief.nInArea, greaterThan(0));

    final (links, tally) = await api.links('all');
    expect(links, isNotEmpty);
    final l = links.first;
    expect((await api.decide(l.a.id, l.b.id, 'unsure')).decision, 'unsure');
    expect((await api.decide(l.a.id, l.b.id, 'undo')).decision, isNull);
    expect((await api.note(l.a.id, l.b.id, 'live check')).notes.last.note, 'live check');
    expect(tally.keys, containsAll(['open', 'confirm']));

    final d = await api.dashboard();
    expect(d.total, greaterThan(0));
    expect(d.byCaza.labels, isNotEmpty);

    final markers = await api.markers();
    expect(markers.first.mgrs, matches(RegExp(r'^3[67]S [A-Z]{2} \d{3} \d{3}$')));
    final info = await api.mapInfo();
    expect(info.size, greaterThanOrEqualTo(0));
  }, skip: url == null ? 'set SIRENS_LIVE_INTERNAL to run' : null);
}
