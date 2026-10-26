// Downloads the offline map from a running internal server, resuming a
// half-finished download and checking the checksum. Skipped unless
// SIRENS_LIVE_INTERNAL, SIRENS_LIVE_USER, SIRENS_LIVE_PASSWORD are set and
// the server has a map file.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/api/api_client.dart';
import 'package:sirens/api/staff_api.dart';
import 'package:sirens/services/map_files.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

void main() {
  final env = Platform.environment;
  final url = env['SIRENS_LIVE_INTERNAL'];

  test('resumable, checked map download', () async {
    final api = StaffApi(ApiClient(url!));
    final login = await api.login(env['SIRENS_LIVE_USER']!, env['SIRENS_LIVE_PASSWORD']!);
    final token = login['token'] as String;
    api.client.token = token;
    final info = await api.mapInfo();
    expect(info.available, isTrue);
    expect(info.sha256, isNotNull);

    // Pretend an earlier download stopped half-way, with the right first half.
    final req = await HttpClient().getUrl(Uri.parse('$url/api/v1/map/lebanon.pmtiles'));
    req.headers.set('Authorization', 'Bearer $token');
    final full = await (await req.close()).fold<List<int>>([], (a, b) => a..addAll(b));
    final dir = Directory.systemTemp.createTempSync('sirens_dl');
    File('${dir.path}/lebanon.pmtiles.part').writeAsBytesSync(full.sublist(0, full.length ~/ 2));

    final files = FileMapFiles(folder: dir);
    final seen = <int>[];
    await files.download(
      url: '$url/api/v1/map/lebanon.pmtiles',
      token: token,
      size: info.size,
      sha256: info.sha256,
      onProgress: (done, _) => seen.add(done),
    );
    expect(seen.first, greaterThan(full.length ~/ 2)); // resumed, not restarted
    final path = (await files.localMap())!;
    expect(sha256.convert(File(path).readAsBytesSync()).toString(), info.sha256);
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    expect(await provider.provide(TileIdentity(8, 153, 102)), isNotEmpty);

    // A damaged download is refused and removed.
    await files.delete();
    File('${dir.path}/lebanon.pmtiles.part').writeAsBytesSync(List.filled(info.size, 0));
    await expectLater(
      files.download(
        url: '$url/api/v1/map/lebanon.pmtiles',
        token: token,
        size: info.size,
        sha256: info.sha256,
      ),
      throwsA(isA<MapDownloadException>()),
    );
    expect(await files.localMap(), isNull);
  }, skip: url == null ? 'set SIRENS_LIVE_INTERNAL to run' : null);
}
