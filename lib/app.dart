import 'package:flutter/material.dart';
import 'package:rideshares_app/src/features/feed/presentation/screens/feed_screen.dart';

class RidesharesApp extends StatelessWidget {
  const RidesharesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rideshares.org (NOSTR)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          accentColor: const Color(0xFF42A5F5),
        ).copyWith(
          secondary: const Color(0xFF4CAF50),
          tertiary: const Color(0xFFFF9800),
          background: const Color(0xFFF5F5F5),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1976D2),
            side: const BorderSide(color: Color(0xFF1976D2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(8.0),
        ),
        textTheme: TextTheme(
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.grey[600]),
          bodySmall: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blueGrey,
          accentColor: const Color(0xFF42A5F5),
        ).copyWith(
          secondary: const Color(0xFF4CAF50),
          tertiary: const Color(0xFFFF9800),
          surface: const Color(0xFF303030),
          onSurface: Colors.white, // Ensure text contrasts with background
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1976D2),
            side: const BorderSide(color: Color(0xFF1976D2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(8.0),
          color: Color(0xFF424242), // Slightly lighter card for contrast
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.normal, color: Colors.white),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
          bodySmall: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          filled: true,
          fillColor: Color(0xFF424242),
        ),
      ),
      themeMode: ThemeMode.system,

      home: const FeedScreen(),

      // TODO: Set up routes for navigation later if needed
      // routes: {
      //   '/feed': (context) => FeedScreen(),
      //   '/post': (context) => PostRideScreen(),
      // },
    );
  }
}