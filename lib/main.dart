import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz; // Import timezone data
import 'src/core/services/auth_service.dart';
import 'src/core/services/nostr_service.dart';
import 'src/features/feed/presentation/providers/feed_provider.dart';
import 'src/features/my_rides/presentation/providers/my_rides_provider.dart';

import 'app.dart'; // We will create this next
// Import necessary providers later (e.g., AuthProvider, NostrServiceProvider)

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize timezone database (required by the timezone package)
  tz.initializeTimeZones();

  // Initialize services
  final nostrService = NostrService();
  nostrService.init();

  final authService = AuthService();
  await authService.loadKey(nostrService: nostrService);

  runApp(
    // MultiProvider will wrap the app with all necessary state providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<NostrService>.value(value: nostrService),
        ChangeNotifierProxyProvider<NostrService, FeedProvider>(
          create: (context) => FeedProvider(nostrService), // Initial create
          update: (context, nostrServiceInstance, previousFeedProvider) {
            // This 'update' is called when NostrService notifies listeners,
            // but FeedProvider itself manages listening via its constructor/listener.
            // We usually return the existing provider instance unless we need
            // to pass updated values from the dependency.
            // In this simple case, returning the existing one is fine.
            return previousFeedProvider ?? FeedProvider(nostrServiceInstance);
          },
        ),
        ChangeNotifierProxyProvider2<AuthService, NostrService, MyRidesProvider>(
          // Note: ProxyProvider2 because it depends on two others
            create: (context) => MyRidesProvider(authService, nostrService),
            update: (context, auth, nostr, previous) {
              // The provider manages its own updates based on auth listener
              return previous ?? MyRidesProvider(auth, nostr);
            }
        ),
      ],
      child: const RidesharesApp(),
    ),
  );
}