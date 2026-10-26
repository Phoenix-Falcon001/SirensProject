import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin.dart';
import '../../services/device.dart';
import '../../state/staff.dart';
import '../civilian/labels.dart';
import '../common.dart';
import '../errors.dart';
import 'new_report_screen.dart';
import 'staff_common.dart';

const civilStatuses = ['received', 'under_review', 'closed', 'rejected'];

/// Civilian reports in the commander's regions (admins: all), newest first.
class CivilReportsScreen extends StatefulWidget {
  const CivilReportsScreen({
    super.key,
    required this.service,
    required this.device,
    required this.regions,
  });

  final StaffService service;
  final DeviceServices device;
  final List<String> regions;

  @override
  State<CivilReportsScreen> createState() => _CivilReportsScreenState();
}

class _CivilReportsScreenState extends State<CivilReportsScreen> {
  String? _status = 'received';

  String _filterLabel(String? s, AppLocalizations l) => s == null ? l.filterAll : statusLabel(s, l);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuCivilReports)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 6,
              children: [
                for (final s in [...civilStatuses, null])
                  ChoiceChip(
                    key: Key('civil-filter-${s ?? 'all'}'),
                    label: Text(_filterLabel(s, l)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Loader<List<CivilReportFull>>(
              key: ValueKey(_status),
              load: () => widget.service.api.civilReports(status: _status),
              builder: (context, rows, reload) => RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l.civilEmpty, textAlign: TextAlign.center),
                      ),
                    for (final r in rows)
                      Card(
                        key: Key('civil-${r.id}'),
                        child: ListTile(
                          leading: Icon(
                            r.hasPhoto ? Icons.photo_outlined : Icons.description_outlined,
                          ),
                          title: Text(
                            '${categoryLabel(r.category, l)} · ${r.caza ?? l.civilNoCaza}',
                          ),
                          subtitle: Text(
                            [
                              formatWhen(context, r.submittedAt),
                              r.description,
                            ].where((s) => s.isNotEmpty).join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Chip(label: Text(statusLabel(r.status, l))),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CivilReportDetailScreen(
                                  service: widget.service,
                                  device: widget.device,
                                  regions: widget.regions,
                                  id: r.id,
                                ),
                              ),
                            );
                            await reload();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CivilReportDetailScreen extends StatefulWidget {
  const CivilReportDetailScreen({
    super.key,
    required this.service,
    required this.device,
    required this.regions,
    required this.id,
  });

  final StaffService service;
  final DeviceServices device;
  final List<String> regions;
  final String id;

  @override
  State<CivilReportDetailScreen> createState() => _CivilReportDetailScreenState();
}

class _CivilReportDetailScreenState extends State<CivilReportDetailScreen> {
  int _version = 0;

  Future<(CivilReportFull, List<int>?)> _load() async {
    final r = await widget.service.api.civilReport(widget.id);
    List<int>? photo;
    if (r.hasPhoto) {
      try {
        photo = await widget.service.api.civilPhoto(widget.id);
      } on Object {
        photo = null; // shown as "could not be loaded"
      }
    }
    return (r, photo);
  }

  Future<void> _setStatus(CivilReportFull r) async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _StatusDialog(current: r.status),
    );
    if (result == null || !mounted) return;
    try {
      await widget.service.api.setCivilStatus(r.id, result.$1, result.$2);
      if (!mounted) return;
      showMessage(context, l.civilStatusSaved);
      setState(() => _version++);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e, l, staff: true));
    }
  }

  void _toReport(CivilReportFull r) {
    final l = AppLocalizations.of(context);
    final text = [
      l.civilFromCivilian(r.id),
      '${categoryLabel(r.category, l)}.',
      if (r.description.isNotEmpty) r.description,
    ].join('\n');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewReportScreen(
          service: widget.service,
          device: widget.device,
          regions: widget.regions,
          initialText: text,
          initialCaza: r.caza,
          initialFix: r.lat == null ? null : GeoFix(r.lat!, r.lon!, r.accuracyM ?? 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.id)),
      body: Loader<(CivilReportFull, List<int>?)>(
        key: ValueKey(_version),
        load: _load,
        builder: (context, data, _) {
          final (r, photo) = data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(categoryLabel(r.category, l), style: t.titleLarge),
              Text(
                [
                  l.sentOn(formatWhen(context, r.submittedAt)),
                  if (r.observedAt != null) l.civilObserved(formatWhen(context, r.observedAt!)),
                ].join(' · '),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(key: const Key('civil-status'), label: Text(statusLabel(r.status, l))),
                  if (r.statusBy != null)
                    Chip(label: Text(l.civilLastChange(statusLabel(r.status, l), r.statusBy!))),
                ],
              ),
              if (r.statusNote.isNotEmpty) Text(r.statusNote, style: t.bodySmall),
              const SizedBox(height: 12),
              if (r.description.isNotEmpty) SelectableText(r.description, style: t.bodyLarge),
              if (r.hasPhoto) ...[
                const SizedBox(height: 12),
                if (photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      Uint8List.fromList(photo),
                      key: const Key('civil-photo'),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(l.civilPhotoFailed),
                    ),
                  )
                else
                  Text(l.civilPhotoFailed),
              ],
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    r.mgrs == null ? l.civilNoLocation : l.gridRef(r.mgrs!),
                    key: const Key('civil-mgrs'),
                  ),
                  subtitle: Text(
                    [
                      r.caza ?? l.civilNoCaza,
                      if (r.accuracyM != null) l.civilAccuracy(r.accuracyM!.round()),
                    ].join(' · '),
                  ),
                  trailing: r.mgrs == null
                      ? null
                      : IconButton(
                          tooltip: l.copy,
                          icon: const Icon(Icons.copy),
                          onPressed: () => Clipboard.setData(ClipboardData(text: r.mgrs!)),
                        ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l.civilReporter),
                  subtitle: Text(
                    r.reporterPhone == null
                        ? l.civilReporterDeleted
                        : '\u2066${r.reporterPhone}\u2069',
                  ),
                  trailing: r.reporterPhone == null
                      ? null
                      : IconButton(
                          key: const Key('call-reporter'),
                          tooltip: l.call,
                          icon: const Icon(Icons.call),
                          onPressed: () => widget.device.dial(r.reporterPhone!),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('set-status'),
                onPressed: () => _setStatus(r),
                icon: const Icon(Icons.flag_outlined),
                label: Text(l.civilSetStatus),
              ),
              const SizedBox(height: 8),
              if (widget.service.canFile)
                OutlinedButton.icon(
                  key: const Key('to-report'),
                  onPressed: () => _toReport(r),
                  icon: const Icon(Icons.edit_note),
                  label: Text(l.civilToReport),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.current});

  final String current;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  late String _status = widget.current;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.civilSetStatus),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v!),
              child: Column(
                children: [
                  for (final s in civilStatuses)
                    RadioListTile<String>(
                      key: Key('status-$s'),
                      value: s,
                      title: Text(statusLabel(s, l)),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('status-note'),
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.civilStatusNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('status-save'),
          onPressed: () => Navigator.pop(context, (_status, _note.text.trim())),
          child: Text(l.save),
        ),
      ],
    );
  }
}
