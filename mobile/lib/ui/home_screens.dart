import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/session.dart';
import 'civilian/my_reports_screen.dart';
import 'civilian/report_screen.dart';
import 'civilian/safety_screen.dart';
import 'civilian/warnings_screen.dart';
import 'common.dart';
import 'staff/brief_screen.dart';
import 'staff/dashboard_screen.dart';
import 'staff/incidents_screen.dart';
import 'staff/map_screen.dart';
import 'staff/new_report_screen.dart';
import 'staff/review_screen.dart';
import 'menu.dart';
import 'settings_screen.dart';

IconButton _settingsButton(BuildContext context) => IconButton(
  key: const Key('open-settings'),
  icon: const Icon(Icons.settings_outlined),
  tooltip: AppLocalizations.of(context).settings,
  onPressed: () =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
);

class CivilianHome extends StatelessWidget {
  const CivilianHome({super.key});

  Widget _screen(String id, AppState state) {
    final svc = state.civilian!;
    return switch (id) {
      'report' => ReportScreen(service: svc, device: state.device),
      'my_reports' => MyReportsScreen(service: svc),
      'warnings' => WarningsScreen(service: svc, lang: state.lang),
      _ => SafetyScreen(service: svc, device: state.device, lang: state.lang),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final svc = state.civilian!;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle), actions: [_settingsButton(context)]),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: svc,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const EmergencyBanner(),
              const SizedBox(height: 16),
              for (final e in civilianMenu)
                MenuTile(
                  key: Key('tile-${e.id}'),
                  icon: e.icon,
                  title: e.label(l),
                  subtitle: e.id == 'my_reports' && svc.pending.isNotEmpty
                      ? '${civilianHint(e.id, l)} · ${l.pendingSection}: ${svc.pending.length}'
                      : civilianHint(e.id, l),
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => _screen(e.id, state))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String roleLabel(Session s, AppLocalizations l) {
  if (s.isAdmin) return l.roleAdmin;
  return switch (s.level) {
    'commander' => l.levelCommander,
    'analyst' => l.levelAnalyst,
    _ => l.levelField,
  };
}

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  void _openStaff(BuildContext context, MenuEntry e, AppState state) {
    final svc = state.staffService!;
    final s = state.session!;
    // Admins may pick any caza; military users only their own.
    final regions = s.allRegions ? svc.regionChoices : s.regions;
    final Widget screen = switch (e.id) {
      'new_report' => NewReportScreen(service: svc, device: state.device, regions: regions),
      'incidents' => IncidentsScreen(service: svc),
      'brief' => BriefScreen(service: svc),
      'map' => MapScreen(service: svc),
      'review' => ReviewScreen(service: svc),
      'dashboard' => DashboardScreen(service: svc, regions: regions),
      _ => ComingSoonScreen(title: e.label(AppLocalizations.of(context))),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final s = state.session!;
    final name = (s.displayName?.isNotEmpty ?? false) ? s.displayName! : s.username!;
    final menu = staffMenu(s);
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle), actions: [_settingsButton(context)]),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refreshStaff,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.staffGreeting(name), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    key: const Key('role-chip'),
                    avatar: const Icon(Icons.badge_outlined, size: 18),
                    label: Text(roleLabel(s, l)),
                  ),
                  if (s.allRegions)
                    Chip(avatar: const Icon(Icons.public, size: 18), label: Text(l.allRegions))
                  else
                    for (final r in s.regions)
                      Chip(avatar: const Icon(Icons.place_outlined, size: 18), label: Text(r)),
                ],
              ),
              const SizedBox(height: 16),
              for (final e in menu)
                MenuTile(
                  key: Key('tile-${e.id}'),
                  icon: e.icon,
                  title: e.label(l),
                  onTap: () => _openStaff(context, e, state),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
