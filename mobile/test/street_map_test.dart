import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:sirens/geo/street_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

/// Writes the repository's synthetic test map with its Python script
/// (scripts/map/make_test_map.py). Null when the Python setup is missing.
Future<String?> syntheticMap() async {
  final python = File('../.venv/bin/python');
  if (!python.existsSync()) return null;
  final out = '${Directory.systemTemp.createTempSync('sirens_map').path}/test.pmtiles';
  final r = await Process.run(python.path, ['../scripts/map/make_test_map.py', out]);
  return r.exitCode == 0 ? out : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the web map style loads in the phone renderer', () async {
    final theme = await StreetMap.loadTheme();
    expect(theme.tileSources, contains(StreetMap.source));
    expect(theme.layers.length, greaterThan(30));
  });

  test('caza outlines are bundled', () async {
    final outlines = await loadCazaOutlines();
    expect(outlines.keys, containsAll(['Beirut', 'Sour', 'BintJbayl', 'Baalbeck']));
    final beirut = outlines['Beirut']!.first;
    expect(beirut.first.latitude, inInclusiveRange(33.8, 33.95));
  });

  test('reads tiles from a pmtiles file on the phone', () async {
    final path = await syntheticMap();
    if (path == null) {
      markTestSkipped('Python test-map tools not installed');
      return;
    }
    final provider = await PmTilesVectorTileProvider.fromSource(path);
    expect(provider.minimumZoom, 6);
    expect(provider.maximumZoom, 11);
    // Tile containing Beirut at zoom 8.
    final bytes = await provider.provide(TileIdentity(8, 153, 102));
    expect(bytes, isNotEmpty);
    final archive = await PmTilesArchive.from(path);
    expect(archive.maxZoom, 11);
  });
}
