import '../api/api_client.dart';
import '../l10n/app_localizations.dart';

/// A message the user can act on, in their language.
String describeError(Object e, AppLocalizations l, {bool staff = false}) {
  if (e is! ApiException) return l.errorGeneric;
  if (e.isNetwork) return staff ? l.errorNetworkStaff : l.errorNetwork;
  final m = e.message.toLowerCase();
  if (e.status == 429) return l.errorTooMany;
  if (m.contains('locked')) return l.errorAccountLocked;
  if (m.contains('disabled')) return l.errorAccountDisabled;
  if (m.contains('wrong username')) return l.errorWrongLogin;
  if (m.contains('code')) return l.errorWrongCode;
  if (m.contains('phone number')) return l.phoneInvalid;
  return l.errorGeneric;
}
