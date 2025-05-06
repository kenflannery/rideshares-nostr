import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../core/models/ride_item_model.dart';
import '../../../ride_detail/presentation/screens/ride_details_screen.dart';

class RideListItem extends StatelessWidget {
  final RideItemModel ride;

  const RideListItem({required this.ride, super.key});

  @override
  Widget build(BuildContext context) {
    String formattedDepartureTime = 'Time Unknown';
    try {
      if (ride.originTimezone != null && ride.originTimezone != 'UTC') {
        final location = tz.getLocation(ride.originTimezone!);
        final localizedDt = tz.TZDateTime.from(ride.departureTimeUtc, location);
        formattedDepartureTime = '${DateFormat("MMM d y, hh:mm a z").format(localizedDt)} (${ride.originTimezone})';
      }
    } catch (e) {
      debugPrint("Error formatting time for ride ${ride.id}: $e");
      formattedDepartureTime = 'Invalid Date';
    }

    String rideTypeText;
    IconData rideTypeIcon;
    Color rideTypeColor;

    switch (ride.type) {
      case RideType.offer:
        rideTypeText = 'Offering Ride';
        rideTypeIcon = Icons.drive_eta;
        rideTypeColor = Colors.green;
        break;
      case RideType.request:
        rideTypeText = 'Requesting Ride';
        rideTypeIcon = Icons.hail;
        rideTypeColor = Colors.blue;
        break;
      default:
        rideTypeText = 'Ride (Unknown Type)';
        rideTypeIcon = Icons.question_mark;
        rideTypeColor = Colors.grey;
    }

    String rideStatusText = ride.status.name.toUpperCase();
    Color statusColor = ride.status == RideStatus.active ? Colors.orange : Colors.grey;

    String formattedPrice = '';
    if (ride.priceAmount != null && ride.priceAmount != "0") {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: rideTypeColor.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsScreen(ride: ride)));
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Leading Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: rideTypeColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: rideTypeColor,
                    child: Icon(rideTypeIcon, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride.origin.displayName} to ${ride.destination.displayName}',
                        /*style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),*/
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Departs: $formattedDepartureTime$formattedPrice',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (ride.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          ride.description,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Trailing Status Chip
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Chip(
                    label: Text(
                      rideStatusText,
                      style: TextStyle(
                        color: statusColor == Colors.orange ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: statusColor.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}