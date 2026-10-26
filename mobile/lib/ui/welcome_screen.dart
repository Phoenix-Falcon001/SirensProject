import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'civilian_sign_in_screen.dart';
import 'common.dart';
import 'language_screen.dart';
import 'staff_sign_in_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final expired = context.watch<AppState>().sessionExpired;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle), actions: const [LanguageMenuButton()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (expired)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_clock),
                    title: Text(l.sessionExpired),
                  ),
                ),
              ),
            Text(l.welcomeTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(l.welcomeBody),
            const SizedBox(height: 16),
            const EmergencyBanner(),
            const SizedBox(height: 24),
            MenuTile(
              key: const Key('choose-civilian'),
              icon: Icons.person_outline,
              title: l.iAmCivilian,
              subtitle: l.iAmCivilianHint,
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const CivilianSignInScreen())),
            ),
            MenuTile(
              key: const Key('choose-staff'),
              icon: Icons.military_tech_outlined,
              title: l.iAmStaff,
              subtitle: l.iAmStaffHint,
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const StaffSignInScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
