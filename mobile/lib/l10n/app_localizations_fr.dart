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
  String get iAmCivilianHint =>
      'Signalez un objet suspect et recevez les alertes de votre région';

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
  String get errorTooMany =>
      'Trop de tentatives. Patientez quelques minutes puis réessayez.';

  @override
  String get errorWrongCode => 'Code erroné ou expiré.';

  @override
  String get errorWrongLogin => 'Nom d\'utilisateur ou mot de passe incorrect.';

  @override
  String get errorAccountLocked =>
      'Compte bloqué temporairement après trop de tentatives.';

  @override
  String get errorAccountDisabled =>
      'Ce compte est désactivé. Contactez votre administrateur.';

  @override
  String get errorGeneric => 'Une erreur s\'est produite. Réessayez.';

  @override
  String get sessionExpired =>
      'Votre session a expiré. Veuillez vous reconnecter.';

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
  String get comingSoon =>
      'Cette partie arrive dans la prochaine version de l\'application.';

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

  @override
  String get catSuspiciousObject => 'Objet suspect';

  @override
  String get catUnexplodedOrdnance => 'Obus, roquette ou bombe non explosé';

  @override
  String get catSuspiciousVehicle => 'Véhicule suspect';

  @override
  String get catSuspiciousActivity => 'Activité suspecte';

  @override
  String get catOther => 'Autre';

  @override
  String get reportSafeDistance => 'Je suis à une distance sûre de l\'objet';

  @override
  String get reportSafeDistanceRequired =>
      'Éloignez-vous d\'abord. N\'envoyez le signalement qu\'à distance de sécurité.';

  @override
  String get reportWhat => 'Qu\'avez-vous vu ?';

  @override
  String get reportDescription => 'Description';

  @override
  String get reportDescriptionHint =>
      'Son aspect et l\'endroit exact (rue, repère)';

  @override
  String get reportPhoto => 'Photo (facultatif)';

  @override
  String get reportPhotoWarning =>
      'Ne vous approchez jamais pour prendre une photo.';

  @override
  String get reportTakePhoto => 'Prendre une photo';

  @override
  String get reportChoosePhoto => 'Depuis la galerie';

  @override
  String get reportRemovePhoto => 'Retirer la photo';

  @override
  String get photoUnsupported =>
      'Ce format de photo n\'est pas pris en charge. Utilisez JPEG ou PNG.';

  @override
  String get photoTooLarge =>
      'Cette photo est trop volumineuse (plus de 5 Mo).';

  @override
  String get reportLocation => 'Position';

  @override
  String get reportUseLocation => 'Utiliser ma position actuelle';

  @override
  String reportLocationFix(int meters) {
    return 'Position ajoutée (à environ $meters m près)';
  }

  @override
  String get reportLocationNone =>
      'Pas de position. Décrivez le lieu aussi précisément que possible.';

  @override
  String get locationServiceOff =>
      'La localisation est désactivée sur ce téléphone.';

  @override
  String get locationDenied => 'L\'autorisation de localisation a été refusée.';

  @override
  String get locationTimeout => 'Position introuvable. Réessayez à découvert.';

  @override
  String get locationOutside => 'Cette position est hors du Liban.';

  @override
  String get reportNeedsContent => 'Ajoutez une description ou une photo.';

  @override
  String get reportSend => 'Envoyer le signalement';

  @override
  String get reportSentTitle => 'Signalement reçu';

  @override
  String reportSentBody(String id) {
    return 'Référence $id. L\'Armée va l\'examiner. Restez loin de l\'objet.';
  }

  @override
  String get reportQueuedTitle => 'Enregistré sur ce téléphone';

  @override
  String get reportQueuedBody =>
      'Pas de connexion. Le signalement sera envoyé automatiquement dès le retour du réseau. En cas de danger immédiat, appelez la ligne d\'urgence.';

  @override
  String get reportDailyLimit =>
      'Vous avez envoyé beaucoup de signalements aujourd\'hui. Appelez plutôt la ligne d\'urgence.';

  @override
  String get ok => 'OK';

  @override
  String get myReportsEmpty => 'Vous n\'avez encore envoyé aucun signalement.';

  @override
  String get pendingSection => 'En attente d\'envoi';

  @override
  String get sentSection => 'Envoyés';

  @override
  String get sendNow => 'Envoyer maintenant';

  @override
  String get discard => 'Abandonner';

  @override
  String notSentReason(String reason) {
    return 'Non accepté : $reason';
  }

  @override
  String get statusReceived => 'Reçu';

  @override
  String get statusUnderReview => 'En cours d\'examen';

  @override
  String get statusClosed => 'Clôturé';

  @override
  String get statusRejected => 'Sans suite';

  @override
  String get statusWaiting => 'En attente d\'envoi';

  @override
  String get deliveredToArmy => 'Transmis à l\'Armée';

  @override
  String sentOn(String date) {
    return 'Envoyé le $date';
  }

  @override
  String savedOn(String date) {
    return 'Enregistré le $date';
  }

  @override
  String showingSaved(String date) {
    return 'Hors ligne. Copie du $date affichée.';
  }

  @override
  String get warningsEmpty => 'Aucune alerte en cours.';

  @override
  String get warningsAllAreas => 'Toutes les zones';

  @override
  String warningsUntil(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get warningsPullHint =>
      'Tirez vers le bas pour vérifier les nouvelles alertes.';

  @override
  String get severityInfo => 'Information';

  @override
  String get severityCaution => 'Prudence';

  @override
  String get severityDanger => 'Danger';

  @override
  String get safetyPlaceholder =>
      'Texte provisoire. Les consignes et numéros officiels de l\'Armée libanaise le remplaceront.';

  @override
  String get safetySteps => 'Si vous voyez un objet suspect';

  @override
  String get safetyHotlines => 'Numéros d\'urgence';

  @override
  String get call => 'Appeler';

  @override
  String get numberToBeConfirmed => 'Numéro à confirmer';

  @override
  String callFailed(String number) {
    return 'Impossible de lancer l\'appel. Composez le $number vous-même.';
  }
}
