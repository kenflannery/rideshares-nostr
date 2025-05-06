import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/models/ride_item_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/nostr_service.dart';
import '../../../ride_detail/presentation/screens/ride_details_screen.dart';
import '../providers/post_ride_provider.dart';
import '../../../location_picker/presentation/screens/location_picker_screen.dart';

class PostRideScreen extends StatelessWidget {
  final RideItemModel? rideToEdit;

  const PostRideScreen({super.key, this.rideToEdit});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PostRideProvider(
        context.read<AuthService>(),
        context.read<NostrService>(),
        rideToEdit: rideToEdit,
      ),
      child: Consumer2<NostrService, PostRideProvider>(
        builder: (context, nostrService, provider, child) {
          if (provider.successMessage != null) {
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) {
                provider.clearSuccessMessage();
              }
            });
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(provider.isEditing ? 'Edit Ride' : 'Post a Ride'),
            ),
            body: nostrService.connectionState == NostrConnectionState.disconnected
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.signal_wifi_off, color: Colors.orange, size: 50),
                    const SizedBox(height: 16),
                    const Text('Not connected to Nostr relays.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('Connected to ${nostrService.connectedRelayCount}/${nostrService.totalRelayCount} relays.', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: () => nostrService.init(), child: const Text('Retry Connection')),
                  ],
                ),
              ),
            )
                : nostrService.connectionState == NostrConnectionState.reconnecting
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Reconnecting to Nostr relays...")]))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRideTypeSelector(context, provider),
                  const SizedBox(height: 20),
                  _buildLocationSelector(
                    context: context,
                    label: 'Origin',
                    location: provider.origin,
                    onLocationSelected: (selectedLocation) {
                      if (selectedLocation != null) {
                        provider.setOrigin(selectedLocation);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLocationSelector(
                    context: context,
                    label: 'Destination',
                    location: provider.destination,
                    onLocationSelected: (selectedLocation) {
                      if (selectedLocation != null) {
                        provider.setDestination(selectedLocation);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDateTimePicker(context, provider),
                  const SizedBox(height: 16),
                  TextField(
                    controller: provider.descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g., Number of seats, luggage space, route details, cost sharing...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),
                  _buildPriceInput(context, provider),
                  const SizedBox(height: 24),
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (provider.successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        provider.successMessage!,
                        style: const TextStyle(color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: provider.isLoading || nostrService.connectionState != NostrConnectionState.connected
                        ? null
                        : () async {
                      final rideItem = await provider.submitRide();
                      if (context.mounted && rideItem != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideDetailsScreen(ride: rideItem),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(provider.isEditing ? 'Update Ride' : 'Post Ride to Nostr'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceInput(BuildContext context, PostRideProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: provider.priceController,
            decoration: const InputDecoration(
              labelText: 'Price (Optional)',
              hintText: '0',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final parsed = double.tryParse(value);
                if (parsed == null || parsed < 0) {
                  return 'Enter a valid number';
                }
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: provider.selectedCurrency,
            items: provider.currencies.map((String currency) {
              return DropdownMenuItem<String>(
                value: currency,
                child: Text(currency),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                provider.setCurrency(newValue);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRideTypeSelector(BuildContext context, PostRideProvider provider) {
    return SegmentedButton<RideType>(
      segments: const <ButtonSegment<RideType>>[
        ButtonSegment<RideType>(
          value: RideType.offer,
          label: Text('Offering Ride'),
          icon: Icon(Icons.drive_eta),
        ),
        ButtonSegment<RideType>(
          value: RideType.request,
          label: Text('Requesting Ride'),
          icon: Icon(Icons.hail),
        ),
      ],
      selected: <RideType>{provider.rideType},
      onSelectionChanged: (Set<RideType> newSelection) {
        provider.setRideType(newSelection.first);
      },
      style: SegmentedButton.styleFrom(visualDensity: VisualDensity.standard),
    );
  }

  Widget _buildLocationSelector({
    required BuildContext context,
    required String label,
    required Function(LocationModel?) onLocationSelected,
    required LocationModel? location,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.location_on),
          label: Text(location?.displayName ?? 'Select $label Location', overflow: TextOverflow.ellipsis),
          onPressed: () async {
            final result = await Navigator.push<LocationModel?>(
              context,
              MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
            );
            if (result != null) {
              onLocationSelected(result);
            }
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            alignment: Alignment.centerLeft,
            foregroundColor: location != null ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker(BuildContext context, PostRideProvider provider) {
    final dateFormat = DateFormat.yMd();
    final timeFormat = DateFormat.jm();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(provider.departureDate == null ? 'Select Date' : dateFormat.format(provider.departureDate!)),
            onPressed: () async {
              final now = DateTime.now();
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: provider.departureDate ?? now,
                firstDate: now.subtract(const Duration(days: 1)),
                lastDate: now.add(const Duration(days: 365)),
              );
              if (pickedDate != null) {
                provider.setDepartureDate(pickedDate);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: provider.departureDate != null ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(provider.departureTime == null
                ? 'Select Time'
                : timeFormat.format(DateTime(2000, 1, 1, provider.departureTime!.hour, provider.departureTime!.minute))),
            onPressed: () async {
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: provider.departureTime ?? TimeOfDay.now(),
              );
              if (pickedTime != null) {
                provider.setDepartureTime(pickedTime);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: provider.departureTime != null ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}