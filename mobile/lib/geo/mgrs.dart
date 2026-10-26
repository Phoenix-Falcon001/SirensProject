/// Latitude/longitude to UTM and MGRS (WGS84), and MGRS grid lines.
///
/// A port of linker/grid_ref.py and static/map/mgrs_grid.js, so the app gives
/// exactly the same references as the server and the web map (checked in
/// test/mgrs_test.dart against values computed by the Python code).
/// Lebanon spans UTM zones 36 and 37, which meet at 36°E; the reference
/// jumps from 36S to 37S there, which is correct.
library;

import 'dart:math' as math;

const _a = 6378137.0;
const _f = 1 / 298.257223563;
const _k0 = 0.9996;
final _n = _f / (2 - _f);
final _aa = _a / (1 + _n) * (1 + _n * _n / 4 + math.pow(_n, 4) / 64);
final _alpha = [
  _n / 2 - 2 * _n * _n / 3 + 5 * math.pow(_n, 3) / 16,
  13 * _n * _n / 48 - 3 * math.pow(_n, 3) / 5,
  61 * math.pow(_n, 3) / 240,
];
final _beta = [
  _n / 2 - 2 * _n * _n / 3 + 37 * math.pow(_n, 3) / 96,
  _n * _n / 48 + math.pow(_n, 3) / 15,
  17 * math.pow(_n, 3) / 480,
];
final _delta = [
  2 * _n - 2 * _n * _n / 3 - 2 * math.pow(_n, 3),
  7 * _n * _n / 3 - 8 * math.pow(_n, 3) / 5,
  56 * math.pow(_n, 3) / 15,
];
final _e = math.sqrt(_f * (2 - _f));
const _bands = 'CDEFGHJKLMNPQRSTUVWX';
const _cols = ['ABCDEFGH', 'JKLMNPQR', 'STUVWXYZ'];
const _rows = 'ABCDEFGHJKLMNPQRSTUV';
const _deg = math.pi / 180;

double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

int utmZone(double lon) => ((lon + 180) / 6).floor() % 60 + 1;
double _lon0(int zone) => (zone - 1) * 6 - 180 + 3.0;

class Utm {
  const Utm(this.zone, this.band, this.easting, this.northing);

  final int zone;
  final String band;
  final double easting;
  final double northing;
}

Utm toUtm(double lat, double lon, [int? zone]) {
  if (lat < -80 || lat >= 84) throw ArgumentError('MGRS/UTM covers latitudes 80S to 84N');
  zone ??= utmZone(lon);
  final phi = lat * _deg, lam = (lon - _lon0(zone)) * _deg;
  final t = _sinh(_atanh(math.sin(phi)) - _e * _atanh(_e * math.sin(phi)));
  final xi = math.atan2(t, math.cos(lam));
  final eta = _atanh(math.sin(lam) / math.sqrt(1 + t * t));
  var x = eta, y = xi;
  for (var j = 1; j <= 3; j++) {
    x += _alpha[j - 1] * math.cos(2 * j * xi) * _sinh(2 * j * eta);
    y += _alpha[j - 1] * math.sin(2 * j * xi) * _cosh(2 * j * eta);
  }
  final band = _bands[math.min(((lat + 80) / 8).floor(), _bands.length - 1)];
  return Utm(zone, band, 500000 + _k0 * _aa * x, _k0 * _aa * y + (lat < 0 ? 10000000 : 0));
}

/// (lat, lon) for a northern-hemisphere UTM point.
(double, double) utmToLatLon(int zone, double easting, double northing) {
  final xi = northing / (_k0 * _aa), eta = (easting - 500000) / (_k0 * _aa);
  var xp = xi, ep = eta;
  for (var j = 1; j <= 3; j++) {
    xp -= _beta[j - 1] * math.sin(2 * j * xi) * _cosh(2 * j * eta);
    ep -= _beta[j - 1] * math.cos(2 * j * xi) * _sinh(2 * j * eta);
  }
  final chi = math.asin(math.sin(xp) / _cosh(ep));
  var phi = chi;
  for (var j = 1; j <= 3; j++) {
    phi += _delta[j - 1] * math.sin(2 * j * chi);
  }
  return (phi / _deg, _lon0(zone) + math.atan2(_sinh(ep), math.cos(xp)) / _deg);
}

/// MGRS reference such as "36S YC 311 527" (digits = 6 means 100 m squares).
/// Digits are truncated, as MGRS requires.
String toMgrs(double lat, double lon, {int digits = 6}) {
  if (![2, 4, 6, 8, 10].contains(digits)) throw ArgumentError('digits must be 2..10, even');
  final u = toUtm(lat, lon);
  final col = _cols[(u.zone - 1) % 3][(u.easting / 100000).floor() - 1];
  final row = _rows[((u.northing / 100000).floor() + (u.zone.isEven ? 5 : 0)) % 20];
  final half = digits ~/ 2;
  final unit = math.pow(10, 5 - half);
  final ee = ((u.easting % 100000) / unit).floor().toString().padLeft(half, '0');
  final nn = ((u.northing % 100000) / unit).floor().toString().padLeft(half, '0');
  return '${u.zone}${u.band} $col$row $ee $nn';
}

/// The 100 km square name, e.g. "36S YC".
String mgrsSquare(double lat, double lon) => toMgrs(lat, lon, digits: 2).substring(0, 6);

/// One grid line as (lat, lon) points; [major] when it falls on a 100 km line.
class GridLine {
  const GridLine(this.points, {required this.major, required this.label});

  final List<(double, double)> points;
  final bool major;
  final String label;
}

String _lineLabel(double value, double spacing) {
  final inSquare = ((value % 100000) + 100000) % 100000;
  if (spacing >= 100000) return '';
  if (spacing >= 10000) return (inSquare ~/ 10000).toString();
  return (inSquare ~/ 1000).toString().padLeft(2, '0');
}

/// Keeps the parts of a line inside [lo, hi] longitude, cut exactly at the edge.
List<List<(double, double)>> _clipLon(List<(double, double)> pts, double lo, double hi) {
  final out = <List<(double, double)>>[];
  var cur = <(double, double)>[];
  (double, double) edge((double, double) p, (double, double) q, double x) {
    final t = (x - p.$2) / (q.$2 - p.$2);
    return (p.$1 + t * (q.$1 - p.$1), x);
  }

  for (var i = 0; i < pts.length; i++) {
    final p = pts[i];
    final inside = p.$2 >= lo && p.$2 <= hi;
    if (i > 0) {
      final q = pts[i - 1];
      final qin = q.$2 >= lo && q.$2 <= hi;
      if (inside && !qin) cur.add(edge(q, p, q.$2 < lo ? lo : hi));
      if (!inside && qin) {
        cur.add(edge(q, p, p.$2 < lo ? lo : hi));
        out.add(cur);
        cur = [];
      }
    }
    if (inside) cur.add(p);
  }
  if (cur.length > 1) out.add(cur);
  return out.where((l) => l.length > 1).toList();
}

/// Grid spacing in metres for a map zoom level (as on the web map).
double gridSpacingForZoom(double zoom) => zoom >= 12
    ? 1000
    : zoom >= 9
    ? 10000
    : 100000;

/// MGRS grid lines inside a view (south, west, north, east), for zones 36
/// and 37, each clipped at its zone edge so the grid jumps at 36°E.
List<GridLine> gridLines(double s, double w, double n, double e, double spacing) {
  final lines = <GridLine>[];
  for (final zone in const [36, 37]) {
    final lo = (zone - 1) * 6 - 180.0, hi = lo + 6;
    final west = math.max(w, lo), east = math.min(e, hi);
    if (west >= east) continue;
    final corners = [
      for (final p in [
        (s, west),
        (s, east),
        (n, west),
        (n, east),
        (s, (west + east) / 2),
        (n, (west + east) / 2),
      ])
        toUtm(p.$1, p.$2, zone),
    ];
    final eMin = corners.map((c) => c.easting).reduce(math.min);
    final eMax = corners.map((c) => c.easting).reduce(math.max);
    final nMin = corners.map((c) => c.northing).reduce(math.min);
    final nMax = corners.map((c) => c.northing).reduce(math.max);
    const steps = 32;
    for (var x = (eMin / spacing).ceil() * spacing; x <= eMax; x += spacing) {
      final pts = [
        for (var k = 0; k <= steps; k++) utmToLatLon(zone, x, nMin + (nMax - nMin) * k / steps),
      ];
      for (final l in _clipLon(pts, lo, hi)) {
        lines.add(GridLine(l, major: x % 100000 == 0, label: _lineLabel(x, spacing)));
      }
    }
    for (var y = (nMin / spacing).ceil() * spacing; y <= nMax; y += spacing) {
      final pts = [
        for (var k = 0; k <= steps; k++) utmToLatLon(zone, eMin + (eMax - eMin) * k / steps, y),
      ];
      for (final l in _clipLon(pts, lo, hi)) {
        lines.add(GridLine(l, major: y % 100000 == 0, label: _lineLabel(y, spacing)));
      }
    }
  }
  return lines;
}
