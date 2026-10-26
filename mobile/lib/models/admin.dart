/// Data for commanders and admins. Mirrors api_bp.py and linker/civil.py.
library;

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// A civilian report as the Army sees it (commander+).
class CivilReportFull {
  const CivilReportFull({
    required this.id,
    required this.submittedAt,
    this.observedAt,
    required this.category,
    required this.description,
    this.lat,
    this.lon,
    this.accuracyM,
    this.caza,
    this.mgrs,
    this.reporterPhone,
    required this.hasPhoto,
    required this.status,
    required this.statusNote,
    this.statusBy,
    this.statusAt,
  });

  final String id;
  final DateTime submittedAt;
  final DateTime? observedAt;
  final String category;
  final String description;
  final double? lat;
  final double? lon;
  final double? accuracyM;
  final String? caza;
  final String? mgrs;
  final String? reporterPhone; // null if the account was deleted
  final bool hasPhoto;
  final String status;
  final String statusNote;
  final String? statusBy;
  final DateTime? statusAt;

  factory CivilReportFull.fromJson(Map<String, dynamic> j) => CivilReportFull(
    id: j['id'] as String,
    submittedAt: DateTime.parse(j['submitted_at'] as String),
    observedAt: _date(j['observed_at']),
    category: (j['category'] as String?) ?? 'other',
    description: (j['description'] as String?) ?? '',
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
    accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
    caza: j['caza'] as String?,
    mgrs: j['mgrs'] as String?,
    reporterPhone: j['reporter_phone'] as String?,
    hasPhoto: j['has_photo'] == true,
    status: j['status'] as String,
    statusNote: (j['status_note'] as String?) ?? '',
    statusBy: j['status_by'] as String?,
    statusAt: _date(j['status_at']),
  );
}

/// A warning as commanders manage it (includes who wrote it, withdrawn ones).
class StaffWarning {
  const StaffWarning({
    required this.id,
    required this.caza,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    required this.withdrawn,
  });

  final int id;
  final String caza;
  final String severity;
  final Map<String, dynamic> title;
  final Map<String, dynamic> body;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool withdrawn;

  bool get isLive => !withdrawn && expiresAt.isAfter(DateTime.now());

  factory StaffWarning.fromJson(Map<String, dynamic> j) => StaffWarning(
    id: j['id'] as int,
    caza: j['caza'] as String,
    severity: j['severity'] as String,
    title: Map<String, dynamic>.from(j['title'] as Map),
    body: Map<String, dynamic>.from(j['body'] as Map),
    createdBy: (j['created_by'] as String?) ?? '',
    createdAt: DateTime.parse(j['created_at'] as String),
    expiresAt: DateTime.parse(j['expires_at'] as String),
    withdrawn: j['withdrawn'] == true,
  );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.level,
    required this.regions,
    required this.active,
  });

  final int id;
  final String username;
  final String displayName;
  final String role;
  final String? level;
  final List<String> regions;
  final bool active;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] as int,
    username: j['username'] as String,
    displayName: (j['display_name'] as String?) ?? '',
    role: j['role'] as String,
    level: j['level'] as String?,
    regions: List<String>.from(j['regions'] as List? ?? const []),
    active: j['active'] == true,
  );
}

class AuditEntry {
  const AuditEntry(this.at, this.actor, this.action, this.detail);

  final DateTime at;
  final String actor;
  final String action;
  final Map<String, dynamic> detail;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    DateTime.parse(j['at'] as String),
    j['actor'] as String,
    j['action'] as String,
    Map<String, dynamic>.from(j['detail'] as Map? ?? const {}),
  );
}
