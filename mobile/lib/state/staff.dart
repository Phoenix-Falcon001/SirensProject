import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/staff_api.dart';
import '../models/staff.dart';
import '../services/map_files.dart';
import 'drafts.dart';

enum FileOutcome { filed, queued }

class FileResult {
  const FileResult(this.outcome, {this.incidentId, this.network});

  final FileOutcome outcome;
  final String? incidentId;
  final NetworkInfo? network;
}

/// What a military or admin user does: file reports (with an offline draft
/// queue), and look things up. Analysis data is not stored on the phone;
/// only drafts waiting to be sent and the offline street map are.
class StaffService extends ChangeNotifier {
  StaffService({
    required this.api,
    required this.drafts,
    required this.maps,
    required this.username,
    required this.internalUrl,
    required this.tokenOf,
  });

  final StaffApi api;
  final DraftStore drafts;
  final MapFiles maps;
  final String username;
  final String internalUrl;
  final String? Function() tokenOf;

  List<StaffDraft> pending = [];
  List<String> regionChoices = const [];
  List<Map<String, String>> munitions = const [];
  bool _flushing = false;

  /// Form lists (cazas, munition types). Kept for the session.
  Future<void> loadMeta() async {
    final m = await api.meta();
    regionChoices = List<String>.from(m['regions'] as List);
    munitions = [
      for (final x in m['munitions'] as List)
        {'key': x['key'] as String, 'label': x['label'] as String},
    ];
    notifyListeners();
  }

  Future<void> loadPending() async {
    pending = (await drafts.all()).where((d) => d.username == username).toList();
    notifyListeners();
  }

  bool _retryable(ApiException e) => e.isNetwork || (e.status ?? 0) >= 500;

  /// Saves the report on the phone first, then files it. Without the VPN it
  /// stays queued; a refusal (e.g. caza outside your regions) is rethrown.
  Future<FileResult> file(StaffDraft d) async {
    await drafts.save(d);
    try {
      final r = await api.fileIncident({...d.body, 'client_ref': d.localId});
      await drafts.remove(d.localId);
      await loadPending();
      return FileResult(
        FileOutcome.filed,
        incidentId: r['incident_id'] as String,
        network: r['network'] == null
            ? null
            : NetworkInfo.fromJson(Map<String, dynamic>.from(r['network'] as Map)),
      );
    } on ApiException catch (e) {
      if (_retryable(e) || e.isUnauthorized) {
        await loadPending();
        return const FileResult(FileOutcome.queued);
      }
      await drafts.remove(d.localId);
      await loadPending();
      rethrow;
    }
  }

  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      for (final d in (await drafts.all()).where((d) => d.username == username)) {
        if (d.lastError != null) continue;
        try {
          await api.fileIncident({...d.body, 'client_ref': d.localId});
          await drafts.remove(d.localId);
          sent++;
        } on ApiException catch (e) {
          if (_retryable(e) || e.isUnauthorized) break;
          d.lastError = e.message;
          await drafts.save(d);
        }
      }
    } finally {
      _flushing = false;
      await loadPending();
    }
    return sent;
  }

  Future<void> discard(String localId) async {
    await drafts.remove(localId);
    await loadPending();
  }

  // -- offline map -------------------------------------------------------------
  Future<void> downloadMap(MapInfo info, void Function(int, int) onProgress) => maps.download(
    url: '$internalUrl/api/v1/map/lebanon.pmtiles',
    token: tokenOf() ?? '',
    size: info.size,
    sha256: info.sha256,
    onProgress: onProgress,
  );
}
