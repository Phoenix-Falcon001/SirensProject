import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/session.dart';
import 'force_password_screen.dart';
import 'home_screens.dart';
import 'language_screen.dart';
import 'theme.dart';
import 'welcome_screen.dart';

class SirensApp extends StatelessWidget {
  const SirensApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      // Arabic switches the whole layout to right-to-left automatically.
      locale: state.locale ?? const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: sirensTheme(),
      darkTheme: sirensDarkTheme(),
      home: const _Root(),
    );
  }
}

/// Chooses the first screen: language (first run), welcome, or a home screen.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (state.locale == null) return const LanguageScreen();
    return switch (state.session?.kind) {
      null => const WelcomeScreen(),
      AccountKind.civilian => const CivilianHome(),
      AccountKind.staff =>
        state.session!.mustChange ? const ForcePasswordScreen() : const StaffHome(),
    };
  }
}
