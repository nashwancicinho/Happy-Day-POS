import 'dart:convert';
import '../../features/settings/settings_repository.dart';

class LicenseInfo {
  final bool isActivated;
  final String licenseType; // 'TRIAL' or 'ANNUAL'
  final int daysRemaining;
  final DateTime firstLaunchDate;
  final DateTime? expiryDate;
  final String? activationKey;
  final String machineId;
  final bool isExpired;

  LicenseInfo({
    required this.isActivated,
    required this.licenseType,
    required this.daysRemaining,
    required this.firstLaunchDate,
    this.expiryDate,
    this.activationKey,
    required this.machineId,
    required this.isExpired,
  });
}

class LicenseService {
  static final LicenseService instance = LicenseService._internal();
  LicenseService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();
  static const String _secretSalt = 'HAPPY_DAY_POS_SALT_KEY_2026_ANNUAL_SUB';
  static const int trialDurationDays = 30;

  /// Get or generate unique hardware Machine ID for this installation
  Future<String> getDeviceMachineId() async {
    final settings = await _settingsRepository.getAllSettings();
    String? machineId = settings['license_machine_id'];
    if (machineId == null || machineId.isEmpty) {
      final nowStr = DateTime.now().millisecondsSinceEpoch.toString();
      final rawHash = base64UrlEncode(utf8.encode('MACHINE-$nowStr-$_secretSalt')).replaceAll('=', '').toUpperCase();
      final p1 = rawHash.substring(0, 4);
      final p2 = rawHash.substring(4, 8);
      machineId = 'HD-$p1-$p2';
      await _settingsRepository.saveSetting('license_machine_id', machineId);
    }
    return machineId;
  }

  /// Initialize license on startup. Ensures first launch date & machine ID are recorded.
  Future<LicenseInfo> initAndGetLicenseInfo() async {
    final settings = await _settingsRepository.getAllSettings();
    final machineId = await getDeviceMachineId();

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
      machineId: machineId,
      isExpired: isExpired,
    );
  }

  /// Validate key specifically for a given Machine ID (Hardware Locked & Single-Use)
  bool validateKeyForMachine(String key, String machineId) {
    final cleanKey = key.trim().toUpperCase().replaceAll(' ', '');
    final cleanMachineId = machineId.trim().toUpperCase().replaceAll(' ', '');
    if (cleanKey.isEmpty || cleanMachineId.isEmpty) return false;

    final parts = cleanKey.split('-');
    if (parts.length != 4) return false;

    final prefix = parts[0];
    if (prefix != 'HD' && prefix != 'HDPOS') return false;

    final p1 = parts[1];
    final p2 = parts[2];
    final checksumPart = parts[3];

    // Compute expected p1, p2 and checksum locked to this specific Machine ID
    final rawHash = base64UrlEncode(utf8.encode('$cleanMachineId-$_secretSalt')).replaceAll('=', '').toUpperCase();
    final expectedP1 = rawHash.substring(0, 4).padRight(4, 'A');
    final expectedP2 = rawHash.substring(4, 8).padRight(4, 'B');

    if (p1 != expectedP1 || p2 != expectedP2) return false;

    final expectedChecksum = _computeChecksumForMachine(cleanMachineId, '$prefix-$p1-$p2');
    return checksumPart == expectedChecksum;
  }

  /// Activate subscription with a valid hardware-locked key for 1 year (365 days)
  Future<bool> activateLicense(String key) async {
    final machineId = await getDeviceMachineId();
    if (!validateKeyForMachine(key, machineId)) return false;

    final cleanKey = key.trim().toUpperCase().replaceAll(' ', '');
    final now = DateTime.now();
    final expiryDate = now.add(const Duration(days: 365));

    await _settingsRepository.saveSetting('license_is_active', 'true');
    await _settingsRepository.saveSetting('license_key', cleanKey);
    await _settingsRepository.saveSetting('license_activation_date', now.toIso8601String());
    await _settingsRepository.saveSetting('license_expiry_date', expiryDate.toIso8601String());

    return true;
  }

  /// Generator helper for owner: Generates a 1-time annual key locked to customer's Machine ID
  static String generateAnnualKeyForMachine(String targetMachineId) {
    final cleanMachineId = targetMachineId.trim().toUpperCase().replaceAll(' ', '');
    final rawHash = base64UrlEncode(utf8.encode('$cleanMachineId-$_secretSalt')).replaceAll('=', '').toUpperCase();

    final p1 = rawHash.substring(0, 4).padRight(4, 'A');
    final p2 = rawHash.substring(4, 8).padRight(4, 'B');
    final checksum = _computeChecksumForMachine(cleanMachineId, 'HD-$p1-$p2');

    return 'HD-$p1-$p2-$checksum';
  }

  static String _computeChecksumForMachine(String machineId, String data) {
    final combined = '$machineId-$data-$_secretSalt';
    int hash = 0;
    for (int i = 0; i < combined.length; i++) {
      hash = (hash * 31 + combined.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).toUpperCase().padLeft(8, '0');
    return hex.substring(0, 4);
  }
}
