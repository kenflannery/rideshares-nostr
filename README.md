This README aims to welcome users and developers, explain the project, detail the NOSTR protocol being used, and make it easy for others to run or contribute.

# Rideshares.org (NOSTR)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter/NOSTR based ridesharing proof-of-concept and protocol proposal.

## Overview

**Rideshares.org** is an experimental, open-source ridesharing application built on the decentralized NOSTR protocol. Created by techie backpackers, the primary goal is not just to build an app, but to **establish a standard rideshare protocol on NOSTR (using NIP-99) that other clients and communities can adopt.**

We believe decentralized protocols like NOSTR are well-suited for connecting people for shared rides without relying on centralized platforms. Rides posted via this app (or other compatible apps like Hitchwiki, Trustroots, Trip Hopping [coming soon]) will be visible across all participating clients, creating a wider, censorship-resistant network for travelers.

**The vibes are good! Join the movement!**

## Features (Current)

*   **View Rides:** Browse ride offers and requests.
    *   Filter by **Nearby** location (using device GPS).
    *   Filter by **Global** feed.
    *   Filter by **Searching** a specific location.
    *   Toggle between **List View** and **Map View** (showing ride origins).
*   **Post Rides:** Offer or request rides using a simple form.
    *   Select Origin/Destination via an interactive map.
    *   Specify Departure Date/Time (including origin timezone).
    *   Add a description.
    *   Set an optional price (defaults to free/cost-share).
*   **Manage Rides:** View your own posted rides.
    *   Mark rides as "Sold" (Filled).
    *   Delete ride posts (using NIP-09).
*   **NOSTR Integration:** Uses NOSTR Kind 30402 (NIP-99 Classifieds) with specific tags for rideshare data.
*   **Cross-Platform:** Built with Flutter, targeting Web, Android, and iOS.

## Getting Started (Users)

1.  **Web App:** Access the deployed web app at [https://rideshares.org](https://rideshares.org)
2.  **Browse:** View rides immediately. Use the "Nearby", "Global", and Search options.
3.  **Post/Manage:** To post or manage your rides, you'll need a NOSTR identity.
    *   **Generate:** The app can generate a new key pair for you. **IMPORTANT: Backup the private key (nsec) shown securely offline! It cannot be recovered.**
    *   **Import:** You can import your existing NOSTR private key (nsec).
    *   *(NIP-07 browser extension support planned for web)*

## Getting Started (Developers)

### Prerequisites

*   **Flutter SDK:** Ensure you have the Flutter SDK installed. See [Flutter Docs](https://docs.flutter.dev/get-started/install).
*   **IDE:** Android Studio (with Flutter plugin) or Visual Studio Code (with Flutter extension).
*   **Git:** For cloning the repository.

### Running Locally

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/kenflannery/rideshares-nostr.git
    cd rideshares-nostr
    ```
2.  **Get Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the App:**
    *   **Web:** `flutter run -d chrome`
    *   **Android:** Connect an Android device or emulator and run `flutter run`.
    *   **iOS:** On macOS with Xcode setup, connect an iOS device or simulator and run `flutter run`.

### Code Structure

This project uses a **feature-first** clean architecture approach with the `provider` package for state management.

*   `lib/src/core`: Shared utilities, models, constants, base classes, services (Auth, Nostr).
*   `lib/src/data`: Data layer interfaces (repositories) and implementations (Nostr sources).
*   `lib/src/features`: Individual feature modules (e.g., `feed`, `post_ride`, `my_rides`, `auth`, `ride_detail`). Each feature typically contains `presentation` (screens, providers, widgets), `domain` (use cases - *optional for smaller features*), and potentially `data` sub-folders.

## NOSTR Rideshare Protocol (NIP-99 Adaptation)

This app uses **Kind 30402** (NIP-99 Classifieds) to represent ride offers and requests. We aim for maximum compatibility with standard NIP-99 clients while adding specific tags crucial for ridesharing functionality.

**Goal:** Enable any NOSTR client to parse and display rideshare information effectively.

**Tag Structure:**

| Tag           | Value Type             | Required? | Purpose & Notes                                            | NIP-99 Standard? |
|---------------|------------------------|-----------|------------------------------------------------------------|-----------------|
| `d`           | String (UUID rec.)     | **Yes**   | Unique identifier for the specific ride listing/request. Prevents duplicates, enables updates/deletion. | Yes             |
| `title`       | String                 | Yes       | Human-readable title, e.g., "Rideshare offer from London to Paris". | Yes             |
| `content`     | String (Markdown)      | Yes       | Full description: seats, luggage, route details, cost-sharing info, contact preferences, etc. Includes formatted departure details for readability. | Yes             |
| `published_at`| String (Unix TS Secs) | **Yes**   | Timestamp of the *initial* publication of this listing (`d` tag). Retained during edits/status updates. | Yes             |
| `t`           | String                 | **Yes**   | At least `rideshare`. Also `ride-offer` or `ride-request`. Optionally `rideshares.org` or other relevant keywords. | Yes             |
| `location`    | String                 | Yes       | Human-readable **origin** location name.                   | Yes             |
| `price`       | `[amount, currency]`   | Yes       | Price array. `amount`= "0" signifies Free/Cost-Share/Negotiable. Currency uses ISO 4217 or common crypto codes (BTC, SATS). E.g., `["50", "USD"]`, `["10000", "SATS"]`. Optional 3rd element for frequency (e.g., "day") not currently used by this app. | Yes             |
| `status`      | String ("active"/"sold")| Yes       | Initial status is "active". Updated by re-posting with same `d` tag and new status. | Yes             |
| `g`           | String (Geohash Prefix)| Yes       | Cascading **origin** geohash (rec. up to len 6) for area filtering. | Yes             |
| `dg`          | String (Geohash Prefix)| **Yes**   | **Custom:** Cascading **destination** geohash (rec. up to len 6) for area filtering. | No              |
| `location_dest` | String                 | **Yes**   | **Custom:** Human-readable **destination** location name.    | No              |
| `origin_lat`  | String (Float)         | **Yes**   | **Custom:** **Origin** latitude for precise mapping.         | No              |
| `origin_lon`  | String (Float)         | **Yes**   | **Custom:** **Origin** longitude for precise mapping.        | No              |
| `dest_lat`    | String (Float)         | **Yes**   | **Custom:** **Destination** latitude for precise mapping.    | No              |
| `dest_lon`    | String (Float)         | **Yes**   | **Custom:** **Destination** longitude for precise mapping.   | No              |
| `departure_utc`| String (Unix TS Secs) | **Yes**   | **Custom:** **Departure** time as UTC timestamp (seconds). | No              |
| `origin_tz`   | String (IANA TZ ID)    | **Yes**   | **Custom:** IANA Timezone ID of the origin (e.g., "America/New_York") for accurate local time display. | No              |
| `summary`     | String                 | Optional  | Short summary/tagline (NIP-99 standard).                   | Yes             |
| `image`       | String (URL)           | Optional  | Image URL (NIP-99 standard). Could be user photo, car, map snippet. | Yes             |

**Rationale for Custom Tags:**

*   `dg`, `location_dest`, `dest_lat`, `dest_lon`: Provide structured data for the destination, essential for filtering and mapping.
*   `origin_lat`, `origin_lon`: Provide precise origin coordinates beyond geohashes for accurate mapping.
*   `departure_utc`, `origin_tz`: Provide unambiguous, machine-readable time information critical for scheduling rides.

**Updating/Deleting Rides:**

*   **Status Updates (e.g., "Sold"):** Re-publish a Kind 30402 event with the **exact same `d` tag** and the **original `published_at` tag**, but with the `status` tag changed to "sold". The event with the latest `created_at` timestamp determines the current state. (Minimal update events are possible but re-publishing full data is simpler for clients).
*   **Edits:** Re-publish a Kind 30402 event with the **exact same `d` tag** and the **original `published_at` tag**, but with updated `content` and any other changed tags. The latest `created_at` wins.
*   **Deletion:** Publish a standard Kind 5 (NIP-09) deletion event tagging (`e` tag) the *event ID* of the specific Kind 30402 event(s) to be deleted.

**Example Event:**

```json
{
  "kind": 30402,
  "created_at": 1715000000, // Timestamp of THIS event object
  "content": "Offering a ride London to Paris. 2 seats available. Sharing gas cost.\n\nType: offer\nDeparture: May 06 2025, 10:00 AM BST\nOrigin: Central London\nDestination: Central Paris\nNOTE: This ride was posted via Rideshares.org.",
  "tags": [
    ["d", "london-paris-20250506-a1b2"], // Unique ID
    ["title", "Rideshare offer from London to Paris"],
    ["published_at", "1715000000"], // Timestamp of first publication
    ["t", "rideshare"],
    ["t", "ride-offer"],
    ["t", "rideshares.org"],
    ["g", "g"], ["g", "gc"], ["g", "gcp"], ["g", "gcpv"], ["g", "gcpvj"], ["g", "gcpvj0"], // Origin geohash
    ["dg", "u"], ["dg", "u0"], ["dg", "u09"], ["dg", "u09t"], ["dg", "u09t S"], ["dg", "u09t S1"], // Dest geohash
    ["location", "Central London"],
    ["price", "30", "EUR"], // Example price
    ["status", "active"],
    ["location_dest", "Central Paris"],
    ["origin_lat", "51.5074"],
    ["origin_lon", "-0.1278"],
    ["dest_lat", "48.8566"],
    ["dest_lon", "2.3522"],
    ["departure_utc", "1746522000"], // Example timestamp for May 6 2025 09:00 UTC (BST is UTC+1)
    ["origin_tz", "Europe/London"]
  ],
  "pubkey": "...",
  "id": "...", // ID of this specific event
  "sig": "..."
}
```


## Contributing

Contributions are welcome! Please feel free to submit Pull Requests or open Issues for bugs, feature requests, or protocol suggestions.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

Developer: Kenny Flannery

Nostr: npub192mfhkcm2jnunx80mdje36chk4k3hfe3jy4k4nwgmh3rhmr7y2asn5g2ff

Twitter: @HoboLifestyle

Project Website: rideshares.org (when live)
