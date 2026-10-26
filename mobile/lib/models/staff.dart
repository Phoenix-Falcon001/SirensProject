/// Data military and admin users work with. Mirrors api_bp.py.
library;

List<String> _strings(Object? v) => List<String>.from(v as List? ?? const []);

class IncidentSummary {
  const IncidentSummary({
    required this.id,
    this.date,
    this.location,
    this.caza,
    required this.summary,
  });

  final String id;
  final String? date;
  final String? location;
  final String? caza;
  final String summary;

  factory IncidentSummary.fromJson(Map<String, dynamic> j) => IncidentSummary(
    id: j['id'] as String,
    date: j['date'] as String?,
    location: j['location'] as String?,
    caza: j['caza'] as String?,
    summary: (j['summary'] as String?) ?? '',
  );
}

class IncidentDetail {
  const IncidentDetail({
    required this.id,
    this.date,
    this.location,
    this.caza,
    required this.narrative,
    required this.features,
    required this.persons,
    required this.groups,
    required this.phones,
  });

  final String id;
  final String? date;
  final String? location;
  final String? caza;
  final String narrative;
  final List<String> features; // "facet=value"
  final List<String> persons;
  final List<String> groups;
  final List<String> phones;

  factory IncidentDetail.fromJson(Map<String, dynamic> j) => IncidentDetail(
    id: j['incident_id'] as String,
    date: j['date'] as String?,
    location: j['location'] as String?,
    caza: j['caza'] as String?,
    narrative: (j['narrative'] as String?) ?? '',
    features: _strings(j['features']),
    persons: _strings(j['persons']),
    groups: _strings(j['groups']),
    phones: _strings(j['phones']),
  );
}

class NetworkLink {
  const NetworkLink({
    required this.other,
    required this.score,
    required this.band,
    required this.reasons,
    this.decision,
  });

  final IncidentSummary other;
  final double score;
  final String band;
  final List<String> reasons;
  final String? decision;

  factory NetworkLink.fromJson(Map<String, dynamic> j) => NetworkLink(
    other: IncidentSummary.fromJson(Map<String, dynamic>.from(j['other'] as Map)),
    score: (j['score'] as num).toDouble(),
    band: j['band'] as String,
    reasons: _strings(j['reasons']),
    decision: j['decision'] as String?,
  );
}

class NetworkInfo {
  const NetworkInfo({
    this.cluster,
    required this.members,
    required this.signature,
    required this.links,
    required this.tentative,
  });

  final String? cluster;
  final List<String> members;
  final List<String> signature;
  final List<NetworkLink> links;
  final bool tentative;

  factory NetworkInfo.fromJson(Map<String, dynamic> j) => NetworkInfo(
    cluster: j['cluster'] as String?,
    members: _strings(j['members']),
    signature: _strings(j['signature']),
    links: [
      for (final l in j['links'] as List? ?? const [])
        NetworkLink.fromJson(Map<String, dynamic>.from(l as Map)),
    ],
    tentative: j['tentative'] == true,
  );
}

class LinkNote {
  const LinkNote(this.note, this.analyst, this.at);

  final String note;
  final String analyst;
  final String at;
}

class LinkRow {
  const LinkRow({
    required this.a,
    required this.b,
    required this.score,
    required this.band,
    required this.reasons,
    this.decision,
    required this.notes,
  });

  final IncidentSummary a;
  final IncidentSummary b;
  final double score;
  final String band;
  final List<String> reasons;
  final String? decision;
  final List<LinkNote> notes;

  String get key => '${a.id}--${b.id}';

  factory LinkRow.fromJson(Map<String, dynamic> j) => LinkRow(
    a: IncidentSummary.fromJson(Map<String, dynamic>.from(j['a'] as Map)),
    b: IncidentSummary.fromJson(Map<String, dynamic>.from(j['b'] as Map)),
    score: (j['score'] as num).toDouble(),
    band: j['band'] as String,
    reasons: _strings(j['reasons']),
    decision: j['decision'] as String?,
    notes: [
      for (final n in j['notes'] as List? ?? const [])
        LinkNote(n['note'] as String, (n['analyst'] as String?) ?? '', (n['at'] as String?) ?? ''),
    ],
  );
}

class BriefMatch {
  const BriefMatch(this.incidentId, this.score, this.location, this.date, this.shared);

  final String incidentId;
  final double score;
  final String location;
  final String? date;
  final List<String> shared;
}

class BriefResult {
  const BriefResult({
    required this.nInArea,
    required this.objectProfile,
    required this.areaSignature,
    required this.matches,
    required this.areaIncidents,
  });

  final int nInArea;
  final List<(String, int, String?)> objectProfile;
  final List<String> areaSignature;
  final List<BriefMatch> matches;
  final List<IncidentSummary> areaIncidents;

  factory BriefResult.fromJson(Map<String, dynamic> j) => BriefResult(
    nInArea: j['n_in_area'] as int,
    objectProfile: [
      for (final o in j['object_profile'] as List)
        (o['type'] as String, o['count'] as int, o['last_seen'] as String?),
    ],
    areaSignature: _strings(j['area_signature']),
    matches: [
      for (final m in j['matches'] as List)
        BriefMatch(
          m['incident_id'] as String,
          (m['score'] as num).toDouble(),
          (m['location'] as String?) ?? '',
          m['date'] as String?,
          _strings(m['shared']),
        ),
    ],
    areaIncidents: [
      for (final i in j['area_incidents'] as List)
        IncidentSummary.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
  );
}

class MapMarker {
  const MapMarker({
    required this.id,
    required this.lat,
    required this.lon,
    required this.exact,
    required this.caza,
    required this.date,
    required this.type,
    required this.typeLabel,
    required this.color,
    required this.mgrs,
    required this.snippet,
  });

  final String id;
  final double lat;
  final double lon;
  final bool exact; // false = placed at the caza centre
  final String caza;
  final String date;
  final String type;
  final String typeLabel;
  final int color; // ARGB
  final String mgrs;
  final String snippet;

  factory MapMarker.fromJson(Map<String, dynamic> j) {
    final hex = (j['fill'] as String? ?? '#8a929a').replaceFirst('#', '');
    return MapMarker(
      id: j['id'] as String,
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
      exact: j['exact'] == true,
      caza: (j['caza'] as String?) ?? '',
      date: (j['date'] as String?) ?? '',
      type: (j['type'] as String?) ?? 'other',
      typeLabel: (j['typelabel'] as String?) ?? '',
      color: 0xFF000000 | int.parse(hex, radix: 16),
      mgrs: (j['mgrs'] as String?) ?? '',
      snippet: (j['snip'] as String?) ?? '',
    );
  }
}

/// Name/count pairs for one dashboard chart.
class Bars {
  const Bars(this.labels, this.values);

  final List<String> labels;
  final List<int> values;

  bool get isEmpty => values.every((v) => v == 0);
}

class DashboardData {
  const DashboardData({
    required this.total,
    required this.timeline,
    required this.undated,
    required this.byCaza,
    required this.byInitiation,
    required this.linkTotal,
    required this.bands,
    required this.review,
    required this.reviewedPct,
    required this.networks,
    required this.unlinked,
    required this.qualityOverall,
    required this.quality,
  });

  final int total;
  final Bars timeline;
  final int undated;
  final Bars byCaza;
  final Bars byInitiation;
  final int linkTotal;
  final Map<String, int> bands; // strong / medium / weak
  final Map<String, int> review; // confirm / reject / unsure / open
  final int reviewedPct;
  final List<(String, int, String)> networks; // id, reports in view, best band
  final int unlinked;
  final int qualityOverall;
  final Bars quality; // percent per field

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    final tl = j['timeline'] as Map;
    final ini = j['by_initiation'] as Map;
    final links = j['links'] as Map;
    final q = j['quality'] as Map;
    return DashboardData(
      total: j['total'] as int,
      timeline: Bars(_strings(tl['labels']), List<int>.from(tl['values'] as List)),
      undated: tl['undated'] as int,
      byCaza: Bars(
        [for (final c in j['by_caza'] as List) c['caza'] as String],
        [for (final c in j['by_caza'] as List) c['n'] as int],
      ),
      byInitiation: Bars(_strings(ini['labels']), List<int>.from(ini['values'] as List)),
      linkTotal: links['total'] as int,
      bands: {for (final b in links['bands'] as List) b['band'] as String: b['n'] as int},
      review: {for (final r in links['review'] as List) r['key'] as String: r['n'] as int},
      reviewedPct: links['reviewed_pct'] as int,
      networks: [
        for (final r in (j['networks'] as Map)['rows'] as List)
          (r['id'] as String, r['in_view'] as int, (r['best_band'] as String?) ?? ''),
      ],
      unlinked: (j['networks'] as Map)['unlinked'] as int,
      qualityOverall: q['overall'] as int,
      quality: Bars(
        [for (final f in q['fields'] as List) f['label'] as String],
        [for (final f in q['fields'] as List) f['pct'] as int],
      ),
    );
  }
}

class MapInfo {
  const MapInfo({required this.available, required this.size, this.sha256});

  final bool available;
  final int size;
  final String? sha256;
}
