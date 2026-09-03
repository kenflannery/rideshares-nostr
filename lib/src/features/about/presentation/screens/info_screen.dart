import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/update_checker_service.dart';

/// About & Protocol Documentation Screen featuring dedicated tabs for Travelers and Developers.
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'About Rideshares.org',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.directions_car_rounded),
              text: 'For Travelers',
            ),
            Tab(icon: Icon(Icons.code_rounded), text: 'For Developers'),
          ],
        ),
      ),
      body: SelectionArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTravelersTab(context, theme, isDark),
            _buildDevelopersTab(context, theme, isDark),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: FOR TRAVELERS & DRIVERS
  // ==========================================
  Widget _buildTravelersTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Text(
              '100% Nostr-Native Ridesharing',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1976D2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Text(
              'Rideshares.org is a free, open, peer-to-peer ridesharing network built on the open Nostr protocol. There are no corporate middlemen, no take rates, and no centralized gatekeepers.\n\nYou own your identity, your rides, and your reputation. Because the network is open, anyone can build a client. If you prefer another app with different features or aesthetics (like Trip Hopping), your rides and account are already there. No importing, no exporting, and no lock-in.',
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Android APK & Updates Card
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: _buildAndroidDownloadSection(context, theme, isDark),
          ),
          const SizedBox(height: 24),

          // Feature Highlights
          FadeInUp(
            duration: const Duration(milliseconds: 650),
            child: _buildFeatureCard(
              context,
              theme,
              icon: Icons.vpn_key_rounded,
              title: 'Sovereign Cryptographic Identity',
              description:
                  'You control your account using your own Nostr keypair (npub / nsec) or remote signer (Amber / NIP-46 / NIP-07). No phone number or credit card registration required.',
            ),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 700),
            child: _buildFeatureCard(
              context,
              theme,
              icon: Icons.alt_route_rounded,
              title: 'Ride Offers & Ride Requests (NIP-99)',
              description:
                  'Drivers publish ride offers with available seats, and passengers publish ride requests with planned routes and departure times across open relays.',
            ),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 750),
            child: _buildFeatureCard(
              context,
              theme,
              icon: Icons.explore_rounded,
              title: 'Geohash Radius & Route Discovery',
              description:
                  'Origin and destination locations use cascading geohash bounds (g and dg tags) so you can find rides departing near you or headed towards your destination.',
            ),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 800),
            child: _buildFeatureCard(
              context,
              theme,
              icon: Icons.handshake_outlined,
              title: 'Travel Companions & Hitchhiking Partners',
              description:
                  'Looking for someone to share a road trip or hitchhike together? Post partner requests to connect with fellow travelers and backpackers.',
            ),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 850),
            child: _buildFeatureCard(
              context,
              theme,
              icon: Icons.currency_bitcoin_rounded,
              title: 'Free, Cost-Sharing, or Bitcoin/Lightning',
              description:
                  'Specify free rides, gas cost-sharing in local currency, or direct satoshi compensation. Transactions happen directly between driver and rider.',
            ),
          ),

          const SizedBox(height: 24),
          Divider(color: theme.dividerColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),

          Text(
            'Understanding Nostr Keypairs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Public Key (npub): Your public travel identity. Share this freely with drivers and passengers.\n'
            '• Private Key (nsec): Your secret signing key. Never share this with anyone! It is saved securely on your device or managed in Amber.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================
  // ANDROID DISTRIBUTION SECTION
  // ==========================================
  Widget _buildAndroidDownloadSection(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.android_rounded,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android App & Direct APK',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '100% Free & Open-Source (FOSS) • No Google Play Required',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Rideshares.org is distributed independently without corporate trackers, Google Play account requirements, or middlemen. Anyone can install the Android APK directly.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'How to Install & Update Outside Google Play:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Tap "Download Android APK" below and open the downloaded file.\n'
                  '2. If Android prompts "Install unknown apps", tap Settings and allow "From this source".\n'
                  '3. Built-in updates: The app checks for newer releases automatically, or you can manage updates with Obtainium / F-Droid.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Consumer<UpdateCheckerService>(
            builder: (context, updateService, _) {
              final updateInfo = updateService.updateInfo;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: UpdateCheckerService.getCurrentVersion(),
                    builder: (context, snapshot) {
                      final ver = snapshot.data ?? '1.1.0';
                      return Text(
                        'Installed Version: v$ver',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  if (updateInfo != null && updateInfo.isUpdateAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'New release available: v${updateInfo.latestVersion}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          launchUrl(
                            Uri.parse(
                              'https://github.com/${UpdateCheckerService.repoOwner}/${UpdateCheckerService.repoName}/releases/latest/download/rideshares-nostr-latest.apk',
                            ),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Android APK'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            updateService.isChecking
                                ? null
                                : () async {
                                  final res =
                                      await updateService.checkForUpdates();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res.isUpdateAvailable
                                              ? 'New version v${res.latestVersion} available!'
                                              : 'You are on the latest version (v${res.currentVersion}).',
                                        ),
                                      ),
                                    );
                                  }
                                },
                        icon:
                            updateService.isChecking
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh, size: 16),
                        label: const Text('Check for Updates'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          launchUrl(
                            Uri.parse(UpdateCheckerService.releasesWebUrl),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('All Releases'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1976D2), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: FOR DEVELOPERS & PROTOCOL SPECS
  // ==========================================
  Widget _buildDevelopersTab(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Text(
              'Protocol Specifications & Interoperability',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1976D2),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Text(
              'Rideshares.org defines the standard Nostr protocol specification for ridesharing, hitchhiking, and transit coordination. Any Nostr client can broadcast and query these events for instant ecosystem interoperability.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 20),

          // Core NIPs & Kinds Summary Card
          FadeInUp(
            duration: const Duration(milliseconds: 550),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NIPs & Event Kinds Implemented',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNipRow(
                      'Kind 30402',
                      'NIP-99',
                      'Classified Listings for Ride Offers, Requests, & Travel Partners',
                    ),
                    _buildNipRow(
                      'Kind 5',
                      'NIP-09',
                      'Event Deletion Requests for removing cancelled or obsolete rides',
                    ),
                    _buildNipRow(
                      'NIP-01',
                      'Core Nostr',
                      'BIP-340 Schnorr Signatures, REQ Filters, & WebSocket Transports',
                    ),
                    _buildNipRow(
                      'NIP-07',
                      'Web Signers',
                      'Browser extension signing via window.nostr (Alby, nos2x, etc.)',
                    ),
                    _buildNipRow(
                      'NIP-46',
                      'Remote Signer',
                      'Bunker / NostrConnect QR & RPC communication protocol',
                    ),
                    _buildNipRow(
                      'NIP-55',
                      'Android Intent',
                      'Amber external intent application signing on Android',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Default Bootstrap Relays Card
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Default Bootstrap Relays',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• wss://relay.damus.io\n'
                      '• wss://nos.lol\n'
                      '• wss://relay.primal.net\n'
                      '• wss://relay.nostr.band\n'
                      '• wss://relay.trustroots.org',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Kind 30402 Tag Specification Table
          FadeInUp(
            duration: const Duration(milliseconds: 650),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kind 30402 Rideshare Tag Structure',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kind 30402 is a parameterized replaceable event. Updating a listing is accomplished by re-publishing with the identical "d" tag and latest created_at timestamp.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade400),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(2.6),
                      },
                      children: [
                        _buildTableHeader(),
                        _buildTableRow(
                          'd',
                          'String (UUID/slug)',
                          'Unique listing ID (enables editing & status updates)',
                        ),
                        _buildTableRow(
                          'title',
                          'String',
                          'Human-readable title (e.g. "Rideshare Denver to Moab")',
                        ),
                        _buildTableRow(
                          't',
                          'Taxonomy tags',
                          'rideshare, ride-offer, ride-request, travel-partner, rideshares.org',
                        ),
                        _buildTableRow(
                          'location',
                          'String',
                          'Human-readable Origin city / place name',
                        ),
                        _buildTableRow(
                          'location_dest',
                          'String',
                          'Human-readable Destination city / place name',
                        ),
                        _buildTableRow(
                          'departure_utc',
                          'Unix seconds',
                          'Scheduled departure timestamp in UTC',
                        ),
                        _buildTableRow(
                          'origin_tz',
                          'IANA TZ string',
                          'Origin local timezone (e.g. "America/Denver")',
                        ),
                        _buildTableRow(
                          'g',
                          'Geohash prefix',
                          'Origin cascading geohash (length 1–6) for proximity filters',
                        ),
                        _buildTableRow(
                          'dg',
                          'Geohash prefix',
                          'Destination cascading geohash (length 1–6)',
                        ),
                        _buildTableRow(
                          'origin_lat / origin_lon',
                          'Float strings',
                          'Origin map coordinates',
                        ),
                        _buildTableRow(
                          'dest_lat / dest_lon',
                          'Float strings',
                          'Destination map coordinates',
                        ),
                        _buildTableRow(
                          'price',
                          '[amount, currency]',
                          '["0", "USD"] (Free/Share) or ["25000", "SATS"]',
                        ),
                        _buildTableRow(
                          'status',
                          'active / sold / cancelled',
                          'Listing lifecycle status ("sold" = filled)',
                        ),
                        _buildTableRow(
                          'published_at',
                          'Unix seconds',
                          'Original publication timestamp (retained across edits)',
                        ),
                        _buildTableRow(
                          'summary',
                          'String',
                          'Short summary tagline',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Verbatim JSON Payload Card
          FadeInUp(
            duration: const Duration(milliseconds: 700),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sample Signed Event (Kind 30402)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black45 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        '''{
  "kind": 30402,
  "created_at": 1746522000,
  "pubkey": "a1b2c3d4e5f6...7890",
  "content": "Offering 2 seats from Denver to Moab. Space for backpacks. Sharing gas cost.\\n\\nDeparture: May 6 2026, 08:00 AM MDT\\nOrigin: Denver, CO\\nDestination: Moab, UT\\nNOTE: Posted via Rideshares.org.",
  "tags": [
    ["d", "ride-denver-moab-20260506-a1b2"],
    ["title", "Rideshare offer from Denver, CO to Moab, UT"],
    ["published_at", "1746522000"],
    ["t", "rideshare"],
    ["t", "ride-offer"],
    ["t", "rideshares.org"],
    ["location", "Denver, CO"],
    ["location_dest", "Moab, UT"],
    ["g", "9"], ["g", "9x"], ["g", "9xj"], ["g", "9xj6"], ["g", "9xj64"], ["g", "9xj64x"],
    ["dg", "9"], ["dg", "9x"], ["dg", "9xh"], ["dg", "9xhz"], ["dg", "9xhzg"], ["dg", "9xhzg0"],
    ["origin_lat", "39.7392"],
    ["origin_lon", "-104.9903"],
    ["dest_lat", "38.5733"],
    ["dest_lon", "-109.5498"],
    ["departure_utc", "1746540000"],
    ["origin_tz", "America/Denver"],
    ["price", "25", "USD"],
    ["status", "active"]
  ],
  "id": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "sig": "3045022100..."
}''',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Repository & Contributing
          FadeInUp(
            duration: const Duration(milliseconds: 750),
            child: Card(
              color:
                  isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open Source & Developer Community',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rideshares.org is 100% open source under the MIT License. Contributions, issues, and client adaptations are warmly welcomed!',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(
                                'https://github.com/kenflannery/rideshares-nostr',
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.code, size: 18),
                          label: const Text('GitHub Repository'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(
                                'https://github.com/kenflannery/rideshares-nostr/issues',
                              ),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.bug_report_outlined, size: 18),
                          label: const Text('Report Issue / Feature'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNipRow(String kindOrNip, String tag, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              kindOrNip,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF1976D2),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return const TableRow(
      decoration: BoxDecoration(color: Color(0x191976D2)),
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Tag',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Format',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Purpose & Standard',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String tag, String format, String purpose) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            tag,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(format, style: const TextStyle(fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(purpose, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
