// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Sirens';

  @override
  String get chooseLanguage => 'Choisissez votre langue';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get welcomeTitle => 'Signalez le danger. Restez en sécurité.';

  @override
  String get welcomeBody => 'Géré par l\'Armée libanaise.';

  @override
  String get iAmCivilian => 'Je suis un civil';

  @override
  String get iAmCivilianHint => 'Signalez un objet suspect et recevez les alertes de votre région';

  @override
  String get iAmStaff => 'Militaire / Administrateur';

  @override
  String get iAmStaffHint =>
      'Connectez-vous avec votre compte de l\'Armée. Le VPN de l\'Armée doit être activé.';

  @override
  String get emergencyBanner =>
      'En danger ? Éloignez-vous de l\'objet et appelez la ligne d\'urgence.';

  @override
  String get phoneLabel => 'Numéro de mobile';

  @override
  String get phoneHint => '03 123 456';

  @override
  String get phoneInvalid => 'Saisissez un numéro de mobile valide.';

  @override
  String get phonePrivacy =>
      'Votre numéro sert uniquement à vous connecter et à permettre à l\'Armée de vous contacter au sujet de vos signalements.';

  @override
  String get sendCode => 'Envoyer le code par SMS';

  @override
  String get codeLabel => 'Code à 6 chiffres';

  @override
  String codeSentTo(String phone) {
    return 'Nous avons envoyé un code au $phone.';
  }

  @override
  String get codeInvalid => 'Saisissez les 6 chiffres reçus par SMS.';

  @override
  String get verify => 'Confirmer';

  @override
  String get changeNumber => 'Changer de numéro';

  @override
  String get resendCode => 'Envoyer un nouveau code';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get fieldRequired => 'Obligatoire';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get errorNetwork =>
      'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get errorNetworkStaff =>
      'Impossible de joindre le serveur de l\'Armée. Vérifiez que le VPN est activé.';

  @override
  String get errorTooMany => 'Trop de tentatives. Patientez quelques minutes puis réessayez.';

  @override
  String get errorWrongCode => 'Code erroné ou expiré.';

  @override
  String get errorWrongLogin => 'Nom d\'utilisateur ou mot de passe incorrect.';

  @override
  String get errorAccountLocked => 'Compte bloqué temporairement après trop de tentatives.';

  @override
  String get errorAccountDisabled => 'Ce compte est désactivé. Contactez votre administrateur.';

  @override
  String get errorGeneric => 'Une erreur s\'est produite. Réessayez.';

  @override
  String get sessionExpired => 'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get reportObject => 'Signaler un objet suspect';

  @override
  String get reportObjectHint => 'Photo, lieu et courte description';

  @override
  String get myReports => 'Mes signalements';

  @override
  String get myReportsHint => 'Voir si vos signalements ont été reçus';

  @override
  String get warnings => 'Alertes de zone';

  @override
  String get warningsHint => 'Lieux à éviter, publiés par l\'Armée';

  @override
  String get safety => 'Sécurité et numéros d\'urgence';

  @override
  String get safetyHint => 'Que faire et qui appeler';

  @override
  String staffGreeting(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get levelField => 'Terrain';

  @override
  String get levelAnalyst => 'Analyste';

  @override
  String get levelCommander => 'Commandant';

  @override
  String get regionsLabel => 'Régions';

  @override
  String get allRegions => 'Toutes les régions';

  @override
  String get menuNewReport => 'Nouveau rapport';

  @override
  String get menuIncidents => 'Incidents';

  @override
  String get menuBrief => 'Briefing avant l\'arrivée';

  @override
  String get menuMap => 'Carte et MGRS';

  @override
  String get menuReview => 'Examiner les liens';

  @override
  String get menuDashboard => 'Tableau de bord';

  @override
  String get menuCivilReports => 'Signalements civils';

  @override
  String get menuWarnings => 'Publier des alertes';

  @override
  String get menuUsers => 'Gérer les comptes';

  @override
  String get menuAudit => 'Journal d\'audit';

  @override
  String get comingSoon => 'Cette partie arrive dans la prochaine version de l\'application.';

  @override
  String get settings => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get account => 'Compte';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String passwordTooShort(int min) {
    return 'Au moins $min caractères.';
  }

  @override
  String get passwordChanged => 'Mot de passe modifié.';

  @override
  String get deleteAccount => 'Supprimer mon compte';

  @override
  String get deleteAccountBody =>
      'Votre compte et votre numéro seront supprimés de cette application. Les signalements déjà reçus par l\'Armée restent à l\'Armée.';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String signedInAs(String who) {
    return 'Connecté en tant que $who';
  }
}
