import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'state/app_state.dart';
import 'state/storage.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    config: AppConfig.fromEnvironment,
    secure: SecureStore(),
    prefs: PrefsStore(),
  )..init();
  runApp(ChangeNotifierProvider.value(value: state, child: const SirensApp()));
}
