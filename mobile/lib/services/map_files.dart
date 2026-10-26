import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Where the offline street map lives on the phone, and how it gets there.
abstract class MapFiles {
  /// Path of the downloaded map, or null if there is none yet.
  Future<String?> localMap();

  /// Downloads the map from the internal server. Resumes a partial download.
  /// [onProgress] gets (bytes so far, total bytes).
  Future<void> download({
    required String url,
    required String token,
    required int size,
    String? sha256,
    void Function(int done, int total)? onProgress,
  });

  Future<void> delete();
}

class MapDownloadException implements Exception {
  const MapDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FileMapFiles implements MapFiles {
  /// [folder] defaults to the app's private support folder.
  FileMapFiles({http.Client? client, this.folder}) : _http = client ?? http.Client();

  final http.Client _http;
  final Directory? folder;

  Future<File> _file(String name) async {
    final dir = folder ?? Directory('${(await getApplicationSupportDirectory()).path}/map');
    await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  @override
  Future<String?> localMap() async {
    final f = await _file('lebanon.pmtiles');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> download({
    required String url,
    required String token,
    required int size,
    String? sha256,
    void Function(int done, int total)? onProgress,
  }) async {
    final part = await _file('lebanon.pmtiles.part');
    var have = await part.exists() ? await part.length() : 0;
    if (have > size) {
      await part.delete();
      have = 0;
    }
    if (have < size) {
      final req = http.Request('GET', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Range'] = 'bytes=$have-';
      final resp = await _http.send(req);
      if (resp.statusCode != 206 && resp.statusCode != 200) {
        throw MapDownloadException('server answered ${resp.statusCode}');
      }
      if (resp.statusCode == 200) have = 0; // server ignored Range: start again
      final sink = part.openWrite(mode: have == 0 ? FileMode.write : FileMode.append);
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          have += chunk.length;
          onProgress?.call(have, size);
        }
      } finally {
        await sink.close();
      }
    }
    if (await part.length() != size) {
      throw const MapDownloadException('download incomplete; try again to resume');
    }
    if (sha256 != null) {
      final digest = await part.openRead().transform(sha256Hasher).first;
      if (digest.toString() != sha256) {
        await part.delete();
        throw const MapDownloadException('downloaded map is damaged; download again');
      }
    }
    await part.rename((await _file('lebanon.pmtiles')).path);
  }

  @override
  Future<void> delete() async {
    for (final n in ['lebanon.pmtiles', 'lebanon.pmtiles.part']) {
      final f = await _file(n);
      if (await f.exists()) await f.delete();
    }
  }
}

/// The sha256 converter from package:crypto, named for readability above.
final sha256Hasher = sha256;
