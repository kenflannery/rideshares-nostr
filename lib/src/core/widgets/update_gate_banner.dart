import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker_service.dart';

/// Interactive banner that notifies users of updates or major protocol upgrades.
class UpdateGateBanner extends StatelessWidget {
  const UpdateGateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = Provider.of<UpdateCheckerService>(context);
    final info = updateService.updateInfo;

    if (info == null || !info.isUpdateAvailable) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // Major Breaking Upgrade Gate
    if (info.isBreakingMajorUpgrade) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.error, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protocol Upgrade Required (v${info.latestVersion})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rideshares.org has upgraded to a new major Nostr protocol standard. To maintain compatibility with other drivers and travelers, updating your app is required.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: () {
                    if (info.apkDownloadUrl != null) {
                      launchUrl(Uri.parse(info.apkDownloadUrl!), mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Update App Now'),
                ),
                const SizedBox(width: 8),
                if (info.releaseUrl != null)
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse(info.releaseUrl!), mode: LaunchMode.externalApplication),
                    child: const Text('Release Notes'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    // Minor / Patch Optional Update Notice
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Update available (v${info.latestVersion})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              if (info.apkDownloadUrl != null) {
                launchUrl(Uri.parse(info.apkDownloadUrl!), mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
