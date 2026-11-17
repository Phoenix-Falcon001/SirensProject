import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Always-visible reminder for civilians: the app never replaces the hotline.
class EmergencyBanner extends StatelessWidget {
  const EmergencyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: c.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).emergencyBanner,
              style: TextStyle(color: c.onErrorContainer, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.primary = false,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// The main action of a screen: drawn as a dark filled tile.
  final bool primary;

  /// A small count shown at the end (e.g. links waiting for review).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final fg = primary ? c.onPrimary : c.onSurface;
    return Card(
      color: primary ? c.primary : null,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: primary ? 14 : 8),
        leading: Icon(icon, size: 30, color: primary ? c.secondary : c.onSurfaceVariant),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: fg, fontSize: primary ? 18 : null),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(color: primary ? fg.withValues(alpha: 0.75) : null)),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(fontWeight: FontWeight.w600, color: c.onPrimaryContainer),
                ),
              )
            : Icon(Icons.chevron_right, color: primary ? fg : null),
        onTap: onTap,
      ),
    );
  }
}

/// Placeholder for features built in the next steps.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).comingSoon, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
