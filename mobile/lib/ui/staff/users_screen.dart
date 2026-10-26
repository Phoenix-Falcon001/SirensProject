import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../models/admin.dart';
import '../../state/staff.dart';
import '../common.dart';
import '../errors.dart';
import '../home_screens.dart' show levelLabel;
import '../settings_screen.dart' show minPassword;
import 'staff_common.dart';

/// A random password without look-alike characters (0/O, 1/l/I).
String generatePassword([int length = 14]) {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

/// The server's refusal reason when it is a rule message, else the usual text.
String _why(Object e, AppLocalizations l) => e is ApiException && e.status == 400
    ? l.serverSaid(e.message)
    : describeError(e, l, staff: true);

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.service, required this.me});

  final StaffService service;

  /// The signed-in admin's username (cannot disable themselves).
  final String me;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  int _version = 0;
  String _query = '';

  Future<void> _edit([AdminUser? u]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserEditScreen(service: widget.service, user: u, me: widget.me),
      ),
    );
    if (saved == true && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuUsers)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-user'),
        onPressed: _edit,
        icon: const Icon(Icons.person_add_alt),
        label: Text(l.usersNew),
      ),
      body: Loader<List<AdminUser>>(
        key: ValueKey(_version),
        load: widget.service.api.users,
        builder: (context, users, reload) {
          final q = _query.toLowerCase();
          final shown = users
              .where((u) => q.isEmpty || '${u.username} ${u.displayName}'.toLowerCase().contains(q))
              .toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                TextField(
                  key: const Key('user-search'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l.usersSearch,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                for (final u in shown)
                  Card(
                    key: Key('user-${u.username}'),
                    child: ListTile(
                      leading: Icon(
                        u.role == 'admin'
                            ? Icons.admin_panel_settings_outlined
                            : Icons.badge_outlined,
                      ),
                      title: Text(
                        [
                          u.displayName.isEmpty ? u.username : u.displayName,
                          if (u.username == widget.me) '(${l.usersYou})',
                        ].join(' '),
                      ),
                      subtitle: Text(
                        [
                          u.username,
                          u.role == 'admin' ? l.roleAdmin : levelLabel(u.level, l),
                          if (u.role != 'admin') u.regions.join(', '),
                        ].join(' · '),
                      ),
                      trailing: u.active ? null : Chip(label: Text(l.usersDisabled)),
                      onTap: () => _edit(u),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Create an account (user == null) or change one.
class UserEditScreen extends StatefulWidget {
  const UserEditScreen({super.key, required this.service, this.user, required this.me});

  final StaffService service;
  final AdminUser? user;
  final String me;

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.user?.username ?? '');
  late final _name = TextEditingController(text: widget.user?.displayName ?? '');
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'military';
  late String _level = widget.user?.level ?? 'field';
  late final Set<String> _regions = {...?widget.user?.regions};
  late bool _active = widget.user?.active ?? true;
  bool _busy = false;

  bool get _isNew => widget.user == null;
  bool get _isMe => widget.user?.username == widget.me;

  @override
  void initState() {
    super.initState();
    if (_isNew) _password.text = generatePassword();
  }

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (_role == 'military' && _regions.isEmpty) {
      showMessage(context, l.usersRegions);
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final military = _role == 'military';
    try {
      if (_isNew) {
        final u = await widget.service.api.createUser({
          'username': _username.text.trim(),
          'display_name': _name.text.trim(),
          'password': _password.text,
          'role': _role,
          if (military) 'level': _level,
          if (military) 'regions': _regions.toList()..sort(),
        });
        messenger.showSnackBar(SnackBar(content: Text(l.usersCreated(u.username))));
      } else {
        await widget.service.api.updateUser(widget.user!.id, {
          'display_name': _name.text.trim(),
          'active': _active,
          if (military) 'level': _level,
          if (military) 'regions': _regions.toList()..sort(),
        });
        messenger.showSnackBar(SnackBar(content: Text(l.usersSaved)));
      }
      nav.pop(true);
    } on Object catch (e) {
      if (mounted) showMessage(context, _why(e, l));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final l = AppLocalizations.of(context);
    final pw = generatePassword();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.usersResetPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              pw,
              key: const Key('reset-password-value'),
              style: const TextStyle(fontSize: 22, fontFamily: 'monospace', letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(l.usersPasswordHint),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            key: const Key('reset-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.usersResetPassword),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.api.updateUser(widget.user!.id, {'password': pw});
      if (mounted) showMessage(context, l.usersResetDone);
    } on Object catch (e) {
      if (mounted) showMessage(context, _why(e, l));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final allRegions = widget.service.regionChoices;
    String? required(String? v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? l.usersNew : widget.user!.username)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isNew) ...[
              TextFormField(
                key: const Key('new-username'),
                controller: _username,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l.username,
                  border: const OutlineInputBorder(),
                ),
                validator: required,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('new-display-name'),
              controller: _name,
              decoration: InputDecoration(
                labelText: l.usersDisplayName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_isNew) ...[
              Text(l.usersRole, style: t.labelLarge),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    key: const Key('role-military'),
                    label: Text(l.usersRoleMilitary),
                    selected: _role == 'military',
                    onSelected: (_) => setState(() => _role = 'military'),
                  ),
                  ChoiceChip(
                    key: const Key('role-admin'),
                    label: Text(l.roleAdmin),
                    selected: _role == 'admin',
                    onSelected: (_) => setState(() => _role = 'admin'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_role == 'military') ...[
              Text(l.usersLevel, style: t.labelLarge),
              Wrap(
                spacing: 6,
                children: [
                  for (final lv in ['field', 'analyst', 'commander'])
                    ChoiceChip(
                      key: Key('level-$lv'),
                      label: Text(levelLabel(lv, l)),
                      selected: _level == lv,
                      onSelected: (_) => setState(() => _level = lv),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.usersRegions, style: t.labelLarge),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in allRegions)
                    FilterChip(
                      key: Key('region-$r'),
                      label: Text(r),
                      selected: _regions.contains(r),
                      onSelected: (on) => setState(() => on ? _regions.add(r) : _regions.remove(r)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_isNew) ...[
              TextFormField(
                key: const Key('new-password'),
                controller: _password,
                decoration: InputDecoration(
                  labelText: l.usersTempPassword,
                  helperText: l.usersPasswordHint,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: l.usersGenerate,
                    icon: const Icon(Icons.casino_outlined),
                    onPressed: () => setState(() => _password.text = generatePassword()),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').length < minPassword ? l.passwordTooShort(minPassword) : null,
              ),
            ] else ...[
              SwitchListTile(
                key: const Key('user-active'),
                title: Text(l.usersActive),
                value: _active,
                onChanged: _isMe ? null : (v) => setState(() => _active = v),
                subtitle: _isMe ? Text(l.usersCannotDisableSelf) : null,
              ),
              ListTile(
                key: const Key('reset-password'),
                leading: const Icon(Icons.password),
                title: Text(l.usersResetPassword),
                onTap: _resetPassword,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('user-save'),
              onPressed: _busy ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key, required this.service});

  final StaffService service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuAudit)),
      body: Loader<List<AuditEntry>>(
        load: service.api.audit,
        builder: (context, entries, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (entries.isEmpty)
                Padding(padding: const EdgeInsets.all(32), child: Text(l.auditEmpty)),
              for (final e in entries)
                ListTile(
                  dense: true,
                  leading: Icon(
                    e.action.startsWith('login.fail') ? Icons.warning_amber : Icons.history,
                  ),
                  title: Text('${e.actor} · ${e.action}'),
                  subtitle: Text(
                    [
                      MaterialLocalizations.of(context).formatShortDate(e.at.toLocal()),
                      TimeOfDay.fromDateTime(e.at.toLocal()).format(context),
                      if (e.detail.isNotEmpty)
                        e.detail.entries.map((d) => '${d.key}: ${d.value}').join(', '),
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
