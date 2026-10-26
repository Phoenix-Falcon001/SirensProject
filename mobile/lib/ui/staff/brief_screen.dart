import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/staff.dart';
import '../../state/staff.dart';
import '../errors.dart';
import 'incidents_screen.dart';
import 'staff_common.dart';

/// Pre-arrival brief: what has been reported before at a place, in the
/// user's regions. Retrieval only; never identifies an object, never gives
/// handling guidance.
class BriefScreen extends StatefulWidget {
  const BriefScreen({super.key, required this.service});

  final StaffService service;

  @override
  State<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends State<BriefScreen> {
  final _location = TextEditingController();
  final _describe = TextEditingController();
  BriefResult? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _location.dispose();
    _describe.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    if (_location.text.trim().isEmpty) {
      setState(() => _error = l.fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.service.api.brief(_location.text.trim(), _describe.text.trim());
      if (mounted) setState(() => _result = r);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e, l, staff: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String id) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => IncidentDetailScreen(service: widget.service, id: id),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.menuBrief)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.briefNote, key: const Key('brief-note')),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('brief-location'),
            controller: _location,
            decoration: InputDecoration(
              labelText: l.briefLocation,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('brief-describe'),
            controller: _describe,
            decoration: InputDecoration(
              labelText: l.briefDescribe,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('brief-run'),
            onPressed: _busy ? null : _run,
            icon: const Icon(Icons.search),
            label: Text(l.briefRun),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (r != null) ...[
            const SizedBox(height: 16),
            Text(l.briefInArea(r.nInArea), style: t.titleLarge, key: const Key('brief-count')),
            if (r.nInArea == 0 && r.matches.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.briefNone)),
            if (r.objectProfile.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.briefObjects, style: t.titleMedium),
              for (final (type, n, last) in r.objectProfile)
                ListTile(
                  dense: true,
                  title: Text(featureLabel(type)),
                  subtitle: last == null ? null : Text(l.lastSeen(last)),
                  trailing: Text('$n', style: t.titleMedium),
                ),
            ],
            if (r.areaSignature.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.briefSignature, style: t.titleMedium),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final s in r.areaSignature) Chip(label: Text(featureLabel(s)))],
              ),
            ],
            if (r.matches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.briefMatches, style: t.titleMedium),
              for (final m in r.matches)
                Card(
                  child: ListTile(
                    title: Text('${m.incidentId} · ${m.location}'),
                    subtitle: Text(m.shared.map(featureLabel).join(' · ')),
                    trailing: Text(m.score.toStringAsFixed(2)),
                    onTap: () => _open(m.incidentId),
                  ),
                ),
            ],
            if (r.areaIncidents.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l.briefIncidents, style: t.titleMedium),
              for (final i in r.areaIncidents)
                ListTile(
                  title: Text('${i.id} · ${i.date ?? ''}'),
                  subtitle: Text(i.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _open(i.id),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
