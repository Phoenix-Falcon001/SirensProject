import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/staff.dart';
import '../../state/staff.dart';
import 'staff_common.dart';

/// Horizontal bars with the numbers written out (readable without colour,
/// and doubles as the table view).
class BarList extends StatelessWidget {
  const BarList({super.key, required this.bars, this.suffix = '', this.max});

  final Bars bars;
  final String suffix;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final top = max ?? (bars.values.isEmpty ? 1 : bars.values.reduce((a, b) => a > b ? a : b));
    return Column(
      children: [
        for (var i = 0; i < bars.labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text(bars.labels[i], overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: top == 0 ? 0 : bars.values[i] / top,
                      minHeight: 14,
                      color: c.primary,
                      backgroundColor: c.surfaceContainerHighest,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${bars.values[i]}$suffix',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Counts over the user's regions, optionally one caza. No conclusions.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.service, required this.regions});

  final StaffService service;
  final List<String> regions;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _caza;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    Widget section(String title, Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.menuDashboard)),
      body: Loader<DashboardData>(
        key: ValueKey(_caza),
        load: () => widget.service.api.dashboard(caza: _caza),
        builder: (context, d, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (widget.regions.length > 1)
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text(l.allCazas),
                      selected: _caza == null,
                      onSelected: (_) => setState(() => _caza = null),
                    ),
                    for (final c in widget.regions)
                      ChoiceChip(
                        key: Key('dash-caza-$c'),
                        label: Text(c),
                        selected: _caza == c,
                        onSelected: (_) => setState(() => _caza = c),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.dashTotal(d.total),
                  style: t.headlineSmall,
                  key: const Key('dash-total'),
                ),
              ),
              section(
                l.dashTimeline,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BarList(bars: d.timeline),
                    if (d.undated > 0) Text(l.dashUndated(d.undated), style: t.bodySmall),
                  ],
                ),
              ),
              section(l.dashByCaza, BarList(bars: d.byCaza)),
              section(l.dashByInitiation, BarList(bars: d.byInitiation)),
              section(
                l.dashLinks,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.dashLinksTotal(d.linkTotal)} · ${l.dashReviewed(d.reviewedPct)}'),
                    const SizedBox(height: 8),
                    BarList(
                      bars: Bars(
                        [l.bandStrong, l.bandMedium, l.bandWeak],
                        [d.bands['strong'] ?? 0, d.bands['medium'] ?? 0, d.bands['weak'] ?? 0],
                      ),
                    ),
                    const Divider(),
                    BarList(
                      bars: Bars(
                        [l.decidedConfirm, l.decidedReject, l.decidedUnsure, l.decidedOpen],
                        [
                          d.review['confirm'] ?? 0,
                          d.review['reject'] ?? 0,
                          d.review['unsure'] ?? 0,
                          d.review['open'] ?? 0,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              section(
                l.dashNetworks,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (id, n, band) in d.networks)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(id),
                        subtitle: Text(l.dashNetworkRow(n)),
                        trailing: band.isEmpty ? null : BandChip(band: band),
                      ),
                    Text(l.dashUnlinked(d.unlinked), style: t.bodySmall),
                  ],
                ),
              ),
              section(
                l.dashQuality,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.dashQualityOverall(d.qualityOverall)),
                    const SizedBox(height: 8),
                    BarList(bars: d.quality, suffix: '%', max: 100),
                  ],
                ),
              ),
              const LeadsNote(),
            ],
          ),
        ),
      ),
    );
  }
}
