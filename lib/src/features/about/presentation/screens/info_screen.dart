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

class _InfoScreenState extends State<InfoScreen> with SingleTickerProviderStateMixin {
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
            Tab(
              icon: Icon(Icons.code_rounded),
              text: 'For Developers',
            ),
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
  Widget _buildTravelersTab(BuildContext context, ThemeData theme, bool isDark) {
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    final textHeader = isDark ? Colors.white : const Color(0xFF0F172A);
    final textBody = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Text(
              '100% Nostr-Native Ridesharing',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Text(
              'Rideshares.org is a free, open, peer-to-peer ridesharing network built on the open Nostr protocol. There are no corporate middlemen, no take rates, and no centralized gatekeepers.\n\nYou own your identity, your rides, and your reputation. Because the network is open, anyone can build a client. If you prefer another app with different features or aesthetics (like Trip Hopping), your rides and account are already there. No importing, no exporting, and no lock-in.',
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: textBody,
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
              isDark: isDark,
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
              isDark: isDark,
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
              isDark: isDark,
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
              isDark: isDark,
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
              isDark: isDark,
              icon: Icons.currency_bitcoin_rounded,
              title: 'Free, Cost-Sharing, or Bitcoin/Lightning',
              description:
                  'Specify free rides, gas cost-sharing in local currency, or direct satoshi compensation. Transactions happen directly between driver and rider.',
            ),
          ),

          const SizedBox(height: 24),
          Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          Text(
            'Understanding Nostr Keypairs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textHeader,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Public Key (npub): Your public travel identity. Share this freely with drivers and passengers.\n'
            '• Private Key (nsec): Your secret signing key. Never share this with anyone! It is saved securely on your device or managed in Amber.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: textBody,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================
  // ANDROID DISTRIBUTION SECTION
  // ==========================================
  Widget _buildAndroidDownloadSection(BuildContext context, ThemeData theme, bool isDark) {
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    final textHeader = isDark ? Colors.white : const Color(0xFF0F172A);
    final textBody = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
          width: 1.5,
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
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.android_rounded, color: primaryColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android App & Direct APK',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textHeader,
                      ),
                    ),
                    Text(
                      '100% Free & Open-Source (FOSS) • No Google Play Required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
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
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: textBody,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'How to Install & Update Outside Google Play:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: textHeader,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Tap "Download Android APK" below and open the downloaded file.\n'
                  '2. If Android prompts "Install unknown apps", tap Settings and allow "From this source".\n'
                  '3. Built-in updates: The app checks for newer releases automatically, or you can manage updates with Obtainium / F-Droid.',
                  style: TextStyle(
                    height: 1.5,
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
                      final ver = snapshot.data ?? '1.1.3';
                      return Text(
                        'Installed Version: v$ver',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textHeader,
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
                          fontSize: 13.5,
                          color: Color(0xFF4ADE80),
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
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                        ),
                        onPressed: updateService.isChecking
                            ? null
                            : () async {
                                final res = await updateService.checkForUpdates();
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
                        icon: updateService.isChecking
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text('Check for Updates'),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: primaryColor),
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
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    final textHeader = isDark ? Colors.white : const Color(0xFF0F172A);
    final textBody = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: isDark ? 2 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primaryColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textHeader,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: textBody,
                      height: 1.45,
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
  Widget _buildDevelopersTab(BuildContext context, ThemeData theme, bool isDark) {
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
    final textHeader = isDark ? Colors.white : const Color(0xFF0F172A);
    final textBody = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Text(
              'Protocol Specifications & Interoperability',
              style: TextStyle(
                fontSize: 22,
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: Text(
              'Rideshares.org defines the standard Nostr protocol specification for ridesharing, hitchhiking, and transit coordination. Any Nostr client can broadcast and query these events for instant ecosystem interoperability.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: textBody,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Core NIPs & Kinds Summary Card
          FadeInUp(
            duration: const Duration(milliseconds: 550),
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: cardBorder),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NIPs & Event Kinds Implemented',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNipRow('Kind 30402', 'NIP-99', 'Classified Listings for Ride Offers, Requests, & Travel Partners', isDark),
                    _buildNipRow('Kind 5', 'NIP-09', 'Event Deletion Requests for removing cancelled or obsolete rides', isDark),
                    _buildNipRow('NIP-01', 'Core Nostr', 'BIP-340 Schnorr Signatures, REQ Filters, & WebSocket Transports', isDark),
                    _buildNipRow('NIP-07', 'Web Signers', 'Browser extension signing via window.nostr (Alby, nos2x, etc.)', isDark),
                    _buildNipRow('NIP-46', 'Remote Signer', 'Bunker / NostrConnect QR & RPC communication protocol', isDark),
                    _buildNipRow('NIP-55', 'Android Intent', 'Amber external intent application signing on Android', isDark),
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
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: cardBorder),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Bootstrap Relays',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• wss://relay.damus.io\n'
                      '• wss://nos.lol\n'
                      '• wss://relay.primal.net\n'
                      '• wss://relay.nostr.band\n'
                      '• wss://relay.trustroots.org',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        height: 1.6,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
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
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: cardBorder),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kind 30402 Rideshare Tag Structure',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kind 30402 is a parameterized replaceable event. Updating a listing is accomplished by re-publishing with the identical "d" tag and latest created_at timestamp.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: textBody,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Table(
                      border: TableBorder.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(2.6),
                      },
                      children: [
                        _buildTableHeader(isDark),
                        _buildTableRow('d', 'String (UUID/slug)', 'Unique listing ID (enables editing & status updates)', isDark),
                        _buildTableRow('title', 'String', 'Human-readable title (e.g. "Rideshare Denver to Moab")', isDark),
                        _buildTableRow('t', 'Taxonomy tags', 'rideshare, ride-offer, ride-request, travel-partner, rideshares.org', isDark),
                        _buildTableRow('location', 'String', 'Human-readable Origin city / place name', isDark),
                        _buildTableRow('location_dest', 'String', 'Human-readable Destination city / place name', isDark),
                        _buildTableRow('departure_utc', 'Unix seconds', 'Scheduled departure timestamp in UTC', isDark),
                        _buildTableRow('origin_tz', 'IANA TZ string', 'Origin local timezone (e.g. "America/Denver")', isDark),
                        _buildTableRow('g', 'Geohash prefix', 'Origin cascading geohash (length 1–6) for proximity filters', isDark),
                        _buildTableRow('dg', 'Geohash prefix', 'Destination cascading geohash (length 1–6)', isDark),
                        _buildTableRow('origin_lat / origin_lon', 'Float strings', 'Origin map coordinates', isDark),
                        _buildTableRow('dest_lat / dest_lon', 'Float strings', 'Destination map coordinates', isDark),
                        _buildTableRow('price', '[amount, currency]', '["0", "USD"] (Free/Share) or ["25000", "SATS"]', isDark),
                        _buildTableRow('status', 'active / sold / cancelled', 'Listing lifecycle status ("sold" = filled)', isDark),
                        _buildTableRow('published_at', 'Unix seconds', 'Original publication timestamp (retained across edits)', isDark),
                        _buildTableRow('summary', 'String', 'Short summary tagline', isDark),
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
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: cardBorder),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Signed Event (Kind 30402)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: SelectableText(
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
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
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
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Source & Developer Community',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rideshares.org is 100% open source under the MIT License. Contributions, issues, and client adaptations are warmly welcomed!',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: textBody,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            launchUrl(
                              Uri.parse('https://github.com/kenflannery/rideshares-nostr'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.code, size: 18),
                          label: const Text('GitHub Repository'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                          ),
                          onPressed: () {
                            launchUrl(
                              Uri.parse('https://github.com/kenflannery/rideshares-nostr/issues'),
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

  Widget _buildNipRow(String kindOrNip, String tag, String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              kindOrNip,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader(bool isDark) {
    return TableRow(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Tag',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Format',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Purpose & Standard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String tag, String format, String purpose, bool isDark) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            tag,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            format,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            purpose,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}
