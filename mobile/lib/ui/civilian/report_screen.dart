import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/civilian.dart';
import '../../services/device.dart';
import '../../state/civilian.dart';
import '../../state/outbox.dart';
import '../common.dart';
import '../errors.dart';
import 'labels.dart';

const maxPhotoBytes = 5 * 1024 * 1024; // same limit as the gateway
const maxDescription = 2000;

/// "Report a suspicious object": safety check, what, photo, where, send.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.service, required this.device});

  final CivilianService service;
  final DeviceServices device;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _description = TextEditingController();
  final _observedAt = DateTime.now();
  bool _safe = false;
  String _category = reportCategories.first;
  PickedPhoto? _photo;
  GeoFix? _fix;
  String? _locationError;
  bool _locating = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _locate(); // start at once; the user can retry if it fails
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final fix = await widget.device.currentPosition();
      if (mounted) setState(() => _fix = fix);
    } on LocationException catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() {
        _locationError = switch (e.problem) {
          LocationProblem.serviceOff => l.locationServiceOff,
          LocationProblem.denied => l.locationDenied,
          LocationProblem.timeout => l.locationTimeout,
        };
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pick(bool camera) async {
    final l = AppLocalizations.of(context);
    final p = await widget.device.pickPhoto(camera: camera);
    if (p == null || !mounted) return;
    if (p.mimeType == null) return showMessage(context, l.photoUnsupported);
    if (p.bytes.length > maxPhotoBytes) return showMessage(context, l.photoTooLarge);
    setState(() => _photo = p);
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final text = _description.text.trim();
    if (!_safe) return showMessage(context, l.reportSafeDistanceRequired);
    if (text.isEmpty && _photo == null) return showMessage(context, l.reportNeedsContent);
    setState(() => _sending = true);
    final report = PendingReport(
      localId: PendingReport.newId(),
      phone: widget.service.phone,
      observedAt: _observedAt,
      category: _category,
      description: text,
      lat: _fix?.lat,
      lon: _fix?.lon,
      accuracyM: _fix?.accuracyM,
      photo: _photo?.bytes,
    );
    try {
      final r = await widget.service.submit(report);
      if (!mounted) return;
      setState(() => _sending = false);
      final sent = r.outcome == SubmitOutcome.sent;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          icon: Icon(sent ? Icons.check_circle_outline : Icons.schedule_send_outlined),
          title: Text(sent ? l.reportSentTitle : l.reportQueuedTitle),
          content: Text(sent ? l.reportSentBody(r.reportId!) : l.reportQueuedBody),
          actions: [
            FilledButton(
              key: const Key('report-done'),
              onPressed: () => Navigator.pop(c),
              child: Text(l.ok),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      showMessage(
        context,
        e.status == 429
            ? l.reportDailyLimit
            : m.contains('outside lebanon')
            ? l.locationOutside
            : describeError(e, l),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.reportObject)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const EmergencyBanner(),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('safe-distance'),
              value: _safe,
              onChanged: (v) => setState(() => _safe = v ?? false),
              title: Text(
                l.reportSafeDistance,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            Text(l.reportWhat, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in reportCategories)
                  ChoiceChip(
                    key: Key('cat-$c'),
                    label: Text(categoryLabel(c, l)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('description'),
              controller: _description,
              maxLines: 4,
              maxLength: maxDescription,
              decoration: InputDecoration(
                labelText: l.reportDescription,
                hintText: l.reportDescriptionHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(l.reportPhoto, style: theme.textTheme.titleMedium),
            Text(l.reportPhotoWarning, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            if (_photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _photo!.bytes,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(height: 80, child: Icon(Icons.image_outlined, size: 48)),
                ),
              ),
              TextButton.icon(
                key: const Key('remove-photo'),
                onPressed: () => setState(() => _photo = null),
                icon: const Icon(Icons.delete_outline),
                label: Text(l.reportRemovePhoto),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('take-photo'),
                      onPressed: () => _pick(true),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l.reportTakePhoto),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('choose-photo'),
                      onPressed: () => _pick(false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l.reportChoosePhoto),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(l.reportLocation, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Card(
              child: ListTile(
                key: const Key('location-status'),
                leading: _locating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_fix != null ? Icons.my_location : Icons.location_off_outlined),
                title: Text(
                  _fix != null
                      ? l.reportLocationFix(_fix!.accuracyM.round())
                      : (_locationError ?? l.reportLocationNone),
                ),
                subtitle: _fix == null && _locationError != null
                    ? Text(l.reportLocationNone)
                    : null,
                trailing: _locating
                    ? null
                    : IconButton(
                        key: const Key('locate'),
                        tooltip: l.reportUseLocation,
                        icon: const Icon(Icons.refresh),
                        onPressed: _locate,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('send-report'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l.reportSend),
            ),
          ],
        ),
      ),
    );
  }
}
