/// Data a civilian sees. Mirrors gateway/app.py.
library;

const reportCategories = [
  'suspicious_object',
  'unexploded_ordnance',
  'suspicious_vehicle',
  'suspicious_activity',
  'other',
];

/// Picks the text for [lang] from a {"ar","en","fr"} map, falling back to
/// English, then to whatever language is there.
String pickText(Map<String, dynamic>? texts, String lang) {
  if (texts == null || texts.isEmpty) return '';
  return (texts[lang] ?? texts['en'] ?? texts.values.first).toString();
}

class CivilReport {
  const CivilReport({
    required this.id,
    required this.submittedAt,
    required this.category,
    required this.status,
    required this.delivered,
    this.statusAt,
  });

  final String id;
  final DateTime submittedAt;
  final String category;
  final String status; // received | under_review | closed | rejected
  final DateTime? statusAt;
  final bool delivered; // collected by the Army server

  factory CivilReport.fromJson(Map<String, dynamic> j) => CivilReport(
    id: j['id'] as String,
    submittedAt: DateTime.parse(j['submitted_at'] as String),
    category: j['category'] as String,
    status: j['status'] as String,
    statusAt: j['status_at'] == null ? null : DateTime.parse(j['status_at'] as String),
    delivered: j['delivered'] == true,
  );
}

class AreaWarning {
  const AreaWarning({
    required this.id,
    required this.caza,
    required this.severity,
    required this.title,
    required this.body,
    required this.expiresAt,
  });

  final int id;
  final String caza;
  final String severity; // info | caution | danger
  final Map<String, dynamic> title;
  final Map<String, dynamic> body;
  final DateTime expiresAt;

  bool get isActive => expiresAt.isAfter(DateTime.now());

  factory AreaWarning.fromJson(Map<String, dynamic> j) => AreaWarning(
    id: j['id'] as int,
    caza: j['caza'] as String,
    severity: j['severity'] as String,
    title: Map<String, dynamic>.from(j['title'] as Map),
    body: Map<String, dynamic>.from(j['body'] as Map),
    expiresAt: DateTime.parse(j['expires_at'] as String),
  );
}

class Hotline {
  const Hotline(this.label, this.number);

  final Map<String, dynamic> label;
  final String number;

  /// Only real numbers get a call button; placeholders do not.
  bool get isDialable => RegExp(r'^\+?[0-9]{2,15}$').hasMatch(number);
}

class SafetyInfo {
  const SafetyInfo({required this.isPlaceholder, required this.hotlines, required this.steps});

  final bool isPlaceholder;
  final List<Hotline> hotlines;
  final Map<String, List<String>> steps;

  List<String> stepsFor(String lang) => steps[lang] ?? steps['en'] ?? const [];

  factory SafetyInfo.fromJson(Map<String, dynamic> j) => SafetyInfo(
    isPlaceholder: j['status'] == 'placeholder',
    hotlines: [
      for (final h in (j['hotlines'] as List? ?? const []))
        Hotline(Map<String, dynamic>.from(h['label'] as Map), h['number'].toString()),
    ],
    steps: {
      for (final e in (j['steps'] as Map? ?? const {}).entries)
        e.key as String: List<String>.from(e.value as List),
    },
  );
}
