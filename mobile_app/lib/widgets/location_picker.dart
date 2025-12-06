import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class LocationPicker extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double? initialAccuracy;

  const LocationPicker({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialAccuracy,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLatitude,
      widget.initialLongitude,
    );
    
    // Listen to map movement to update selected location when panning
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove) {
        setState(() {
          _selectedLocation = event.camera.center;
        });
      }
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _mapController.move(location, _mapController.camera.zoom);
  }

  Future<void> _getCurrentLocation() async {
    if (kIsWeb) {
      // Web doesn't support geolocator the same way
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are not available on web.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled. Please enable them.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied.'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _selectedLocation = newLocation;
        });
        _mapController.move(newLocation, 15);
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Location',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap on the map or use current location',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Map
            Expanded(
              child: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      try {
                        return FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation,
                            initialZoom: 15.0,
                            onTap: _onMapTap,
                            minZoom: 3.0,
                            maxZoom: 18.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.utkars_agent',
                              maxZoom: 19,
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedLocation,
                                  width: 48,
                                  height: 48,
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 48,
                                    color: AppTheme.errorColor,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } catch (e) {
                        print('Error initializing map: $e');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load map',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please check your internet connection',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  // Current location button
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: _isLoading ? null : _getCurrentLocation,
                      backgroundColor: theme.colorScheme.surface,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                  // Zoom controls
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          onPressed: () {
                            final currentZoom = _mapController.camera.zoom;
                            _mapController.move(_selectedLocation, currentZoom + 1);
                          },
                          backgroundColor: theme.colorScheme.surface,
                          heroTag: 'zoom_in',
                          child: const Icon(Icons.add_rounded),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          onPressed: () {
                            final currentZoom = _mapController.camera.zoom;
                            _mapController.move(_selectedLocation, currentZoom - 1);
                          },
                          backgroundColor: theme.colorScheme.surface,
                          heroTag: 'zoom_out',
                          child: const Icon(Icons.remove_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Coordinates display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoordinateDisplay(
                          context,
                          'Latitude',
                          _selectedLocation.latitude.toStringAsFixed(6),
                          Icons.north_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCoordinateDisplay(
                          context,
                          'Longitude',
                          _selectedLocation.longitude.toStringAsFixed(6),
                          Icons.east_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.cancel_rounded),
                          label: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop({
                              'latitude': _selectedLocation.latitude,
                              'longitude': _selectedLocation.longitude,
                            });
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Confirm Location'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateDisplay(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
