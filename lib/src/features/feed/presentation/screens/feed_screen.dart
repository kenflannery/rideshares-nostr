import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart'; // For animations
import '../../../../core/models/ride_item_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/nostr_service.dart';
import '../../../about/presentation/screens/info_screen.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../ride_detail/presentation/screens/ride_details_screen.dart';
import '../providers/feed_provider.dart';
import '../../../post_ride/presentation/screens/post_ride_screen.dart';
import '../../../my_rides/presentation/screens/my_rides_screen.dart';
import '../widgets/ride_list_item.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isMapView = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: Text(
          _getAppBarTitleText(context.watch<FeedProvider>()),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt, color: Colors.white),
            tooltip: 'My Rides',
            onPressed: () {
              if (context.read<AuthService>().isLoggedIn) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRidesScreen()));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to view your rides.')));
              }
            },
          ),
          _buildLogInOrOut(),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'About This App',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen()));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 4),
          child: Card(
            margin: const EdgeInsets.all(0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
            color: Colors.white.withOpacity(0.9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    //spacing: 8,
                    children: [
                      IconButton(
                        icon: Icon(_isMapView ? Icons.list : Icons.map, color: Colors.blueAccent),
                        tooltip: _isMapView ? 'Show List View' : 'Show Map View',
                        onPressed: () {
                          setState(() {
                            _isMapView = !_isMapView;
                          });
                        },
                      ),
                      Consumer<FeedProvider>(
                        builder: (context, provider, child) {
                          return SegmentedButton<FeedMode>(
                            segments: const [
                              ButtonSegment(value: FeedMode.nearby, label: Text('Nearby'), icon: Icon(Icons.location_searching, size: 16)),
                              ButtonSegment(value: FeedMode.global, label: Text('Global'), icon: Icon(Icons.public, size: 16)),
                              ButtonSegment(value: FeedMode.search, label: Text('Search'), icon: Icon(Icons.search, size: 16)),
                            ],
                            selected: {provider.currentMode},
                            onSelectionChanged: (newSelection) {
                              if (provider.isLoading) return;
                              final mode = newSelection.first;
                              if (mode == FeedMode.nearby) provider.switchToNearbyMode();
                              if (mode == FeedMode.global) provider.switchToGlobalMode();
                              if (mode == FeedMode.search) _showSearchDialog(context);
                            },
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.blueAccent,
                              selectedForegroundColor: Colors.white,
                              selectedBackgroundColor: Colors.blueAccent,
                            ),
                            showSelectedIcon: false,
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Consumer<FeedProvider>(
                        builder: (context, feedProvider, child) {
                          return IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            tooltip: 'Refresh',
                            onPressed: feedProvider.isLoading ? null : () => feedProvider.requestDeviceLocationAndFetch(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueAccent,
                              side: BorderSide(color: Colors.blueAccent),
                              disabledForegroundColor: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _isMapView ? _buildMapView(context) : _buildListView(context),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final authService = context.read<AuthService>();
          if (authService.isLoggedIn) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRideScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())).then((_) {
              if (context.read<AuthService>().isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login successful! Tap Post Ride again.')));
              }
            });
          }
        },
        tooltip: 'Post a Ride',
        elevation: 6,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  String _getAppBarTitleText(FeedProvider provider) {
    switch (provider.currentMode) {
      case FeedMode.nearby:
        return 'Rides Nearby';
      case FeedMode.global:
        return 'Global Rides';
      case FeedMode.search:
        return 'Rides near ${provider.searchQuery ?? 'Search'}';
    }
  }

  void _showSearchDialog(BuildContext context) {
    final provider = context.read<FeedProvider>();
    _searchController.text = provider.searchQuery ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search Rides by Location'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter city, address, etc.'),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              provider.searchLocationAndFetch(value.trim());
              Navigator.of(dialogContext).pop();
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final query = _searchController.text.trim();
              if (query.isNotEmpty) {
                provider.searchLocationAndFetch(query);
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogInOrOut() {
    final authService = context.watch<AuthService>();
    if (authService.isLoggedIn) {
      return IconButton(
        icon: const Icon(Icons.logout, color: Colors.white),
        tooltip: 'Logout',
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Logout'),
              content: const Text('Are you sure you want to log out? Your key will be cleared from this device.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            context.read<AuthService>().clearKey();
          }
        },
      );
    } else {
      return IconButton(
        icon: const Icon(Icons.login, color: Colors.white),
        tooltip: 'Login',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
        },
      );
    }
  }

  Widget _buildListView(BuildContext context) {
    return Consumer2<NostrService, FeedProvider>(
      builder: (context, nostrService, feedProvider, child) {
        final feedIsLoading = feedProvider.isLoading;
        final feedError = feedProvider.error;
        final locationError = feedProvider.locationError;
        final isFetchingDeviceLoc = feedProvider.isFetchingDeviceLocation;
        final rides = feedProvider.rides;

        if (nostrService.connectionState == NostrConnectionState.disconnected && !feedIsLoading && !isFetchingDeviceLoc) {
          return Center(
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
                    const Text('Not connected to Nostr relays.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Connected to ${nostrService.connectedRelayCount}/${nostrService.totalRelayCount} relays.', style: Theme.of(context).textTheme.bodySmall),
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
          );
        }

        if (nostrService.connectionState == NostrConnectionState.reconnecting) {
          return Center(
            child: FadeIn(
              duration: Duration(milliseconds: 300),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 10),
                Text("Reconnecting to Nostr relays...", style: TextStyle(color: Colors.blueAccent)),
              ]),
            ),
          );
        }

        if (isFetchingDeviceLoc && feedProvider.currentMode == FeedMode.nearby) {
          return Center(
            child: FadeIn(
              duration: Duration(milliseconds: 300),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 10),
                Text("Getting your location...", style: TextStyle(color: Colors.blueAccent)),
              ]),
            ),
          );
        }

        if (locationError != null && feedProvider.currentMode == FeedMode.nearby) {
          return Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off, color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text('Location Error: $locationError', style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => feedProvider.requestDeviceLocationAndFetch(),
                      child: const Text('Retry Location', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (feedProvider.isSearchingLocation && feedProvider.currentMode == FeedMode.search) {
          return Center(
            child: FadeIn(
              duration: Duration(milliseconds: 300),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 10),
                Text("Searching for ${feedProvider.searchQuery ?? 'location'}...", style: TextStyle(color: Colors.blueAccent)),
              ]),
            ),
          );
        }

        if (feedIsLoading && rides.isEmpty) {
          String loadingText = "Fetching rides from Nostr...";
          if (feedProvider.currentMode == FeedMode.search && feedProvider.searchQuery != null) {
            loadingText = "Fetching rides near ${feedProvider.searchQuery}...";
          } else if (feedProvider.currentMode == FeedMode.nearby && feedProvider.currentDevicePosition != null) {
            loadingText = "Fetching nearby rides...";
          }
          return Center(
            child: FadeIn(
              duration: Duration(milliseconds: 300),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 10),
                Text(loadingText, style: TextStyle(color: Colors.blueAccent)),
              ]),
            ),
          );
        }

        if (feedError != null && rides.isEmpty) {
          return Center(
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
                    Text('Error: $feedError', style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => feedProvider.requestDeviceLocationAndFetch(),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!feedIsLoading && feedError == null && locationError == null && rides.isEmpty) {
          String message = 'No rides available right now.';
          String suggestion = 'Try searching a different location or switch to Global mode.';
          if (feedProvider.currentMode == FeedMode.nearby) {
            message = 'No rides available nearby.';
          } else if (feedProvider.currentMode == FeedMode.search && feedProvider.searchQuery != null) {
            message = 'No rides found near ${feedProvider.searchQuery}.';
          }

          return Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car, color: Colors.blueAccent, size: 50),
                    const SizedBox(height: 16),
                    Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(suggestion, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          onPressed: () => _showSearchDialog(context),
                          child: const Text('Search Elsewhere', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent, side: BorderSide(color: Colors.blueAccent)),
                          onPressed: () => feedProvider.switchToGlobalMode(),
                          child: const Text('Go Global'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await feedProvider.fetchAndListenToRides(position: feedProvider.currentDevicePosition, forceRefresh: true);
          },
          child: ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              return RideListItem(ride: ride);
            },
          ),
        );
      },
    );
  }

  Widget _buildMapView(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feedProvider, child) {
        final activeRidesWithCoords = feedProvider.rides
            .where((ride) => ride.status == RideStatus.active && ride.origin.latitude != 0.0 && ride.origin.longitude != 0.0)
            .toList();

        List<Marker> markers = activeRidesWithCoords.map((ride) {
          return Marker(
            width: 80.0,
            height: 80.0,
            point: LatLng(ride.origin.latitude, ride.origin.longitude),
            child: Tooltip(
              message: '${ride.type == RideType.offer ? "Offer" : "Request"}\nFrom: ${ride.origin.displayName}\nTo: ${ride.destination.displayName}',
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)));
                },
                child: Icon(
                  ride.type == RideType.offer ? Icons.drive_eta : Icons.hail,
                  color: ride.type == RideType.offer ? Colors.green : Colors.orange,
                  size: 30.0,
                ),
              ),
            ),
          );
        }).toList();

        LatLng initialCenter = const LatLng(51.5074, -0.1278);
        if (feedProvider.currentDevicePosition != null) {
          initialCenter = LatLng(feedProvider.currentDevicePosition!.latitude, feedProvider.currentDevicePosition!.longitude);
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 10.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      tileProvider: CancellableNetworkTileProvider(),
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                if (feedProvider.isLoading || feedProvider.isFetchingDeviceLocation)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}