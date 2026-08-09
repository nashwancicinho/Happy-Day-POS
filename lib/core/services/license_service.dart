import 'dart:convert';
import '../../features/settings/settings_repository.dart';

class LicenseInfo {
  final bool isActivated;
  final String licenseType; // 'TRIAL' or 'ANNUAL'
  final int daysRemaining;
  final DateTime firstLaunchDate;
  final DateTime? expiryDate;
  final String? activationKey;
  final bool isExpired;

  LicenseInfo({
    required this.isActivated,
    required this.licenseType,
    required this.daysRemaining,
    required this.firstLaunchDate,
    this.expiryDate,
    this.activationKey,
    required this.isExpired,
  });
}

class LicenseService {
  static final LicenseService instance = LicenseService._internal();
  LicenseService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();
  static const String _secretSalt = 'HAPPY_DAY_POS_SALT_KEY_2026_ANNUAL_SUB';
  static const int trialDurationDays = 30;

  /// Initialize license on startup. Ensures first launch date is recorded.
  Future<LicenseInfo> initAndGetLicenseInfo() async {
    final settings = await _settingsRepository.getAllSettings();

    String? firstLaunchStr = settings['license_first_launch_date'];
    if (firstLaunchStr == null || firstLaunchStr.isEmpty) {
      firstLaunchStr = DateTime.now().toIso8601String();
      await _settingsRepository.saveSetting('license_first_launch_date', firstLaunchStr);
    }

    final firstLaunchDate = DateTime.tryParse(firstLaunchStr) ?? DateTime.now();
    final isActivated = settings['license_is_active'] == 'true';
    final activationKey = settings['license_key'];
    final expiryStr = settings['license_expiry_date'];
    final expiryDate = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    final licenseType = isActivated ? 'ANNUAL' : 'TRIAL';

    bool isExpired = false;
    int daysRemaining = 0;

    if (isActivated) {
      if (expiryDate != null) {
        final diff = expiryDate.difference(DateTime.now()).inDays;
        daysRemaining = diff > 0 ? diff : 0;
        isExpired = DateTime.now().isAfter(expiryDate);
      } else {
        // Lifetime or active without explicit expiry date
        daysRemaining = 365;
        isExpired = false;
      }
    } else {
      final daysPassed = DateTime.now().difference(firstLaunchDate).inDays;
      daysRemaining = trialDurationDays - daysPassed;
      if (daysRemaining < 0) daysRemaining = 0;
      isExpired = daysPassed >= trialDurationDays;
    }

    return LicenseInfo(
      isActivated: isActivated,
      licenseType: licenseType,
      daysRemaining: daysRemaining,
      firstLaunchDate: firstLaunchDate,
      expiryDate: expiryDate,
      activationKey: activationKey,
      isExpired: isExpired,
    );
  }

  /// Cryptographic key validation algorithm
  bool validateKey(String key) {
    final cleanKey = key.trim().toUpperCase().replaceAll(' ', '');
    if (cleanKey.isEmpty) return false;

    // Expected format: HD-XXXX-YYYY-ZZZZ (or HDPOS-XXXX-YYYY-ZZZZ)
    final parts = cleanKey.split('-');
    if (parts.length != 4) return false;

    final prefix = parts[0];
    if (prefix != 'HD' && prefix != 'HDPOS') return false;

    final p1 = parts[1];
    final p2 = parts[2];
    final checksumPart = parts[3];

    // Compute expected checksum
    final expectedChecksum = _computeChecksum('$prefix-$p1-$p2');
    return checksumPart == expectedChecksum;
  }

  /// Activate subscription with a valid key for 1 year (365 days)
  Future<bool> activateLicense(String key) async {
    if (!validateKey(key)) return false;

    final cleanKey = key.trim().toUpperCase().replaceAll(' ', '');
    final now = DateTime.now();
    final expiryDate = now.add(const Duration(days: 365));

    await _settingsRepository.saveSetting('license_is_active', 'true');
    await _settingsRepository.saveSetting('license_key', cleanKey);
    await _settingsRepository.saveSetting('license_activation_date', now.toIso8601String());
    await _settingsRepository.saveSetting('license_expiry_date', expiryDate.toIso8601String());

    return true;
  }

  /// Helper to generate a valid annual key for customers
  static String generateAnnualKey({int seedOffset = 0}) {
    final now = DateTime.now();
    final seed = '${now.millisecondsSinceEpoch + seedOffset}';
    final rawHash = base64UrlEncode(utf8.encode('$seed-$_secretSalt')).replaceAll('=', '').toUpperCase();
    
    final p1 = rawHash.substring(0, 4).padRight(4, 'A');
    final p2 = rawHash.substring(4, 8).padRight(4, 'B');
    final checksum = _computeChecksum('HD-$p1-$p2');

    return 'HD-$p1-$p2-$checksum';
  }

  static String _computeChecksum(String data) {
    final combined = '$data-$_secretSalt';
    int hash = 0;
    for (int i = 0; i < combined.length; i++) {
      hash = (hash * 31 + combined.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
    return hex.substring(0, 4);
  }
}
