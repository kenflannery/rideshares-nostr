import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz; // Import timezone data
import 'src/core/services/auth_service.dart';
import 'src/core/services/nostr_service.dart';
import 'src/core/services/update_checker_service.dart';
import 'src/features/feed/presentation/providers/feed_provider.dart';
import 'src/features/my_rides/presentation/providers/my_rides_provider.dart';

import 'app.dart';

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

  final updateCheckerService = UpdateCheckerService();
  // Trigger non-blocking update check
  updateCheckerService.checkForUpdates().catchError((_) => AppUpdateInfo.upToDate(currentVersion: '1.0.0'));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<NostrService>.value(value: nostrService),
        ChangeNotifierProvider<UpdateCheckerService>.value(value: updateCheckerService),
        ChangeNotifierProxyProvider<NostrService, FeedProvider>(
          create: (context) => FeedProvider(nostrService),
          update: (context, nostrServiceInstance, previousFeedProvider) {
            return previousFeedProvider ?? FeedProvider(nostrServiceInstance);
          },
        ),
        ChangeNotifierProxyProvider2<AuthService, NostrService, MyRidesProvider>(
          create: (context) => MyRidesProvider(authService, nostrService),
          update: (context, auth, nostr, previous) {
            return previous ?? MyRidesProvider(auth, nostr);
          },
        ),
      ],
      child: const RidesharesApp(),
    ),
  );
}