import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin.dart';
import '../../models/civilian.dart' show pickText;
import '../../state/staff.dart';
import '../civilian/labels.dart';
import '../common.dart';
import '../errors.dart';
import '../language_screen.dart' show languageNames;
import 'staff_common.dart';

/// Area warnings for civilians: publish for one of your cazas, withdraw.
/// They reach civilians through the gateway at the next sync.
class WarningsAdminScreen extends StatefulWidget {
  const WarningsAdminScreen({
    super.key,
    required this.service,
    required this.regions,
    required this.lang,
  });

  final StaffService service;
  final List<String> regions;
  final String lang;

  @override
  State<WarningsAdminScreen> createState() => _WarningsAdminScreenState();
}

class _WarningsAdminScreenState extends State<WarningsAdminScreen> {
  int _version = 0;

  Future<void> _withdraw(StaffWarning w) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.warnWithdrawConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            key: const Key('withdraw-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.warnWithdraw),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.api.withdrawWarning(w.id);
      if (mounted) setState(() => _version++);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e, l, staff: true));
    }
  }

  Widget _card(StaffWarning w, AppLocalizations l, {required bool live}) => Card(
    key: Key('staff-warning-${w.id}'),
    child: ListTile(
      title: Text(pickText(w.title, widget.lang)),
      subtitle: Text(
        [
          '${severityLabel(w.severity, l)} · ${w.caza}',
          pickText(w.body, widget.lang),
          w.withdrawn ? l.warnWithdrawn : l.warningsUntil(formatWhen(context, w.expiresAt)),
          l.warnBy(w.createdBy),
        ].join('\n'),
      ),
      isThreeLine: true,
      trailing: live
          ? TextButton(
              key: Key('withdraw-${w.id}'),
              onPressed: () => _withdraw(w),
              child: Text(l.warnWithdraw),
            )
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.menuWarnings)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-warning'),
        onPressed: () async {
          final done = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) =>
                  PublishWarningScreen(service: widget.service, regions: widget.regions),
            ),
          );
          if (done == true && mounted) setState(() => _version++);
        },
        icon: const Icon(Icons.campaign_outlined),
        label: Text(l.warnNew),
      ),
      body: Loader<List<StaffWarning>>(
        key: ValueKey(_version),
        load: widget.service.api.warnings,
        builder: (context, all, reload) {
          final live = all.where((w) => w.isLive).toList();
          final past = all.where((w) => !w.isLive).take(20).toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                Text(l.warnActive, style: t.titleMedium),
                if (live.isEmpty)
                  Padding(padding: const EdgeInsets.all(16), child: Text(l.warnEmpty)),
                for (final w in live) _card(w, l, live: true),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l.warnPast, style: t.titleMedium),
                  for (final w in past) _card(w, l, live: false),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class PublishWarningScreen extends StatefulWidget {
  const PublishWarningScreen({super.key, required this.service, required this.regions});

  final StaffService service;
  final List<String> regions;

  @override
  State<PublishWarningScreen> createState() => _PublishWarningScreenState();
}

class _PublishWarningScreenState extends State<PublishWarningScreen> {
  static const _durations = [6, 24, 72, 168]; // hours
  final _form = GlobalKey<FormState>();
  final _title = {for (final k in languageNames.keys) k: TextEditingController()};
  final _body = {for (final k in languageNames.keys) k: TextEditingController()};
  String? _caza;
  String _severity = 'caution';
  int _hours = 24;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.regions.length == 1) _caza = widget.regions.single;
  }

  @override
  void dispose() {
    for (final c in [..._title.values, ..._body.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String _durationLabel(int h, AppLocalizations l) => h < 48 ? l.warnHours(h) : l.warnDays(h ~/ 24);

  Future<void> _publish() async {
    final l = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    final title = {
      for (final e in _title.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    final body = {
      for (final e in _body.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    // Each language used needs both a title and a text.
    final complete = title.keys.where(body.containsKey);
    if (complete.isEmpty || title.length != body.length || complete.length != title.length) {
      showMessage(context, l.warnNeedsText);
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.api.publishWarning(
        caza: _caza!,
        severity: _severity,
        title: title,
        body: body,
        expiresAt: DateTime.now().add(Duration(hours: _hours)),
      );
      messenger.showSnackBar(SnackBar(content: Text(l.warnPublished)));
      nav.pop(true);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e, l, staff: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.warnNew)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(padding: const EdgeInsets.all(12), child: Text(l.warnGuidance)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('warn-caza'),
              initialValue: _caza,
              decoration: InputDecoration(
                labelText: l.newReportCaza,
                border: const OutlineInputBorder(),
              ),
              items: [for (final c in widget.regions) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _caza = v),
              validator: (v) => v == null ? l.fieldRequired : null,
            ),
            const SizedBox(height: 12),
            Text(l.warnSeverity),
            Wrap(
              spacing: 6,
              children: [
                for (final s in ['info', 'caution', 'danger'])
                  ChoiceChip(
                    key: Key('warn-sev-$s'),
                    label: Text(severityLabel(s, l)),
                    selected: _severity == s,
                    onSelected: (_) => setState(() => _severity = s),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.warnDuration),
            Wrap(
              spacing: 6,
              children: [
                for (final h in _durations)
                  ChoiceChip(
                    key: Key('warn-hours-$h'),
                    label: Text(_durationLabel(h, l)),
                    selected: _hours == h,
                    onSelected: (_) => setState(() => _hours = h),
                  ),
              ],
            ),
            for (final e in languageNames.entries) ...[
              const SizedBox(height: 16),
              Directionality(
                textDirection: e.key == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                child: Column(
                  children: [
                    TextFormField(
                      key: Key('warn-title-${e.key}'),
                      controller: _title[e.key],
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: l.warnTitleIn(e.value),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      key: Key('warn-body-${e.key}'),
                      controller: _body[e.key],
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: l.warnBodyIn(e.value),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('warn-publish'),
              onPressed: _busy ? null : _publish,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(l.warnPublish),
            ),
          ],
        ),
      ),
    );
  }
}
