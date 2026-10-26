import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/session.dart';
import 'common.dart';
import 'errors.dart';
import 'language_screen.dart';

const minPassword = 10; // same rule as the server (linker/accounts.py)

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = context.watch<AppState>();
    final s = state.session;
    final nav = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(title: Text(l.language, style: Theme.of(context).textTheme.titleSmall)),
          RadioGroup<String>(
            groupValue: state.lang,
            onChanged: (v) => state.setLanguage(v!),
            child: Column(
              children: [
                for (final e in languageNames.entries)
                  RadioListTile<String>(
                    key: Key('setlang-${e.key}'),
                    value: e.key,
                    title: Text(e.value),
                  ),
              ],
            ),
          ),
          const Divider(),
          ListTile(title: Text(l.account, style: Theme.of(context).textTheme.titleSmall)),
          if (s != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                l.signedInAs(
                  s.kind == AccountKind.civilian ? '\u2066${s.phone}\u2069' : s.username!,
                ),
              ),
            ),
          if (s?.kind == AccountKind.staff)
            ListTile(
              leading: const Icon(Icons.password),
              title: Text(l.changePassword),
              onTap: () =>
                  showDialog<void>(context: context, builder: (_) => const _PasswordDialog()),
            ),
          ListTile(
            key: const Key('sign-out'),
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () async {
              await state.signOut();
              nav.popUntil((r) => r.isFirst);
            },
          ),
          if (s?.kind == AccountKind.civilian)
            ListTile(
              key: const Key('delete-account'),
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l.deleteAccount),
              onTap: () => _confirmDelete(context),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.deleteCivilianAccount();
      nav.popUntil((r) => r.isFirst);
    } on Object catch (e) {
      if (context.mounted) showMessage(context, describeError(e, l));
    }
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<AppState>().changePassword(_current.text, _new.text);
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(l.passwordChanged)));
    } on Object catch (e) {
      final msg = e.toString().contains('current password')
          ? l.errorWrongLogin
          : describeError(e, l, staff: true);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.changePassword),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(labelText: l.currentPassword),
              validator: (v) => (v ?? '').isEmpty ? l.fieldRequired : null,
            ),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: InputDecoration(labelText: l.newPassword),
              validator: (v) =>
                  (v ?? '').length < minPassword ? l.passwordTooShort(minPassword) : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
      ],
    );
  }
}
