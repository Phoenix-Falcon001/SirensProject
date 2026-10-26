import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/staff.dart';
import '../../state/staff.dart';
import 'staff_common.dart';

/// Reports in the user's regions, newest first, with search and caza filter.
class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key, required this.service});

  final StaffService service;

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  String _query = '';
  String? _caza;

  bool _matches(IncidentSummary i) {
    if (_caza != null && i.caza != _caza) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [i.id, i.location ?? '', i.summary].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuIncidents)),
      body: Loader<List<IncidentSummary>>(
        load: widget.service.api.incidents,
        builder: (context, all, reload) {
          final cazas = {for (final i in all) i.caza}.whereType<String>().toList()..sort();
          final shown = all.where(_matches).toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                TextField(
                  key: const Key('incident-search'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.searchHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                if (cazas.length > 1) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(l.allCazas),
                        selected: _caza == null,
                        onSelected: (_) => setState(() => _caza = null),
                      ),
                      for (final c in cazas)
                        ChoiceChip(
                          label: Text(c),
                          selected: _caza == c,
                          onSelected: (_) => setState(() => _caza = c),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(l.incidentsEmpty, textAlign: TextAlign.center),
                  ),
                for (final i in shown)
                  Card(
                    key: Key('incident-${i.id}'),
                    child: ListTile(
                      title: Text('${i.id} · ${i.location ?? ''}'),
                      subtitle: Text(
                        [i.date ?? '', i.summary].where((s) => s.isNotEmpty).join('\n'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => IncidentDetailScreen(service: widget.service, id: i.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({super.key, required this.service, required this.id});

  final StaffService service;
  final String id;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(id)),
      body: Loader<(IncidentDetail, NetworkInfo)>(
        load: () async => (await service.api.incident(id), await service.api.network(id)),
        builder: (context, data, _) {
          final (inc, net) = data;
          Widget section(String title, List<String> items) => items.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.labelLarge),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final x in items)
                            Chip(
                              label: Text(featureLabel(x)),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                [inc.date, inc.location, inc.caza].whereType<String>().join(' · '),
                style: t.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(l.narrative, style: t.labelLarge),
              SelectableText(inc.narrative),
              section(l.extractedFeatures, inc.features),
              section(l.people, inc.persons),
              section(l.groups, inc.groups),
              section(l.phones, inc.phones),
              const SizedBox(height: 16),
              NetworkCard(
                network: net,
                onOpen: (other) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IncidentDetailScreen(service: service, id: other),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
