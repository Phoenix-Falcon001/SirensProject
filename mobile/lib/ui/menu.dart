import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/session.dart';

/// One tile on a home screen. [permission] is the server permission that
/// must be present for the tile to appear (null = always shown).
class MenuEntry {
  const MenuEntry(this.id, this.permission, this.icon, this.label);

  final String id;
  final String? permission;
  final IconData icon;
  final String Function(AppLocalizations) label;
}

final List<MenuEntry> _staffEntries = [
  MenuEntry('new_report', 'incidents:create', Icons.edit_note, (l) => l.menuNewReport),
  MenuEntry('incidents', 'incidents:read', Icons.list_alt, (l) => l.menuIncidents),
  MenuEntry('brief', 'brief', Icons.assignment_outlined, (l) => l.menuBrief),
  MenuEntry('map', 'map', Icons.map_outlined, (l) => l.menuMap),
  MenuEntry('review', 'review', Icons.fact_check_outlined, (l) => l.menuReview),
  MenuEntry('dashboard', 'dashboard', Icons.insights_outlined, (l) => l.menuDashboard),
  MenuEntry('civil_reports', 'civil_reports', Icons.inbox_outlined, (l) => l.menuCivilReports),
  MenuEntry('warnings', 'warnings:publish', Icons.campaign_outlined, (l) => l.menuWarnings),
  MenuEntry('users', 'users:manage', Icons.manage_accounts_outlined, (l) => l.menuUsers),
  MenuEntry('audit', 'audit:read', Icons.history, (l) => l.menuAudit),
];

/// Tiles for a military or admin user, decided by the permissions the server
/// gave this account.
List<MenuEntry> staffMenu(Session s) => [
  for (final e in _staffEntries)
    if (e.permission == null || s.can(e.permission!)) e,
];

final List<MenuEntry> civilianMenu = [
  MenuEntry('report', null, Icons.report_outlined, (l) => l.reportObject),
  MenuEntry('my_reports', null, Icons.receipt_long_outlined, (l) => l.myReports),
  MenuEntry('warnings', null, Icons.warning_amber_outlined, (l) => l.warnings),
  MenuEntry('safety', null, Icons.health_and_safety_outlined, (l) => l.safety),
];

String civilianHint(String id, AppLocalizations l) => switch (id) {
  'report' => l.reportObjectHint,
  'my_reports' => l.myReportsHint,
  'warnings' => l.warningsHint,
  _ => l.safetyHint,
};
