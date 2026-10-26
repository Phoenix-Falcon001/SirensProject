import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Native names, so anyone can find their language whatever is on screen now.
const languageNames = {'ar': 'العربية', 'en': 'English', 'fr': 'Français'};

/// First screen on a new install. Shows all three prompts, since the user
/// has not picked a language yet.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'اختر لغتك · Choose your language · Choisissez votre langue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 32),
                  for (final e in languageNames.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.tonal(
                        key: Key('lang-${e.key}'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: () => state.setLanguage(e.key),
                        child: Text(e.value, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Language switcher for app bars.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.translate),
      initialValue: state.lang,
      onSelected: state.setLanguage,
      itemBuilder: (_) => [
        for (final e in languageNames.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
      ],
    );
  }
}
