import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/session.dart';
import 'common.dart';
import 'menu.dart';
import 'settings_screen.dart';

void _open(BuildContext context, String title) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComingSoonScreen(title: title)));

IconButton _settingsButton(BuildContext context) => IconButton(
  key: const Key('open-settings'),
  icon: const Icon(Icons.settings_outlined),
  tooltip: AppLocalizations.of(context).settings,
  onPressed: () =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
);

class CivilianHome extends StatelessWidget {
  const CivilianHome({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle), actions: [_settingsButton(context)]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const EmergencyBanner(),
            const SizedBox(height: 16),
            for (final e in civilianMenu)
              MenuTile(
                key: Key('tile-${e.id}'),
                icon: e.icon,
                title: e.label(l),
                subtitle: civilianHint(e.id, l),
                onTap: () => _open(context, e.label(l)),
              ),
          ],
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
                  onTap: () => _open(context, e.label(l)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
