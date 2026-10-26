import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/civilian.dart';
import '../../state/civilian.dart';
import '../errors.dart';
import 'labels.dart';

/// Active warnings published by the Army. Fetched when opened and on
/// pull-to-refresh (push notifications are off until the Army decides);
/// the last copy is shown when offline.
class WarningsScreen extends StatefulWidget {
  const WarningsScreen({super.key, required this.service, required this.lang});

  final CivilianService service;
  final String lang;

  @override
  State<WarningsScreen> createState() => _WarningsScreenState();
}

class _WarningsScreenState extends State<WarningsScreen> {
  Cached<List<AreaWarning>>? _data;
  Object? _error;
  String? _caza; // null = all areas
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.service.warnings();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({Color bg, Color fg, IconData icon}) _look(String severity, ColorScheme c) => switch (severity) {
    'danger' => (bg: c.errorContainer, fg: c.onErrorContainer, icon: Icons.dangerous_outlined),
    'caution' => (
      bg: c.tertiaryContainer,
      fg: c.onTertiaryContainer,
      icon: Icons.warning_amber_outlined,
    ),
    _ => (bg: c.secondaryContainer, fg: c.onSecondaryContainer, icon: Icons.info_outline),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final all = _data?.value ?? const <AreaWarning>[];
    final areas = {for (final w in all) w.caza}.toList()..sort();
    final shown = [
      for (final w in all)
        if (_caza == null || w.caza == _caza) w,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.warnings)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading && _data == null) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: Text(describeError(_error!, l)),
                ),
              ),
            if (_data?.fromCache ?? false)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: Text(l.showingSaved(formatWhen(context, _data!.savedAt!))),
                ),
              ),
            if (areas.length > 1)
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(l.warningsAllAreas),
                    selected: _caza == null,
                    onSelected: (_) => setState(() => _caza = null),
                  ),
                  for (final a in areas)
                    ChoiceChip(
                      key: Key('area-$a'),
                      label: Text(a),
                      selected: _caza == a,
                      onSelected: (_) => setState(() => _caza = a),
                    ),
                ],
              ),
            if (_data != null && shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 40),
                    const SizedBox(height: 8),
                    Text(l.warningsEmpty, textAlign: TextAlign.center),
                  ],
                ),
              ),
            for (final w in shown)
              Builder(
                builder: (context) {
                  final look = _look(w.severity, c);
                  return Card(
                    key: Key('warning-${w.id}'),
                    color: look.bg,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: look.fg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(look.icon, color: look.fg),
                                const SizedBox(width: 8),
                                Text(
                                  '${severityLabel(w.severity, l)} · ${w.caza}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pickText(w.title, widget.lang),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: look.fg),
                            ),
                            const SizedBox(height: 4),
                            Text(pickText(w.body, widget.lang)),
                            const SizedBox(height: 8),
                            Text(
                              l.warningsUntil(formatWhen(context, w.expiresAt)),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Text(
              l.warningsPullHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
