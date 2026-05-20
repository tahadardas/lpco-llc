import 'package:lpco_llc/core/storage/storage_service.dart';

class LegalConsentService {
  static final LegalConsentService _instance = LegalConsentService._internal();

  factory LegalConsentService() => _instance;

  LegalConsentService._internal();

  // Update this version whenever the legal documents change significantly
  // to prompt users to accept the new terms.
  static const String currentVersion = '2026-05-20-v1';
  static const String _consentVersionKey = 'legal_consent_version';
  static const String _consentAcceptedAtKey = 'legal_consent_accepted_at';

  bool hasAcceptedCurrentVersion() {
    final storedVersion = StorageService().settingsBox.get(_consentVersionKey);
    return storedVersion == currentVersion;
  }

  Future<void> acceptCurrentVersion() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await StorageService().settingsBox.put(_consentVersionKey, currentVersion);
    await StorageService().settingsBox.put(_consentAcceptedAtKey, now);
  }

  String? getAcceptedAt() {
    return StorageService().settingsBox.get(_consentAcceptedAtKey) as String?;
  }
}
