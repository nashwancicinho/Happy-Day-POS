import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final String? releaseName;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
    this.forceUpdate = false,
    this.releaseName,
  });
}

class UpdateService {
  static const String _defaultGithubRepo = 'nashwancicinho/Happy-Day-POS';

  /// Gets the current installed version string from pubspec metadata
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version; // e.g. "1.0.0"
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return '1.0.0';
    }
  }

  /// Checks for update against GitHub Releases or a custom JSON URL endpoint
  static Future<AppUpdateInfo> checkForUpdates({
    String? customApiUrl,
    String? githubRepo,
  }) async {
    final currentVersion = await getCurrentVersion();
    final repo = githubRepo ?? _defaultGithubRepo;
    final url = (customApiUrl != null && customApiUrl.trim().isNotEmpty)
        ? customApiUrl
        : 'https://api.github.com/repos/$repo/releases/latest';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Check if response is from GitHub Releases API
        if (data.containsKey('tag_name')) {
          return _parseGithubRelease(data, currentVersion);
        } else if (data.containsKey('latest_version')) {
          // Custom JSON format
          return _parseCustomJsonRelease(data, currentVersion);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      hasUpdate: false,
      downloadUrl: '',
      releaseNotes: '',
    );
  }

  static AppUpdateInfo _parseGithubRelease(Map<String, dynamic> data, String currentVersion) {
    String tag = (data['tag_name'] as String? ?? '').replaceAll('v', '').trim();
    String releaseNotes = data['body'] as String? ?? 'تحديث جديد يتضمن تحسينات وإصلاحات.';
    String releaseName = data['name'] as String? ?? 'إصدار جديد $tag';
    
    String downloadUrl = '';
    final assets = data['assets'] as List<dynamic>? ?? [];

    for (var asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final url = asset['browser_download_url'] as String? ?? '';
      
      // Look for .exe file for Windows or .apk for Android
      if (Platform.isWindows && name.endsWith('.exe')) {
        downloadUrl = url;
        break;
      } else if (Platform.isAndroid && name.endsWith('.apk')) {
        downloadUrl = url;
        break;
      } else if (url.isNotEmpty) {
        downloadUrl = url;
      }
    }

    final cleanCurrent = _cleanVersion(currentVersion);
    final cleanLatest = _cleanVersion(tag);

    final hasUpdate = _isVersionHigher(cleanLatest, cleanCurrent) && downloadUrl.isNotEmpty;

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: tag,
      hasUpdate: hasUpdate,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      releaseName: releaseName,
    );
  }

  static AppUpdateInfo _parseCustomJsonRelease(Map<String, dynamic> data, String currentVersion) {
    String latestVersion = data['latest_version'] as String? ?? currentVersion;
    String downloadUrl = data['download_url'] as String? ?? '';
    String releaseNotes = data['release_notes'] as String? ?? 'تحديث جديد متوفر للبرنامج.';
    bool forceUpdate = data['force_update'] as bool? ?? false;

    final cleanCurrent = _cleanVersion(currentVersion);
    final cleanLatest = _cleanVersion(latestVersion);

    final hasUpdate = _isVersionHigher(cleanLatest, cleanCurrent) && downloadUrl.isNotEmpty;

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      hasUpdate: hasUpdate,
      downloadUrl: downloadUrl,
      releaseNotes: releaseNotes,
      forceUpdate: forceUpdate,
    );
  }

  /// Compares two semver strings (e.g., "1.1.0" > "1.0.0")
  static bool _isVersionHigher(String v1, String v2) {
    try {
      List<int> parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      int maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
      for (int i = 0; i < maxLength; i++) {
        int num1 = i < parts1.length ? parts1[i] : 0;
        int num2 = i < parts2.length ? parts2[i] : 0;

        if (num1 > num2) return true;
        if (num1 < num2) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions $v1 and $v2: $e');
    }
    return false;
  }

  static String _cleanVersion(String v) {
    if (v.contains('+')) {
      v = v.split('+')[0];
    }
    return v.trim();
  }

  /// Downloads the update setup installer file while streaming progress (0.0 to 1.0)
  static Stream<double> downloadUpdateFile({
    required String url,
    required String destinationPath,
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('فشل التنزيل رمز الحالة: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;
      final file = File(destinationPath);
      final sink = file.openWrite();

      await for (var chunk in response.stream) {
        downloaded += chunk.length;
        sink.add(chunk);

        if (contentLength > 0) {
          yield downloaded / contentLength;
        } else {
          yield -1.0; // Unknown size
        }
      }

      await sink.flush();
      await sink.close();
      yield 1.0;
    } finally {
      client.close();
    }
  }

  /// Returns the target temp path for downloading the installer file
  static Future<String> getTempInstallerPath({String fileName = 'HappyDayPOS_Setup_Update.exe'}) async {
    final tempDir = await getTemporaryDirectory();
    return p.join(tempDir.path, fileName);
  }

  /// Launches the downloaded installer file and closes the current application
  static Future<bool> launchInstallerAndExit(String installerPath) async {
    try {
      final file = File(installerPath);
      if (!await file.exists()) {
        debugPrint('Installer file does not exist at $installerPath');
        return false;
      }

      if (Platform.isWindows) {
        // Execute installer on Windows asynchronously
        await Process.start(
          installerPath,
          [],
          mode: ProcessStartMode.detached,
        );
        // Exit application so setup can overwrite executable files without lock
        Future.delayed(const Duration(milliseconds: 500), () {
          exit(0);
        });
        return true;
      } else if (Platform.isAndroid) {
        // For Android apk installation
        await Process.run('am', ['start', '-a', 'android.intent.action.VIEW', '-t', 'application/vnd.android.package-archive', '-d', 'file://$installerPath']);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [installerPath]);
        return true;
      }
    } catch (e) {
      debugPrint('Error launching installer: $e');
    }
    return false;
  }
}
