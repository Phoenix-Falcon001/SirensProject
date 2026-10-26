enum AccountKind { civilian, staff }

/// Who is signed in. Permissions and regions always come from the server;
/// the app only uses them to decide what to show.
class Session {
  const Session({
    required this.kind,
    required this.token,
    required this.expiresAt,
    this.phone,
    this.username,
    this.displayName,
    this.role,
    this.level,
    this.regions = const [],
    this.permissions = const {},
    this.allRegions = false,
  });

  final AccountKind kind;
  final String token;
  final DateTime expiresAt;

  // Civilian
  final String? phone;

  // Military / admin
  final String? username;
  final String? displayName;
  final String? role; // 'admin' | 'military'
  final String? level; // 'field' | 'analyst' | 'commander'
  final List<String> regions;
  final Set<String> permissions;
  final bool allRegions;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAdmin => role == 'admin';
  bool can(String permission) => permissions.contains(permission);

  factory Session.civilian(Map<String, dynamic> verify) => Session(
    kind: AccountKind.civilian,
    token: verify['token'] as String,
    expiresAt: DateTime.parse(verify['expires_at'] as String),
    phone: (verify['citizen'] as Map<String, dynamic>)['phone'] as String,
  );

  factory Session.staff(String token, String expiresAt, Map<String, dynamic> user) => Session(
    kind: AccountKind.staff,
    token: token,
    expiresAt: DateTime.parse(expiresAt),
    username: user['username'] as String,
    displayName: user['display_name'] as String?,
    role: user['role'] as String,
    level: user['level'] as String?,
    regions: List<String>.from(user['regions'] as List? ?? const []),
    permissions: Set<String>.from(user['permissions'] as List? ?? const []),
    allRegions: user['all_regions'] == true,
  );

  /// Same session, with the user's details refreshed from /me.
  Session withStaffUser(Map<String, dynamic> user) =>
      Session.staff(token, expiresAt.toIso8601String(), user);

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'token': token,
    'expires_at': expiresAt.toIso8601String(),
    'phone': phone,
    'username': username,
    'display_name': displayName,
    'role': role,
    'level': level,
    'regions': regions,
    'permissions': permissions.toList()..sort(),
    'all_regions': allRegions,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    kind: AccountKind.values.byName(j['kind'] as String),
    token: j['token'] as String,
    expiresAt: DateTime.parse(j['expires_at'] as String),
    phone: j['phone'] as String?,
    username: j['username'] as String?,
    displayName: j['display_name'] as String?,
    role: j['role'] as String?,
    level: j['level'] as String?,
    regions: List<String>.from(j['regions'] as List? ?? const []),
    permissions: Set<String>.from(j['permissions'] as List? ?? const []),
    allRegions: j['all_regions'] == true,
  );
}
