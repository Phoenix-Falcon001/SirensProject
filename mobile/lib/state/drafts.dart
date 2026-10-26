import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A military report filed while the Army server could not be reached.
class StaffDraft {
  StaffDraft({
    required this.localId,
    required this.username,
    required this.savedAt,
    required this.body,
    this.lastError,
  });

  final String localId; // sent as client_ref: retries never file twice
  final String username; // only this account sends it
  final DateTime savedAt;
  final Map<String, dynamic> body; // the POST /api/v1/incidents body
  String? lastError;

  Map<String, dynamic> toJson() => {
    'local_id': localId,
    'username': username,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'body': body,
    'last_error': lastError,
  };

  factory StaffDraft.fromJson(Map<String, dynamic> j) => StaffDraft(
    localId: j['local_id'] as String,
    username: j['username'] as String,
    savedAt: DateTime.parse(j['saved_at'] as String),
    body: Map<String, dynamic>.from(j['body'] as Map),
    lastError: j['last_error'] as String?,
  );
}

abstract class DraftStore {
  Future<List<StaffDraft>> all();
  Future<void> save(StaffDraft d);
  Future<void> remove(String localId);
}

/// One JSON file per draft in the app's private support folder.
class FileDraftStore implements DraftStore {
  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/drafts');
    return d.create(recursive: true);
  }

  @override
  Future<List<StaffDraft>> all() async {
    final out = <StaffDraft>[];
    for (final f in (await _dir()).listSync().whereType<File>()) {
      try {
        out.add(StaffDraft.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>));
      } on Object {
        await f.delete();
      }
    }
    return out..sort((a, b) => a.savedAt.compareTo(b.savedAt));
  }

  @override
  Future<void> save(StaffDraft d) async =>
      File('${(await _dir()).path}/${d.localId}.json').writeAsString(jsonEncode(d.toJson()));

  @override
  Future<void> remove(String localId) async {
    final f = File('${(await _dir()).path}/$localId.json');
    if (await f.exists()) await f.delete();
  }
}

class MemoryDraftStore implements DraftStore {
  final Map<String, StaffDraft> items = {};

  @override
  Future<List<StaffDraft>> all() async =>
      items.values.toList()..sort((a, b) => a.savedAt.compareTo(b.savedAt));

  @override
  Future<void> save(StaffDraft d) async => items[d.localId] = d;

  @override
  Future<void> remove(String localId) async => items.remove(localId);
}
