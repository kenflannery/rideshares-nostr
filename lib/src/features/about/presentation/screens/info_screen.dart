import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart'; // For fade-in animation

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('About Rideshares', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with animated fade-in
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rideshares.org',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Decentralized Ridesharing Platform',
                        style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Vibes info
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'The vibes are good',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text('This app has been created by techie backpackers to establish a rideshare protocol for NOSTR that anyone can adopt. Hitchwiki, Trustroots, and Trip Hopping have or will soon be compatible, and we hope to see more apps join the movement. Rides posted here, or there, will be visible in all apps that support this protocol.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Contact Info
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const Text('Nostr Pubkey: npub192mfhkcm2jnunx80mdje36chk4k3hfe3jy4k4nwgmh3rhmr7y2asn5g2ff'),
                        //const Text('NIP-05: rideshares@yourdomain.com'),
                        const Text('Twitter: @HoboLifestyle'),
                        //const Text('Email: support@rideshares.org'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // NIP-99 Explanation
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
                      const Text(
                        'NIP-99 Structure & Rationale',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This app adapts NIP-99 (kind 30402) for ridesharing events, building on its classified listing framework. NIP-99 provides a flexible structure for metadata, which we extend with custom tags to support ride-specific data. Below is the tag structure:',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Table(
                        border: TableBorder.all(color: Colors.grey),
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(3),
                        },
                        children: [
                          const TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Tag', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Value', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          // NIP-99 Standard Tags
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('title')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('String')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Title of the ride listing')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('published_at')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Unix timestamp')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Publication timestamp')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('location')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('String')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Human-readable origin location')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('price')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('[amount, currency]')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Price in ISO 4217 format, e.g., ["50", "USD"]')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('status')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('active/sold')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Listing status')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('t')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('rideshare, etc.')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Categories or keywords')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('g')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Geohash prefix')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Cascading origin geohash for location filtering')),
                            ],
                          ),
                          // Custom Rideshare Tags
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('dg')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Geohash prefix')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Cascading destination geohash for filtering')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('location_dest')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('String')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Human-readable destination')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('origin_lat')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Float')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Origin latitude for mapping')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('origin_lon')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Float')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Origin longitude for mapping')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('dest_lat')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Float')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Destination latitude for mapping')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('dest_lon')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Float')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Destination longitude for mapping')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('departure_utc')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Unix timestamp')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Departure time in UTC')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('origin_tz')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Timezone ID')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Origin timezone for localization')),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(padding: EdgeInsets.all(8.0), child: Text('d')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('String')),
                              Padding(padding: EdgeInsets.all(8.0), child: Text('Unique identifier for deduplication')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Our adaptation adds rideshare-specific tags (e.g., departure_utc, coordinates) to enhance functionality like mapping and time scheduling. The "d" tag ensures unique ride identification, while geohashes (g, dg) optimize location-based filtering.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sample Event:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        '''
{
  "kind": 30402,
  "created_at": 1715000000,
  "content": "Offering a ride with AC and Wi-Fi\\nType: offer\\nDeparture: May 6 2025, 09:00 AM EDT\\nOrigin: New York\\nDestination: Boston\\nNOTE: This ride was posted via Rideshares.org.",
  "tags": [
    ["d", "ride-ny-to-bos-20250506"],
    ["title", "Rideshare offer from New York to Boston"],
    ["published_at", "1715000000"],
    ["t", "rideshare"],
    ["t", "ride-offer"],
    [
      "g",
      "u"
    ],
    [
      "g",
      "u0"
    ],
    [
      "g",
      "u0n"
    ],
    [
      "g",
      "u0n7"
    ],
    [
      "g",
      "u0n7y"
    ],
    [
      "g",
      "u0n7y1"
    ],
    [
      "dg",
      "g"
    ],
    [
      "dg",
      "gc"
    ],
    [
      "dg",
      "gcp"
    ],
    [
      "dg",
      "gcpf"
    ],
    [
      "dg",
      "gcpfy"
    ],
    [
      "dg",
      "gcpfym"
    ],
    ["location", "New York"],
    ["price", "50", "USD"],
    ["status", "active"],
    ["location_dest", "Boston"],
    ["origin_lat", "40.7128"],
    ["origin_lon", "-74.0060"],
    ["dest_lat", "42.3601"],
    ["dest_lon", "-71.0589"],
    ["departure_utc", "1715001600"],
    ["origin_tz", "America/New_York"]
  ],
  "pubkey": "...",
  "id": "..."
}''',
                        style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Call to Action
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Join the Movement!',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'We encourage developers to adopt this NIP-99 structure for seamless ridesharing interoperability. Contribute or build your own!',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1976D2), foregroundColor: Colors.white),
                        onPressed: () {
                          // Placeholder for action (e.g., open GitHub or email)
                        },
                        child: const Text('Get Involved'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Additional Info
            FadeInUp(
              duration: const Duration(milliseconds: 900),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'More Details',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text('https://github.com/kenflannery/rideshares-nostr', style: TextStyle(decoration: TextDecoration.underline)),
                      const SizedBox(height: 5),
                      const Text('Tech Stack: Flutter, NOSTR, dart_nostr'),
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
}