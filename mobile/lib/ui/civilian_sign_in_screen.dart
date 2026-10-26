import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'errors.dart';

/// Phone number, then the 6-digit SMS code. The first sign-in creates the
/// account, so there is no separate sign-up form.
class CivilianSignInScreen extends StatefulWidget {
  const CivilianSignInScreen({super.key});

  @override
  State<CivilianSignInScreen> createState() => _CivilianSignInScreenState();
}

class _CivilianSignInScreenState extends State<CivilianSignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _sentTo; // normalised number once a code was sent
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e, AppLocalizations.of(context)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final n = await context.read<AppState>().requestCode(_phone.text);
    setState(() {
      _sentTo = n;
      _code.clear();
    });
  });

  Future<void> _verify() => _run(() async {
    final nav = Navigator.of(context);
    await context.read<AppState>().signInCivilian(_sentTo!, _code.text.trim());
    nav.popUntil((r) => r.isFirst);
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final codeStep = _sentTo != null;
    return Scaffold(
      appBar: AppBar(title: Text(l.iAmCivilian)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!codeStep) ...[
                // Phone numbers read left-to-right in every language.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    key: const Key('phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]'))],
                    decoration: InputDecoration(
                      labelText: l.phoneLabel,
                      hintText: l.phoneHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        RegExp(r'\d').allMatches(v ?? '').length >= 7 ? null : l.phoneInvalid,
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.phonePrivacy, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('send-code'),
                  onPressed: _busy ? null : _sendCode,
                  child: Text(l.sendCode),
                ),
              ] else ...[
                Text(l.codeSentTo('\u2066$_sentTo\u2069')),
                const SizedBox(height: 16),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextFormField(
                    key: const Key('code'),
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: InputDecoration(
                      labelText: l.codeLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v ?? '').length == 6 ? null : l.codeInvalid,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('verify'),
                  onPressed: _busy ? null : _verify,
                  child: Text(l.verify),
                ),
                TextButton(onPressed: _busy ? null : _sendCode, child: Text(l.resendCode)),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _sentTo = null),
                  child: Text(l.changeNumber),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
