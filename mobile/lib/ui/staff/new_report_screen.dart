import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../geo/mgrs.dart';
import '../../l10n/app_localizations.dart';
import '../../services/device.dart';
import '../../state/drafts.dart';
import '../../state/outbox.dart' show PendingReport;
import '../../state/staff.dart';
import '../common.dart';
import '../errors.dart';
import 'incidents_screen.dart';
import 'staff_common.dart';

/// File a new report, as on the web console's New report form. Works without
/// the VPN: the report is kept on the phone and filed when it is back.
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({
    super.key,
    required this.service,
    required this.device,
    required this.regions,
    this.initialText,
    this.initialCaza,
    this.initialFix,
  });

  final StaffService service;
  final DeviceServices device;

  /// Cazas this user may file in.
  final List<String> regions;

  /// Pre-filled values, e.g. when filing from a civilian report.
  final String? initialText;
  final String? initialCaza;
  final GeoFix? initialFix;

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  final _form = GlobalKey<FormState>();
  final _street = TextEditingController();
  final _text = TextEditingController();
  String? _caza;
  String? _munition;
  DateTime _date = DateTime.now();
  GeoFix? _fix;
  bool _locating = false;
  bool _busy = false;
  FileResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.regions.length == 1) _caza = widget.regions.single;
    if (widget.initialCaza != null && widget.regions.contains(widget.initialCaza)) {
      _caza = widget.initialCaza;
    }
    _text.text = widget.initialText ?? '';
    _fix = widget.initialFix;
  }

  @override
  void dispose() {
    _street.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final f = await widget.device.currentPosition();
      if (mounted) setState(() => _fix = f);
    } on LocationException {
      if (mounted) showMessage(context, AppLocalizations.of(context).locationTimeout);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    final draft = StaffDraft(
      localId: PendingReport.newId(),
      username: widget.service.username,
      savedAt: DateTime.now(),
      body: {
        'narrative': _text.text.trim(),
        'caza': _caza,
        'street': _street.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'munition': ?_munition,
        if (_fix != null) 'lat': _fix!.lat,
        if (_fix != null) 'lon': _fix!.lon,
      },
    );
    try {
      final r = await widget.service.file(draft);
      if (!mounted) return;
      setState(() => _busy = false);
      if (r.outcome == FileOutcome.queued) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.schedule_send_outlined),
            content: Text(l.reportQueuedStaff),
            actions: [
              FilledButton(
                key: const Key('queued-ok'),
                onPressed: () => Navigator.pop(c),
                child: Text(l.ok),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _result = r);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showMessage(context, e.status == 403 ? l.outsideRegions : describeError(e, l, staff: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _filed(BuildContext context, FileResult r) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l.reportFiled(r.incidentId!), key: const Key('filed-id')),
          ),
        ),
        if (r.network != null)
          NetworkCard(
            network: r.network!,
            onOpen: (id) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => IncidentDetailScreen(service: widget.service, id: id),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.ok)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final svc = widget.service;
    return Scaffold(
      appBar: AppBar(title: Text(l.menuNewReport)),
      body: _result != null
          ? _filed(context, _result!)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListenableBuilder(
                    listenable: svc,
                    builder: (context, _) => svc.pending.isEmpty
                        ? const SizedBox.shrink()
                        : Card(
                            child: ListTile(
                              leading: const Icon(Icons.schedule_send_outlined),
                              title: Text(l.draftsWaiting(svc.pending.length)),
                              trailing: TextButton(
                                key: const Key('drafts-send-now'),
                                onPressed: svc.flush,
                                child: Text(l.sendNow),
                              ),
                            ),
                          ),
                  ),
                  DropdownButtonFormField<String>(
                    key: const Key('caza'),
                    initialValue: _caza,
                    decoration: InputDecoration(
                      labelText: l.newReportCaza,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in widget.regions) DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _caza = v),
                    validator: (v) => v == null ? l.fieldRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('street'),
                    controller: _street,
                    decoration: InputDecoration(
                      labelText: l.newReportStreet,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('date'),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event),
                          label: Text(
                            '${l.newReportDate}: ${DateFormat.yMMMd(l.localeName).format(_date)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: const Key('munition'),
                    initialValue: _munition,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.newReportType,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(l.typeUnknown)),
                      for (final m in svc.munitions)
                        DropdownMenuItem<String?>(value: m['key'], child: Text(m['label']!)),
                    ],
                    onChanged: (v) => setState(() => _munition = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('narrative'),
                    controller: _text,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: l.newReportText,
                      hintText: l.newReportTextHint,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      key: const Key('grid'),
                      leading: Icon(_fix == null ? Icons.location_searching : Icons.my_location),
                      title: Text(
                        _fix == null
                            ? l.reportUseLocation
                            : l.gridRef(toMgrs(_fix!.lat, _fix!.lon)),
                      ),
                      subtitle: _fix == null
                          ? null
                          : Text(l.reportLocationFix(_fix!.accuracyM.round())),
                      trailing: _locating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _locating ? null : _locate,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('file-report'),
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l.fileReport),
                  ),
                ],
              ),
            ),
    );
  }
}
