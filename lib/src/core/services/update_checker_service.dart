import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Semantic version representation (Major.Minor.Patch).
class SemVer {
  final int major;
  final int minor;
  final int patch;

  const SemVer({
    required this.major,
    required this.minor,
    required this.patch,
  });

  /// Parses a version string (e.g. "1.2.3" or "v2.0.0+4" or "1.0.0").
  static SemVer? parse(String raw) {
    try {
      var clean = raw.trim().toLowerCase();
      if (clean.startsWith('v')) {
        clean = clean.substring(1);
      }
      final plusIdx = clean.indexOf('+');
      if (plusIdx != -1) {
        clean = clean.substring(0, plusIdx);
      }
      final dashIdx = clean.indexOf('-');
      if (dashIdx != -1) {
        clean = clean.substring(0, dashIdx);
      }

      final parts = clean.split('.');
      if (parts.isEmpty) return null;

      final major = int.tryParse(parts[0]);
      if (major == null) return null;

      final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

      return SemVer(major: major, minor: minor, patch: patch);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if `this` version is strictly older than [other].
  bool isOlderThan(SemVer other) {
    if (major < other.major) return true;
    if (major > other.major) return false;

    if (minor < other.minor) return true;
    if (minor > other.minor) return false;

    return patch < other.patch;
  }

  /// Returns true if [other] represents a breaking major upgrade over `this`.
  bool isMajorUpgrade(SemVer other) {
    return other.major > major;
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// Release metadata and update status information.
class AppUpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final String? releaseTitle;
  final String? releaseNotes;
  final String? releaseUrl;
  final String? apkDownloadUrl;
  final bool isUpdateAvailable;
  final bool isBreakingMajorUpgrade;
  final DateTime? checkedAt;

  const AppUpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.releaseTitle,
    this.releaseNotes,
    this.releaseUrl,
    this.apkDownloadUrl,
    this.isUpdateAvailable = false,
    this.isBreakingMajorUpgrade = false,
    this.checkedAt,
  });

  /// Factory for when no update is needed or check failed.
  factory AppUpdateInfo.upToDate({required String currentVersion}) {
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      isUpdateAvailable: false,
      isBreakingMajorUpgrade: false,
      checkedAt: DateTime.now(),
    );
  }
}

/// Service that checks the repository's GitHub Releases for newer versions.
class UpdateCheckerService with ChangeNotifier {
  static const String repoOwner = 'kenflannery';
  static const String repoName = 'rideshares-nostr';
  static const String fallbackVersion = '1.0.0';

  AppUpdateInfo? _updateInfo;
  bool _isChecking = false;

  AppUpdateInfo? get updateInfo => _updateInfo;
  bool get isChecking => _isChecking;
  bool get isUpdateAvailable => _updateInfo?.isUpdateAvailable ?? false;

  /// GitHub public API endpoint for the latest release.
  static String get latestReleaseApiUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// GitHub releases web URL for user viewing.
  static String get releasesWebUrl =>
      'https://github.com/$repoOwner/$repoName/releases';

  /// Asynchronously retrieves current installed app version.
  static Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.isNotEmpty ? info.version : fallbackVersion;
    } catch (_) {
      return fallbackVersion;
    }
  }

  /// Checks GitHub Releases API for a newer version.
  Future<AppUpdateInfo> checkForUpdates() async {
    _isChecking = true;
    notifyListeners();

    final currentVerStr = await getCurrentVersion();
    final currentSemVer = SemVer.parse(currentVerStr) ?? const SemVer(major: 1, minor: 0, patch: 0);

    try {
      final response = await http.get(
        Uri.parse(latestReleaseApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Rideshares-AppUpdateChecker',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final tagName = data['tag_name']?.toString() ?? '';
        final title = data['name']?.toString() ?? tagName;
        final body = data['body']?.toString();
        final htmlUrl = data['html_url']?.toString() ?? releasesWebUrl;

        // Find .apk asset if present
        String? apkUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            final name = asset['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url']?.toString();
              break;
            }
          }
        }

        final latestSemVer = SemVer.parse(tagName);
        if (latestSemVer != null) {
          final isOlder = currentSemVer.isOlderThan(latestSemVer);
          final isMajor = currentSemVer.isMajorUpgrade(latestSemVer);

          _updateInfo = AppUpdateInfo(
            currentVersion: currentVerStr,
            latestVersion: latestSemVer.toString(),
            releaseTitle: title,
            releaseNotes: body,
            releaseUrl: htmlUrl,
            apkDownloadUrl: apkUrl ?? htmlUrl,
            isUpdateAvailable: isOlder,
            isBreakingMajorUpgrade: isOlder && isMajor,
            checkedAt: DateTime.now(),
          );
          _isChecking = false;
          notifyListeners();
          return _updateInfo!;
        }
      }
    } catch (e) {
      debugPrint('UpdateCheckerService error: $e');
    }

    _updateInfo = AppUpdateInfo.upToDate(currentVersion: currentVerStr);
    _isChecking = false;
    notifyListeners();
    return _updateInfo!;
  }
}
