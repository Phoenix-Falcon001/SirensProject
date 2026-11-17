import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'errors.dart';
import 'settings_screen.dart' show minPassword;

/// Shown instead of the home screen while the account still has the password
/// an administrator chose. Nothing else is reachable until it is replaced.
class ForcePasswordScreen extends StatefulWidget {
  const ForcePasswordScreen({super.key});

  @override
  State<ForcePasswordScreen> createState() => _ForcePasswordScreenState();
}

class _ForcePasswordScreenState extends State<ForcePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await context.read<AppState>().changePassword(_current.text, _new.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      showMessage(
        context,
        m.contains('current password')
            ? l.errorWrongLogin
            : m.contains('different')
            ? l.passwordMustDiffer
            : describeError(e, l, staff: true),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.choosePasswordTitle),
        actions: [
          TextButton(
            key: const Key('force-sign-out'),
            onPressed: state.signOut,
            child: Text(l.signOut),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.choosePasswordBody),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('force-current'),
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.temporaryPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').isEmpty ? l.fieldRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('force-new'),
                controller: _new,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.newPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').length < minPassword
                    ? l.passwordTooShort(minPassword)
                    : v == _current.text
                    ? l.passwordMustDiffer
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('force-again'),
                controller: _again,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.repeatPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v != _new.text ? l.passwordsDiffer : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('force-save'),
                onPressed: _busy ? null : _save,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
