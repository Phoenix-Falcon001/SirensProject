import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../geo/mgrs.dart';
import '../../geo/street_map.dart';
import '../../l10n/app_localizations.dart';
import '../../models/staff.dart';
import '../../services/map_files.dart';
import '../../state/staff.dart';
import '../errors.dart';
import 'incidents_screen.dart';

final lebanonBounds = LatLngBounds(const LatLng(33.0, 35.0), const LatLng(34.75, 36.7));

/// Offline map: street map (once downloaded), caza outlines, MGRS grid,
/// incident markers, and the MGRS reference of the map centre.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.service});

  final StaffService service;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();
  Map<String, List<List<LatLng>>> _outlines = const {};
  List<MapMarker> _markers = const [];
  StreetMap? _street;
  MapInfo? _info;
  bool _showGrid = true;
  LatLng _centre = const LatLng(33.85, 35.86);
  double _zoom = 8;
  LatLngBounds? _view;
  double? _progress; // 0..1 while downloading
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _outlines = await loadCazaOutlines();
    if (!mounted) return;
    setState(() {});
    final l = AppLocalizations.of(context); // only after initState has finished
    await _openStreetMap();
    try {
      final markers = await widget.service.api.markers();
      if (mounted) setState(() => _markers = markers);
    } on Object catch (e) {
      if (mounted) setState(() => _status = describeError(e, l, staff: true));
    }
    if (_street == null) {
      try {
        final info = await widget.service.api.mapInfo();
        if (mounted) setState(() => _info = info);
      } on Object {
        // offline: nothing to offer; the outlines and grid still work
      }
    }
  }

  Future<void> _openStreetMap() async {
    final path = await widget.service.maps.localMap();
    if (path == null) return;
    try {
      final m = await StreetMap.open(path);
      if (mounted) setState(() => _street = m);
    } on Object {
      // A damaged file: offer the download again.
      await widget.service.maps.delete();
    }
  }

  Future<void> _download() async {
    final l = AppLocalizations.of(context);
    final info = _info!;
    setState(() {
      _progress = 0;
      _status = null;
    });
    try {
      await widget.service.downloadMap(info, (done, total) {
        if (mounted) setState(() => _progress = total == 0 ? 0 : done / total);
      });
      await _openStreetMap();
    } on Object catch (e) {
      final reason = e is MapDownloadException ? e.message : describeError(e, l, staff: true);
      if (mounted) setState(() => _status = l.mapDownloadFailed(reason));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  void _moved(MapCamera camera, bool _) {
    setState(() {
      _centre = camera.center;
      _zoom = camera.zoom;
      _view = camera.visibleBounds;
    });
  }

  List<Polyline> _gridLines(ColorScheme c) {
    final v = _view;
    if (!_showGrid || v == null) return const [];
    final spacing = gridSpacingForZoom(_zoom);
    return [
      for (final g in gridLines(v.south, v.west, v.north, v.east, spacing))
        Polyline(
          points: [for (final p in g.points) LatLng(p.$1, p.$2)],
          color: c.primary.withValues(alpha: g.major ? 0.7 : 0.35),
          strokeWidth: g.major ? 1.6 : 0.8,
        ),
    ];
  }

  void _showMarker(MapMarker m) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: Key('marker-sheet-${m.id}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.id} · ${m.typeLabel}', style: Theme.of(c).textTheme.titleMedium),
            Text([m.date, m.caza].where((s) => s.isNotEmpty).join(' · ')),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l.gridRef(m.mgrs), style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  tooltip: l.copy,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: m.mgrs)),
                ),
              ],
            ),
            Text(m.exact ? l.mapExact : l.mapApprox, style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(m.snippet),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('marker-open'),
              onPressed: () {
                Navigator.pop(c);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IncidentDetailScreen(service: widget.service, id: m.id),
                  ),
                );
              },
              child: Text(l.openReport),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCentre() async {
    final l = AppLocalizations.of(context);
    final ref = toMgrs(_centre.latitude, _centre.longitude);
    await Clipboard.setData(ClipboardData(text: ref));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.mapCopied(ref))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final centreRef = toMgrs(_centre.latitude, _centre.longitude);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.menuMap),
        actions: [
          IconButton(
            key: const Key('toggle-grid'),
            tooltip: l.mapGrid,
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off),
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          if (_street != null)
            PopupMenuButton<String>(
              onSelected: (_) async {
                await widget.service.maps.delete();
                setState(() => _street = null);
                _load();
              },
              itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(l.mapDeleteMap))],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_street == null)
            Material(
              color: c.surfaceContainerHighest,
              child: ListTile(
                key: const Key('map-banner'),
                leading: const Icon(Icons.map_outlined),
                title: Text(l.mapNoStreetMap),
                subtitle: _progress != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.mapDownloading((_progress! * 100).round())),
                          LinearProgressIndicator(value: _progress),
                        ],
                      )
                    : _info == null
                    ? null
                    : !_info!.available
                    ? Text(l.mapNotOnServer)
                    : Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          key: const Key('map-download'),
                          onPressed: _download,
                          icon: const Icon(Icons.download),
                          label: Text(l.mapDownload((_info!.size / 1048576).toStringAsFixed(0))),
                        ),
                      ),
              ),
            ),
          if (_status != null)
            Material(
              color: c.errorContainer,
              child: ListTile(dense: true, title: Text(_status!, key: const Key('map-status'))),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _centre,
                    initialZoom: _zoom,
                    minZoom: 7,
                    maxZoom: 17,
                    backgroundColor: c.surface,
                    cameraConstraint: CameraConstraint.containCenter(bounds: lebanonBounds),
                    onPositionChanged: _moved,
                    onMapReady: () => _moved(_controller.camera, false),
                  ),
                  children: [
                    if (_street != null) _street!.layer(),
                    PolygonLayer(
                      polygons: [
                        for (final rings in _outlines.values)
                          for (final ring in rings)
                            Polygon(
                              points: ring,
                              color: _street == null ? c.primary.withValues(alpha: 0.04) : null,
                              borderColor: c.outline,
                              borderStrokeWidth: 1,
                            ),
                      ],
                    ),
                    PolylineLayer(polylines: _gridLines(c)),
                    MarkerLayer(
                      markers: [
                        for (final m in _markers)
                          Marker(
                            point: LatLng(m.lat, m.lon),
                            width: 30,
                            height: 30,
                            child: GestureDetector(
                              key: Key('marker-${m.id}'),
                              onTap: () => _showMarker(m),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(m.color),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: m.exact ? 3 : 1.5),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_street != null)
                      const SimpleAttributionWidget(source: Text('© OpenStreetMap contributors')),
                  ],
                ),
                // Crosshair at the centre: the reference below is for this point.
                IgnorePointer(
                  child: Center(child: Icon(Icons.add, size: 32, color: c.onSurface)),
                ),
              ],
            ),
          ),
          Material(
            elevation: 4,
            child: ListTile(
              key: const Key('centre-ref'),
              leading: const Icon(Icons.my_location),
              title: Text(
                l.mapCentre(centreRef),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(l.mapZoneNote),
              trailing: IconButton(
                key: const Key('copy-centre'),
                tooltip: l.copy,
                icon: const Icon(Icons.copy),
                onPressed: _copyCentre,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
