import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'errors.dart';

/// Military and admin sign-in, against the internal server over the VPN.
/// Accounts are created by an admin only; there is no sign-up here.
class StaffSignInScreen extends StatefulWidget {
  const StaffSignInScreen({super.key});

  @override
  State<StaffSignInScreen> createState() => _StaffSignInScreenState();
}

class _StaffSignInScreenState extends State<StaffSignInScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await context.read<AppState>().signInStaff(_user.text, _pass.text);
      nav.popUntil((r) => r.isFirst);
    } on Object catch (e) {
      if (mounted) showMessage(context, describeError(e, l, staff: true));
    } finally {
      _pass.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String? required(String? v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null;
    return Scaffold(
      appBar: AppBar(title: Text(l.iAmStaff)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.iAmStaffHint),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('username'),
                  controller: _user,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: l.username,
                    border: const OutlineInputBorder(),
                  ),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('password'),
                  controller: _pass,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: l.password,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  validator: required,
                  onFieldSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('sign-in'),
                  onPressed: _busy ? null : _signIn,
                  child: Text(l.signIn),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
