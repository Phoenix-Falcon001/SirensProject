import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// A report saved on the phone until the gateway confirms it.
class PendingReport {
  PendingReport({
    required this.localId,
    required this.phone,
    required this.observedAt,
    required this.category,
    required this.description,
    this.lat,
    this.lon,
    this.accuracyM,
    this.photo,
    this.lastError,
  });

  /// Also sent as client_ref, so a retry never creates a second report.
  final String localId;

  /// Only the account that wrote it may send it.
  final String phone;
  final DateTime observedAt;
  final String category;
  final String description;
  final double? lat;
  final double? lon;
  final double? accuracyM;
  final Uint8List? photo;

  /// Set when the gateway refused it (will not be retried automatically).
  String? lastError;

  static String newId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Map<String, dynamic> toJson() => {
    'local_id': localId,
    'phone': phone,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'category': category,
    'description': description,
    'lat': lat,
    'lon': lon,
    'accuracy_m': accuracyM,
    'last_error': lastError,
  };

  factory PendingReport.fromJson(Map<String, dynamic> j, Uint8List? photo) => PendingReport(
    localId: j['local_id'] as String,
    phone: j['phone'] as String,
    observedAt: DateTime.parse(j['observed_at'] as String),
    category: j['category'] as String,
    description: j['description'] as String,
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
    accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
    photo: photo,
    lastError: j['last_error'] as String?,
  );
}

abstract class OutboxStore {
  Future<List<PendingReport>> all();
  Future<void> save(PendingReport r);
  Future<void> remove(String localId);
}

/// Files in the app's private support folder (not backed up, not visible to
/// other apps): `<id>.json` plus `<id>.photo`.
class FileOutboxStore implements OutboxStore {
  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/outbox');
    return d.create(recursive: true);
  }

  @override
  Future<List<PendingReport>> all() async {
    final d = await _dir();
    final out = <PendingReport>[];
    for (final f in d.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      try {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final p = File(f.path.replaceFirst(RegExp(r'\.json$'), '.photo'));
        out.add(PendingReport.fromJson(j, await p.exists() ? await p.readAsBytes() : null));
      } on Object {
        await f.delete(); // unreadable leftovers must not block the queue
      }
    }
    out.sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return out;
  }

  @override
  Future<void> save(PendingReport r) async {
    final d = await _dir();
    if (r.photo != null) await File('${d.path}/${r.localId}.photo').writeAsBytes(r.photo!);
    await File('${d.path}/${r.localId}.json').writeAsString(jsonEncode(r.toJson()));
  }

  @override
  Future<void> remove(String localId) async {
    final d = await _dir();
    for (final ext in ['json', 'photo']) {
      final f = File('${d.path}/$localId.$ext');
      if (await f.exists()) await f.delete();
    }
  }
}

class MemoryOutboxStore implements OutboxStore {
  final Map<String, PendingReport> items = {};

  @override
  Future<List<PendingReport>> all() async =>
      items.values.toList()..sort((a, b) => a.observedAt.compareTo(b.observedAt));

  @override
  Future<void> save(PendingReport r) async => items[r.localId] = r;

  @override
  Future<void> remove(String localId) async => items.remove(localId);
}
