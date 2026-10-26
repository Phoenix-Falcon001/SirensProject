import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/staff.dart';
import '../errors.dart';

String bandLabel(String band, AppLocalizations l) => switch (band) {
  'strong' => l.bandStrong,
  'medium' => l.bandMedium,
  _ => l.bandWeak,
};

String decisionLabel(String? d, AppLocalizations l) => switch (d) {
  'confirm' => l.decidedConfirm,
  'reject' => l.decidedReject,
  'unsure' => l.decidedUnsure,
  _ => l.decidedOpen,
};

/// "trigger=pressure_plate" -> "trigger: pressure plate".
String featureLabel(String f) => f.replaceAll('_', ' ').replaceFirst('=', ': ');

/// Strength badge. Bands are computed on the server (weak < 0.40 ≤ medium < 0.66 ≤ strong).
class BandChip extends StatelessWidget {
  const BandChip({super.key, required this.band, this.score});

  final String band;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = switch (band) {
      'strong' => (c.primary, c.onPrimary),
      'medium' => (c.secondaryContainer, c.onSecondaryContainer),
      _ => (c.surfaceContainerHighest, c.onSurfaceVariant),
    };
    final text = score == null
        ? bandLabel(band, l)
        : '${bandLabel(band, l)} · ${score!.toStringAsFixed(2)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// The reminder shown wherever links appear.
class LeadsNote extends StatelessWidget {
  const LeadsNote({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context).leadsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

/// Loads [load] and shows a spinner, an error with "Try again", or [builder].
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) {
      final e = _error!;
      final msg = e is ApiException && e.status == 404
          ? l.notFoundOrOutside
          : describeError(e, l, staff: true);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(key: const Key('retry'), onPressed: _reload, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/// The incident's candidate network: its links (strongest first) and what
/// the members share. Shown on an incident and after filing a report.
class NetworkCard extends StatelessWidget {
  const NetworkCard({super.key, required this.network, this.onOpen});

  final NetworkInfo network;
  final void Function(String incidentId)? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('network-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.networkTitle, style: t.titleMedium),
            if (network.links.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.networkNone))
            else ...[
              if (network.tentative)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.networkTentative, style: t.bodySmall),
                ),
              if (network.signature.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.networkShares, style: t.labelLarge),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in network.signature)
                      Chip(label: Text(featureLabel(s)), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              for (final link in network.links)
                ListTile(
                  key: Key('net-${link.other.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text('${link.other.id} · ${link.other.location ?? ''}'),
                  subtitle: Text(link.reasons.take(3).join(' · ')),
                  trailing: BandChip(band: link.band, score: link.score),
                  onTap: onOpen == null ? null : () => onOpen!(link.other.id),
                ),
            ],
            const LeadsNote(),
          ],
        ),
      ),
    );
  }
}
