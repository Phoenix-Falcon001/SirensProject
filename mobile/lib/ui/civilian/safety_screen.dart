import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/civilian.dart';
import '../../services/device.dart';
import '../../state/civilian.dart';
import '../common.dart';

/// What to do and who to call. Works offline: last copy from the gateway,
/// or the copy bundled in the app.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key, required this.service, required this.device, required this.lang});

  final CivilianService service;
  final DeviceServices device;
  final String lang;

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  SafetyInfo? _info;

  @override
  void initState() {
    super.initState();
    widget.service.safety().then((r) {
      if (mounted) setState(() => _info = r.value);
    });
  }

  Future<void> _call(Hotline h) async {
    final ok = await widget.device.dial(h.number);
    if (!ok && mounted) showMessage(context, AppLocalizations.of(context).callFailed(h.number));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: Text(l.safety)),
      body: info == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (info.isPlaceholder)
                  Card(
                    key: const Key('safety-placeholder'),
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l.safetyPlaceholder),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(l.safetySteps, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final (i, step) in info.stepsFor(widget.lang).indexed)
                  ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(step, style: const TextStyle(fontSize: 17)),
                  ),
                const Divider(height: 32),
                Text(l.safetyHotlines, style: theme.textTheme.titleLarge),
                for (final h in info.hotlines)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone_in_talk_outlined),
                      title: Text(pickText(h.label, widget.lang)),
                      subtitle: Text(
                        h.isDialable ? '\u2066${h.number}\u2069' : l.numberToBeConfirmed,
                      ),
                      trailing: h.isDialable
                          ? FilledButton.icon(
                              key: Key('call-${h.number}'),
                              onPressed: () => _call(h),
                              icon: const Icon(Icons.call),
                              label: Text(l.call),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}
