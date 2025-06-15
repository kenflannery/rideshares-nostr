import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:animate_do/animate_do.dart';
import '../../../../core/models/ride_item_model.dart';
import '../providers/my_rides_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/nostr_service.dart';
import '../../../post_ride/presentation/screens/post_ride_screen.dart';

class MyRidesScreen extends StatelessWidget {
  const MyRidesScreen({super.key});

  Future<void> _showRelayManagementDialog(BuildContext context) async {
    final nostrService = context.read<NostrService>();
    final TextEditingController relayController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manage Nostr Relays'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: relayController,
                  decoration: InputDecoration(
                    labelText: 'Add New Relay (wss://...)',
                    border: const OutlineInputBorder(),
                    errorText: relayController.text.isNotEmpty && !relayController.text.startsWith('wss://')
                        ? 'Relay must start with wss://'
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Current Relays:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...nostrService.relays.map((relay) {
                  final isConnected = nostrService.connectedRelayUrls.contains(relay['url'] as String);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      relay['url'] as String,
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.grey,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            (relay['active'] as bool) ? Icons.toggle_on : Icons.toggle_off,
                            color: (relay['active'] as bool) ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () async {
                            await nostrService.toggleRelayActive(relay['url'] as String);
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove Relay'),
                                content: Text('Remove ${relay['url']} from the relay list?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await nostrService.removeRelay(relay['url'] as String);
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                    TextButton(
                      onPressed: relayController.text.isEmpty || !relayController.text.startsWith('wss://')
                          ? () {ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relay format invalid')));}
                          : () async {
                        final success = await nostrService.addRelay(relayController.text.trim());
                        if (success) {
                          relayController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relay added successfully')));
                          Navigator.of(dialogContext).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add relay')));
                        }
                      },
                      child: const Text('Add Relay'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
    relayController.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'My Posted Rides',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
          ),
        ),
        actions: [
          Consumer<MyRidesProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh My Rides',
                onPressed: provider.isLoading ? null : () => provider.fetchMyRides(forceRefresh: true),
              );
            },
          ),
        ],
      ),
      body: Consumer3<NostrService, MyRidesProvider, AuthService>(
        builder: (context, nostrService, ridesProvider, authService, child) {
          final loggedInSection = authService.isLoggedIn
              ? FadeIn(
            duration: const Duration(milliseconds: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Logged In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Public Key (npub):'),
                        Row(
                          children: [
                            SelectableText(
                              authService.npub ?? 'Error: Npub not found',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: authService.npub == null
                                  ? null
                                  : () {
                                Clipboard.setData(ClipboardData(text: authService.npub!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Npub copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Private Key (nsec):'),
                        Consumer<AuthService>(
                          builder: (context, authService, child) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: SelectableText(
                                    authService.nsec ?? 'Not available',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    authService.showNsec ? Icons.visibility_off : Icons.visibility,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    authService.toggleNsecVisibility();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16),
                                  onPressed: authService.nsec == null || !authService.showNsec
                                      ? null
                                      : () {
                                    Clipboard.setData(ClipboardData(text: authService.nsec!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Nsec copied to clipboard')),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Nostr Relays:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => _showRelayManagementDialog(context),
                          child: const Text('Edit Relays', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    ),
                    ...nostrService.relays.map((relay) {
                      final isConnected = nostrService.connectedRelayUrls.contains(relay['url'] as String);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              isConnected ? Icons.check_circle : Icons.error_outline,
                              color: isConnected ? Colors.green : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                relay['url'] as String,
                                style: TextStyle(
                                  color: isConnected ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (relay['active'] as bool) ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: (relay['active'] as bool) ? Colors.blue : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          )
              : const SizedBox.shrink();

          Widget rideContent;
          if (nostrService.connectionState == NostrConnectionState.disconnected && !ridesProvider.isLoading) {
            rideContent = Center(
              child: FadeIn(
                duration: const Duration(milliseconds: 300),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.signal_wifi_off, color: Colors.orange, size: 50),
                        const SizedBox(height: 16),
                        const Text(
                          'Not connected to Nostr relays.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connected to ${nostrService.connectedRelayCount}/${nostrService.totalRelayCount} relays.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          onPressed: () => nostrService.init(),
                          child: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          } else if (nostrService.connectionState == NostrConnectionState.reconnecting) {
            rideContent = Center(
              child: FadeIn(
                duration: const Duration(milliseconds: 300),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blueAccent),
                    SizedBox(height: 10),
                    Text("Reconnecting to Nostr relays...", style: TextStyle(color: Colors.blueAccent)),
                  ],
                ),
              ),
            );
          } else if (ridesProvider.isLoading && ridesProvider.myRides.isEmpty) {
            rideContent = Center(
              child: FadeIn(
                duration: const Duration(milliseconds: 300),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.blueAccent),
                    SizedBox(height: 10),
                    Text("Loading your rides...", style: TextStyle(color: Colors.blueAccent)),
                  ],
                ),
              ),
            );
          } else if (ridesProvider.error != null) {
            rideContent = Center(
              child: FadeIn(
                duration: const Duration(milliseconds: 300),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${ridesProvider.error}',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => ridesProvider.fetchMyRides(forceRefresh: true),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          } else {
            rideContent = Expanded(
              child: ridesProvider.myRides.isEmpty
                  ? const Center(child: Text("You haven't posted any rides yet."))
                  : RefreshIndicator(
                onRefresh: () async {
                  await ridesProvider.fetchMyRides(forceRefresh: true);
                },
                child: ListView.builder(
                  itemCount: ridesProvider.myRides.length,
                  itemBuilder: (context, index) {
                    final ride = ridesProvider.myRides[index];
                    return MyRideListItem(ride: ride);
                  },
                ),
              ),
            );
          }

          return Column(
            children: [
              loggedInSection,
              rideContent,
            ],
          );
        },
      ),
    );
  }
}

class MyRideListItem extends StatelessWidget {
  final RideItemModel ride;

  const MyRideListItem({required this.ride, super.key});

  Future<bool> _showConfirmationDialog(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(title, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MyRidesProvider>();

    String formattedDepartureTime = 'Time Unknown';
    try {
      if (ride.originTimezone != null && ride.originTimezone != 'UTC') {
        final location = tz.getLocation(ride.originTimezone!);
        final localizedDt = tz.TZDateTime.from(ride.departureTimeUtc, location);
        formattedDepartureTime = DateFormat('MMM d y, hh:mm a z').format(localizedDt);
      } else {
        formattedDepartureTime = '${DateFormat.yMd().add_jm().format(ride.departureTimeUtc)} (UTC)';
      }
    } catch (e) {
      debugPrint("Error formatting time for ride ${ride.id}: $e");
      formattedDepartureTime = 'Invalid Date';
    }

    String formattedPrice = '';
    if (ride.priceAmount != null && ride.priceAmount != '0') {
      String currency = ride.priceCurrency ?? '';
      String amount = ride.priceAmount!;
      if (currency == 'USD') currency = '\$';
      else if (currency == 'EUR') currency = '€';
      else if (currency == 'GBP') currency = '£';
      else if (currency == 'SATS') currency = ' sats';
      else currency = ' $currency';
      formattedPrice = currency == ' sats' || currency.startsWith(' ') ? '$amount$currency' : '$currency$amount';
      formattedPrice = ' - $formattedPrice';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: ride.status != RideStatus.active ? Colors.grey[200] : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ride.status == RideStatus.active ? Colors.green : Colors.grey,
          child: Icon(
            ride.type == RideType.offer ? Icons.drive_eta : ride.type == RideType.partner ? Icons.people_alt_outlined : Icons.hail,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '${ride.origin.displayName} to ${ride.destination.displayName}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: ride.status != RideStatus.active ? TextDecoration.lineThrough : null,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${ride.status.name.toUpperCase()}'),
            Text('Departs: $formattedDepartureTime$formattedPrice'),
            if (ride.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  ride.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (String result) async {
            bool confirm = false;
            if (result == 'sold') {
              confirm = await _showConfirmationDialog(context, 'Mark as Sold', 'Mark this ride as filled/sold?');
              if (confirm) {
                final success = await provider.markRideSold(ride);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Ride marked as sold.' : 'Failed to mark ride as sold.')),
                  );
                }
              }
            } else if (result == 'edit') {
              confirm = await _showConfirmationDialog(context, 'Edit Ride', 'Edit this ride’s details?');
              if (confirm) {
                final success = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostRideScreen(rideToEdit: ride),
                  ),
                );
                if (context.mounted && success != true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to edit ride.')),
                  );
                }
              }
            } else if (result == 'delete') {
              confirm = await _showConfirmationDialog(context, 'Delete Ride', 'Permanently delete this ride posting?');
              if (confirm) {
                final success = await provider.deleteRide(ride);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Ride deleted.' : 'Failed to delete ride.')),
                  );
                }
              }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            if (ride.status == RideStatus.active)
              const PopupMenuItem<String>(
                value: 'sold',
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline, color: Colors.green),
                  title: Text('Mark as Sold'),
                ),
              ),
            if (ride.status == RideStatus.active)
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit, color: Colors.blue),
                  title: Text('Edit'),
                ),
              ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text('Delete'),
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
        isThreeLine: ride.description.isNotEmpty,
      ),
    );
  }
}