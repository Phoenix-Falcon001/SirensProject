import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

String categoryLabel(String c, AppLocalizations l) => switch (c) {
  'suspicious_object' => l.catSuspiciousObject,
  'unexploded_ordnance' => l.catUnexplodedOrdnance,
  'suspicious_vehicle' => l.catSuspiciousVehicle,
  'suspicious_activity' => l.catSuspiciousActivity,
  _ => l.catOther,
};

String statusLabel(String s, AppLocalizations l) => switch (s) {
  'under_review' => l.statusUnderReview,
  'closed' => l.statusClosed,
  'rejected' => l.statusRejected,
  _ => l.statusReceived,
};

String severityLabel(String s, AppLocalizations l) => switch (s) {
  'danger' => l.severityDanger,
  'caution' => l.severityCaution,
  _ => l.severityInfo,
};

/// Date and time in the user's language, in local time.
String formatWhen(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).languageCode;
  return DateFormat.yMMMd(locale).add_Hm().format(t.toLocal());
}
