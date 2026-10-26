import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sirens/geo/mgrs.dart';

void main() {
  // Computed by linker/grid_ref.py (the server), which is itself checked
  // against the independent mgrs and pyproj packages.
  final ref = (jsonDecode(File('test/mgrs_reference.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('same MGRS as the server for 208 points across Lebanon', () {
    for (final r in ref) {
      final lat = (r['lat'] as num).toDouble(), lon = (r['lon'] as num).toDouble();
      expect(toMgrs(lat, lon), r['m6'], reason: '$lat,$lon');
      expect(toMgrs(lat, lon, digits: 10), r['m10'], reason: '$lat,$lon');
      final u = toUtm(lat, lon);
      expect(u.easting, closeTo((r['e'] as num).toDouble(), 0.001));
      expect(u.northing, closeTo((r['n'] as num).toDouble(), 0.001));
    }
  });

  test('zone changes at 36°E', () {
    expect(toMgrs(33.9, 35.999999), startsWith('36S'));
    expect(toMgrs(33.9, 36.000001), startsWith('37S'));
    expect(mgrsSquare(33.8938, 35.5018), '36S YC');
  });

  test('UTM round trip is under a millimetre', () {
    for (final r in ref.take(50)) {
      final lat = (r['lat'] as num).toDouble(), lon = (r['lon'] as num).toDouble();
      final u = toUtm(lat, lon);
      final (la, lo) = utmToLatLon(u.zone, u.easting, u.northing);
      expect(la, closeTo(lat, 1e-8));
      expect(lo, closeTo(lon, 1e-8));
    }
  });

  test('grid lines follow zoom and stop at the zone edge', () {
    expect(gridSpacingForZoom(7), 100000);
    expect(gridSpacingForZoom(10), 10000);
    expect(gridSpacingForZoom(13), 1000);
    final lines = gridLines(33.8, 35.9, 34.0, 36.1, 10000);
    expect(lines, isNotEmpty);
    for (final l in lines) {
      final lons = l.points.map((p) => p.$2);
      // each line lies entirely on one side of 36°E (with float tolerance)
      expect(lons.every((x) => x <= 36 + 1e-9) || lons.every((x) => x >= 36 - 1e-9), isTrue);
    }
    expect(lines.where((l) => l.label.isNotEmpty), isNotEmpty);
  });
}
