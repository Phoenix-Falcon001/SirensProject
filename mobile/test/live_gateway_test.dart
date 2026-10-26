// Runs the app's real gateway code against a running gateway:
//   SIRENS_GW_DEV=1 SIRENS_GW_SYNC_KEY=dev-sync-key-123456 python -m gateway.app
//   SIRENS_LIVE_GATEWAY=http://127.0.0.1:5100 SIRENS_GW_LOG=<gateway log file> flutter test test/live_gateway_test.dart
// Skipped unless SIRENS_LIVE_GATEWAY is set.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/api/gateway_api.dart';
import 'package:sirens/state/outbox.dart';

void main() {
  final url = Platform.environment['SIRENS_LIVE_GATEWAY'];
  final log = Platform.environment['SIRENS_GW_LOG'];

  test('sign in, send a report with photo, retry, read it back', () async {
    final api = GatewayApi(ApiClient(url!));
    final phone = await api.requestCode('70 555 01${DateTime.now().second % 10}', 'en');
    final code = RegExp(r'code (\d{6})').allMatches(File(log!).readAsStringSync()).last.group(1)!;
    final v = await api.verify(phone, code, 'en');
    api.client.token = v['token'] as String;

    final r = PendingReport(
      localId: PendingReport.newId(),
      phone: phone,
      observedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      category: 'unexploded_ordnance',
      description: 'Shell in the field — قذيفة في الحقل',
      lat: 33.27,
      lon: 35.2,
      accuracyM: 6,
      photo: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 7)]),
    );
    final first = await api.submitReport(r);
    final again = await api.submitReport(r);
    expect(again['id'], first['id']);
    final mine = await api.myReports();
    expect(mine.where((x) => x.id == first['id']), hasLength(1));
    expect(mine.first.category, 'unexploded_ordnance');
    expect((await api.safety())['steps'], contains('ar'));
    expect(await api.warnings(), isA<List>());
  }, skip: url == null ? 'set SIRENS_LIVE_GATEWAY to run' : null);
}
