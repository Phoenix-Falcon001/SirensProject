import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../api/api_client.dart';
import '../api/gateway_api.dart';
import '../models/civilian.dart';
import 'outbox.dart';
import 'storage.dart';

enum SubmitOutcome { sent, queued }

class SubmitResult {
  const SubmitResult(this.outcome, [this.reportId]);

  final SubmitOutcome outcome;
  final String? reportId;
}

/// Result of loading something that is cached for offline use.
class Cached<T> {
  const Cached(this.value, {required this.fromCache, this.savedAt});

  final T value;
  final bool fromCache;
  final DateTime? savedAt;
}

/// Everything a signed-in civilian does: send reports (through the outbox),
/// follow them, read warnings and the safety page.
class CivilianService extends ChangeNotifier {
  CivilianService({
    required this.api,
    required this.outbox,
    required this.cache,
    required this.phone,
  });

  final GatewayApi api;
  final OutboxStore outbox;
  final KeyValueStore cache;
  final String phone;

  static const _warningsKey = 'cache.warnings';
  static const _safetyKey = 'cache.safety';
  static const safetyAsset = 'assets/safety_fallback.json';

  List<PendingReport> pending = [];
  List<CivilReport> reports = [];
  DateTime? reportsLoadedAt;
  bool _flushing = false;

  Future<void> loadPending() async {
    pending = (await outbox.all()).where((r) => r.phone == phone).toList();
    notifyListeners();
  }

  /// Saves the report on the phone first, then tries to send it. A report is
  /// never lost to a bad connection: it stays queued until the gateway has it.
  /// Refusals by the gateway (e.g. daily limit) are rethrown and nothing is kept.
  Future<SubmitResult> submit(PendingReport r) async {
    await outbox.save(r);
    try {
      final id = await _send(r);
      await outbox.remove(r.localId);
      await loadPending();
      return SubmitResult(SubmitOutcome.sent, id);
    } on ApiException catch (e) {
      // Offline, server trouble, or session ended: keep it and send later
      // (after signing in again with the same number).
      if (_retryable(e) || e.isUnauthorized) {
        await loadPending();
        return const SubmitResult(SubmitOutcome.queued);
      }
      await outbox.remove(r.localId);
      await loadPending();
      rethrow;
    }
  }

  bool _retryable(ApiException e) => e.isNetwork || (e.status ?? 0) >= 500;

  Future<String> _send(PendingReport r) async {
    final res = await api.submitReport(r);
    return res['id'] as String;
  }

  /// Sends whatever is waiting. Returns how many went out.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      for (final r in (await outbox.all()).where((r) => r.phone == phone)) {
        if (r.lastError != null) continue;
        try {
          await _send(r);
          await outbox.remove(r.localId);
          sent++;
        } on ApiException catch (e) {
          if (_retryable(e)) break; // still offline: try again later
          if (e.isUnauthorized) break; // signed out; keep it for this account
          r.lastError = e.message;
          await outbox.save(r);
        }
      }
    } finally {
      _flushing = false;
      await loadPending();
    }
    return sent;
  }

  Future<void> discard(String localId) async {
    await outbox.remove(localId);
    await loadPending();
  }

  /// Removes this account's queued reports (used when the account is deleted).
  Future<void> clearPending() async {
    for (final r in await outbox.all()) {
      if (r.phone == phone) await outbox.remove(r.localId);
    }
    await loadPending();
  }

  Future<void> refreshReports() async {
    reports = await api.myReports();
    reportsLoadedAt = DateTime.now();
    notifyListeners();
  }

  /// Active warnings; falls back to the last copy when offline.
  Future<Cached<List<AreaWarning>>> warnings() async {
    try {
      final raw = await api.warnings();
      await cache.write(
        _warningsKey,
        jsonEncode({'at': DateTime.now().toIso8601String(), 'warnings': raw}),
      );
      return Cached(_parseWarnings(raw), fromCache: false);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final saved = await cache.read(_warningsKey);
      if (saved == null) rethrow;
      final j = jsonDecode(saved) as Map<String, dynamic>;
      return Cached(
        _parseWarnings(j['warnings'] as List),
        fromCache: true,
        savedAt: DateTime.parse(j['at'] as String),
      );
    }
  }

  List<AreaWarning> _parseWarnings(List raw) =>
      [for (final w in raw) AreaWarning.fromJson(Map<String, dynamic>.from(w as Map))]
          .where((w) => w.isActive)
          .toList()
        ..sort((a, b) => _rank(a).compareTo(_rank(b)));

  int _rank(AreaWarning w) => switch (w.severity) {
    'danger' => 0,
    'caution' => 1,
    _ => 2,
  };

  /// Safety page: from the gateway, else the last copy, else the copy bundled
  /// in the app, so the hotline numbers are there even on first use offline.
  Future<Cached<SafetyInfo>> safety() async {
    try {
      final raw = await api.safety();
      await cache.write(_safetyKey, jsonEncode(raw));
      return Cached(SafetyInfo.fromJson(raw), fromCache: false);
    } on ApiException {
      final saved = await cache.read(_safetyKey);
      final j = saved ?? await rootBundle.loadString(safetyAsset);
      return Cached(SafetyInfo.fromJson(jsonDecode(j) as Map<String, dynamic>), fromCache: true);
    }
  }
}
