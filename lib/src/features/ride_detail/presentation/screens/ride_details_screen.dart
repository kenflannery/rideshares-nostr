import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:animate_do/animate_do.dart'; // For animations
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/ride_item_model.dart';

class RideDetailsScreen extends StatefulWidget {
  final RideItemModel ride;

  const RideDetailsScreen({super.key, required this.ride});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  bool _isMetadataExpanded = false;

  @override
  Widget build(BuildContext context) {
    String formattedDepartureTime = 'Time Unknown';
    try {
      if (widget.ride.originTimezone != null && widget.ride.originTimezone != 'UTC') {
        final location = tz.getLocation(widget.ride.originTimezone!);
        final localizedDt = tz.TZDateTime.from(widget.ride.departureTimeUtc, location);
        formattedDepartureTime = '${DateFormat("MMM d y, hh:mm a z").format(localizedDt)} (${widget.ride.originTimezone})';
      } else {
        formattedDepartureTime = '${DateFormat("MMM d y, hh:mm a").format(widget.ride.departureTimeUtc)} (UTC)';
      }
    } catch (e) {
      debugPrint("Error formatting time for ride ${widget.ride.id}: $e");
      formattedDepartureTime = 'Invalid Date';
    }

    String formattedPrice = 'Not specified';
    if (widget.ride.priceAmount != null && widget.ride.priceAmount != "0") {
      String currency = widget.ride.priceCurrency ?? '';
      String amount = widget.ride.priceAmount!;
      if (currency == 'USD') currency = '\$';
      else if (currency == 'EUR') currency = '€';
      else if (currency == 'GBP') currency = '£';
      else if (currency == 'SATS') currency = ' sats';
      else currency = ' $currency';
      formattedPrice = currency == ' sats' || currency.startsWith(' ') ? '$amount$currency' : '$currency$amount';
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          '${widget.ride.origin.displayName} to ${widget.ride.destination.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.ride.status == RideStatus.active ? Colors.green : Colors.grey,
                    child: Icon(
                      widget.ride.type == RideType.offer ? Icons.drive_eta : Icons.hail,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    widget.ride.type == RideType.offer
                        ? 'Ride Offer'
                        : widget.ride.type == RideType.partner
                            ? 'Looking for travel partner'
                            : 'Ride Request',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Status: ${widget.ride.status.name.toUpperCase()}',
                    style: TextStyle(color: widget.ride.status == RideStatus.active ? Colors.orange : Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Map Section
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        (widget.ride.origin.latitude + widget.ride.destination.latitude) / 2,
                        (widget.ride.origin.longitude + widget.ride.destination.longitude) / 2,
                      ),
                      initialZoom: 10.0,
                      minZoom: 2,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(widget.ride.origin.latitude, widget.ride.origin.longitude),
                            child: const Icon(Icons.location_pin, color: Colors.green, size: 30),
                          ),
                          Marker(
                            width: 40,
                            height: 40,
                            point: LatLng(widget.ride.destination.latitude, widget.ride.destination.longitude),
                            child: const Icon(Icons.location_pin, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Details Section
            Text('Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FadeInUp(
              duration: const Duration(milliseconds: 700),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(context, Icons.location_on, 'Origin', widget.ride.origin.displayName),
                      _buildDetailRow(context, Icons.flag, 'Destination', widget.ride.destination.displayName),
                      _buildDetailRow(context, Icons.schedule, 'Departure', formattedDepartureTime),
                      _buildDetailRow(context, Icons.attach_money, 'Price', formattedPrice),
                      if (widget.ride.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Description', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.ride.description, style: Theme.of(context).textTheme.bodyMedium),
                        _buildMessageButton(widget.ride.pubkey),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Metadata Section with Collapsible Raw Data
            Text('Metadata', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(context, Icons.fingerprint, 'Event ID', widget.ride.id, isSelectable: true),
                      _buildDetailRowWithLink(context, Icons.person, 'Posted by', widget.ride.pubkey),
                      _buildDetailRow(context, Icons.calendar_today, 'Created At', DateFormat.yMd().add_jm().format(widget.ride.createdAt)),
                      ExpansionTile(
                        title: const Text(
                          'Raw Nostr Event',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        leading: const Icon(Icons.code, color: Colors.blueAccent),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SelectableText(
                              _formatRawNostrEvent(widget.ride),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageButton(String pubkey) {

    if (pubkey.isEmpty) {
      return const SizedBox.shrink(); // Return an empty widget if pubkey is empty
    }
    String npub = Nostr.instance.services.bech32.encodePublicKeyToNpub(pubkey);
    String url = 'https://www.nostrchat.io/dm/$npub';
    if (url.isEmpty) {
      return const SizedBox.shrink(); // Return an empty widget if URL is empty
  }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.message),
        label: const Text('Message'),
        onPressed: () {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
    ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {bool isSelectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: isSelectable
                ? SelectableText(value, style: Theme.of(context).textTheme.bodyMedium)
                : Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }


  Widget _buildDetailRowWithLink(BuildContext context, IconData icon, String label, String value) {

    String npub = Nostr.instance.services.bech32.encodePublicKeyToNpub(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () async {
                final url = 'https://njump.me/$npub';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open link')),
                  );
                }
              },
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRawNostrEvent(RideItemModel ride) {
    // Construct a simplified representation of the Nostr event
    final eventData = {
      'id': ride.id,
      'pubkey': ride.pubkey,
      'created_at': ride.createdAt.millisecondsSinceEpoch ~/ 1000,
      'kind': 30402,
      'tags': [
        ['t', 'rideshare'],
        ['g', ride.origin.geohash],
        ['dg', ride.destination.geohash],
        ['location_dest', ride.destination.displayName],
        ['coordinates', '${ride.origin.latitude},${ride.origin.longitude}'],
        ['departure_utc', ride.departureTimeUtc.toIso8601String()],
        ['origin_tz', ride.originTimezone ?? 'UTC'],
        if (ride.priceAmount != null && ride.priceAmount != "0") ['price', ride.priceAmount!, ride.priceCurrency ?? ''],
        ['d', ride.status.name],
      ],
      'content': ride.description,
      'sig': ride.rawNostrEvent?.sig,
    };

    // Pretty-print the event data as a JSON-like string
    return _prettyPrintEvent(eventData);
  }

  String _prettyPrintEvent(Map<String, dynamic> event) {
    final buffer = StringBuffer();
    buffer.writeln('{');
    event.forEach((key, value) {
      if (value is List) {
        buffer.writeln('  "$key": [');
        for (var i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is List) {
            buffer.write('    [${item.map((e) => '"$e"').join(', ')}]');
          } else {
            buffer.write('    "$item"');
          }
          if (i < value.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('  ]');
      } else {
        buffer.write('  "$key": ');
        if (value is String) {
          buffer.write('"$value"');
        } else {
          buffer.write(value.toString());
        }
      }
      if (key != event.keys.last) buffer.write(',');
      buffer.writeln();
    });
    buffer.write('}');
    return buffer.toString();
  }
}