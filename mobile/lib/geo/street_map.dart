import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' show Theme, ThemeReader;
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

/// The offline street map: the same OpenStreetMap file (lebanon.pmtiles) and
/// style as the web map, drawn on the phone with no network.
class StreetMap {
  const StreetMap(this.provider, this.theme);

  final PmTilesVectorTileProvider provider;
  final Theme theme;

  static const source = 'protomaps'; // source name in static/map/style.json

  static Future<Theme> loadTheme() async =>
      ThemeReader().read(await _loadJson('assets/map_style.json'));

  static Future<StreetMap> open(String path) async =>
      StreetMap(await PmTilesVectorTileProvider.fromSource(path), await loadTheme());

  VectorTileLayer layer() => VectorTileLayer(
    tileProviders: TileProviders({source: provider}),
    theme: theme,
    maximumZoom: provider.maximumZoom.toDouble(),
  );
}

/// Caza outlines from the bundled data/regions.json (outer rings only).
/// Always available, so the map is usable before the street map is downloaded.
Future<Map<String, List<List<LatLng>>>> loadCazaOutlines() async {
  final data = await _loadJson('assets/regions.json');
  final out = <String, List<List<LatLng>>>{};
  for (final f in data['features'] as List) {
    final name = f['properties']['name'] as String;
    final g = f['geometry'] as Map<String, dynamic>;
    final polys = g['type'] == 'Polygon' ? [g['coordinates']] : g['coordinates'] as List;
    for (final poly in polys) {
      final ring = (poly as List).first as List;
      (out[name] ??= []).add([
        for (final p in ring) LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
      ]);
    }
  }
  return out;
}

/// Reads a bundled JSON file on the calling isolate (rootBundle.loadString
/// hands large files to a background isolate, which is not needed here).
Future<Map<String, dynamic>> _loadJson(String asset) async {
  final bytes = await rootBundle.load(asset);
  return jsonDecode(utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)))
      as Map<String, dynamic>;
}
