/// Server addresses, fixed at build time by the Army:
///
/// ```
/// flutter build apk \
///   --dart-define=SIRENS_GATEWAY_URL=https://gateway.example \
///   --dart-define=SIRENS_INTERNAL_URL=https://internal.example
/// ```
///
/// The defaults point at a development machine as seen from the Android
/// emulator (10.0.2.2 is the host computer).
class AppConfig {
  const AppConfig({required this.gatewayUrl, required this.internalUrl});

  /// Public gateway: civilians only.
  final String gatewayUrl;

  /// Internal Army server, reached over the Army VPN: military and admins.
  final String internalUrl;

  static const fromEnvironment = AppConfig(
    gatewayUrl: String.fromEnvironment('SIRENS_GATEWAY_URL', defaultValue: 'http://10.0.2.2:5100'),
    internalUrl: String.fromEnvironment(
      'SIRENS_INTERNAL_URL',
      defaultValue: 'http://10.0.2.2:5000',
    ),
  );
}
