import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/staff.dart';
import '../../state/staff.dart';
import '../common.dart';
import '../errors.dart';
import 'incidents_screen.dart';
import 'staff_common.dart';

/// Link review: confirm, reject or mark unsure; undo; add notes. Decisions
/// are stored apart from the machine's scores and recorded under the
/// signed-in account.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.service});

  final StaffService service;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _filters = ['open', 'all', 'confirm', 'reject', 'unsure'];
  String _show = 'open';
  List<LinkRow>? _rows;
  Map<String, int> _tally = const {};
  Object? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (rows, tally) = await widget.service.api.links(_show);
      if (mounted) {
        setState(() {
          _rows = rows;
          _tally = tally;
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(LinkRow row, Future<LinkRow> Function() call) async {
    setState(() => _busy.add(row.key));
    try {
      final updated = await call();
      if (!mounted) return;
      setState(() {
        final i = _rows!.indexWhere((r) => r.key == row.key);
        if (i >= 0) _rows![i] = updated;
      });
      await _load(); // keep tally and filter in step
    } on Object catch (e) {
      if (mounted) {
        showMessage(context, describeError(e, AppLocalizations.of(context), staff: true));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(row.key));
    }
  }

  Future<void> _note(LinkRow row) async {
    final text = await showDialog<String>(context: context, builder: (_) => const _NoteDialog());
    if (text == null || text.isEmpty) return;
    await _act(row, () => widget.service.api.note(row.a.id, row.b.id, text));
  }

  String _filterLabel(String f, AppLocalizations l) => switch (f) {
    'open' => '${l.decidedOpen} (${_tally['open'] ?? 0})',
    'confirm' => '${l.decidedConfirm} (${_tally['confirm'] ?? 0})',
    'reject' => '${l.decidedReject} (${_tally['reject'] ?? 0})',
    'unsure' => '${l.decidedUnsure} (${_tally['unsure'] ?? 0})',
    _ => l.filterAll,
  };

  void _open(String id) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => IncidentDetailScreen(service: widget.service, id: id),
    ),
  );

  Widget _card(LinkRow r, AppLocalizations l) {
    final t = Theme.of(context).textTheme;
    final busy = _busy.contains(r.key);
    Widget decide(String d, String label, IconData icon) => r.decision == d
        ? FilledButton.icon(
            key: Key('${r.key}-$d'),
            onPressed: null,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            key: Key('${r.key}-$d'),
            onPressed: busy
                ? null
                : () => _act(r, () => widget.service.api.decide(r.a.id, r.b.id, d)),
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
    return Card(
      key: Key('link-${r.key}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(decisionLabel(r.decision, l), style: t.labelLarge)),
                BandChip(band: r.band, score: r.score),
              ],
            ),
            for (final inc in [r.a, r.b])
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${inc.id} · ${inc.location ?? ''} · ${inc.date ?? ''}'),
                subtitle: Text(inc.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _open(inc.id),
              ),
            for (final reason in r.reasons) Text('• $reason', style: t.bodySmall),
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l.notes, style: t.labelLarge),
              for (final n in r.notes) Text('${n.analyst}: ${n.note}', style: t.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                decide('confirm', l.decisionConfirm, Icons.check),
                decide('reject', l.decisionReject, Icons.close),
                decide('unsure', l.decisionUnsure, Icons.help_outline),
                if (r.decision != null)
                  TextButton.icon(
                    key: Key('${r.key}-undo'),
                    onPressed: busy
                        ? null
                        : () => _act(r, () => widget.service.api.decide(r.a.id, r.b.id, 'undo')),
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l.decisionUndo),
                  ),
                TextButton.icon(
                  key: Key('${r.key}-note'),
                  onPressed: busy ? null : () => _note(r),
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: Text(l.addNote),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuReview)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final f in _filters)
                  ChoiceChip(
                    key: Key('filter-$f'),
                    label: Text(_filterLabel(f, l)),
                    selected: _show == f,
                    onSelected: (_) {
                      setState(() => _show = f);
                      _load();
                    },
                  ),
              ],
            ),
            const LeadsNote(),
            if (_error != null && _rows == null)
              Card(child: ListTile(title: Text(describeError(_error!, l, staff: true)))),
            if (_rows == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_rows != null && _rows!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.reviewEmpty, textAlign: TextAlign.center),
              ),
            for (final r in _rows ?? const <LinkRow>[]) _card(r, l),
          ],
        ),
      ),
    );
  }
}

/// Owns its text controller, so it is disposed only when the dialog is gone.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.addNote),
      content: TextField(
        key: const Key('note-text'),
        controller: _c,
        autofocus: true,
        maxLines: 3,
        maxLength: 2000,
        decoration: InputDecoration(hintText: l.noteHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('note-save'),
          onPressed: () => Navigator.pop(context, _c.text.trim()),
          child: Text(l.save),
        ),
      ],
    );
  }
}
