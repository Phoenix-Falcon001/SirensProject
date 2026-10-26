import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../state/civilian.dart';
import '../common.dart';
import '../errors.dart';
import 'labels.dart';

/// The civilian's own reports: those still on the phone, then those sent,
/// with their status. Never any investigation details.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key, required this.service});

  final CivilianService service;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = widget.service;
    await s.flush();
    try {
      await s.refreshReports();
      if (mounted) setState(() => _offline = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _offline = e.isNetwork);
      if (!e.isNetwork) showMessage(context, describeError(e, AppLocalizations.of(context)));
    }
  }

  Color _statusColor(String status, ColorScheme c) => switch (status) {
    'under_review' => c.tertiaryContainer,
    'closed' => c.secondaryContainer,
    'rejected' => c.surfaceContainerHighest,
    _ => c.primaryContainer,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.myReports)),
      body: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final s = widget.service;
          final empty = s.pending.isEmpty && s.reports.isEmpty;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_offline)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_off),
                      title: Text(l.errorNetwork),
                    ),
                  ),
                if (s.pending.isNotEmpty) ...[
                  Text(l.pendingSection, style: Theme.of(context).textTheme.titleMedium),
                  for (final p in s.pending)
                    Card(
                      key: Key('pending-${p.localId}'),
                      child: ListTile(
                        leading: const Icon(Icons.schedule_send_outlined),
                        title: Text(categoryLabel(p.category, l)),
                        subtitle: Text(
                          p.lastError == null
                              ? l.savedOn(formatWhen(context, p.observedAt))
                              : l.notSentReason(p.lastError!),
                        ),
                        trailing: p.lastError == null
                            ? null
                            : TextButton(
                                onPressed: () => s.discard(p.localId),
                                child: Text(l.discard),
                              ),
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      key: const Key('send-now'),
                      onPressed: _refresh,
                      icon: const Icon(Icons.send),
                      label: Text(l.sendNow),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (s.reports.isNotEmpty) ...[
                  Text(l.sentSection, style: Theme.of(context).textTheme.titleMedium),
                  for (final r in s.reports)
                    Card(
                      key: Key('report-${r.id}'),
                      child: ListTile(
                        title: Text(categoryLabel(r.category, l)),
                        subtitle: Text(
                          [
                            l.sentOn(formatWhen(context, r.submittedAt)),
                            '\u2066${r.id}\u2069',
                            if (r.delivered) l.deliveredToArmy,
                          ].join(' · '),
                        ),
                        trailing: Chip(
                          label: Text(statusLabel(r.status, l)),
                          backgroundColor: _statusColor(r.status, c),
                        ),
                      ),
                    ),
                ],
                if (empty && !_offline)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l.myReportsEmpty, textAlign: TextAlign.center),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
