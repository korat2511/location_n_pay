import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  GoogleMapController? _mapController;
  Location location = Location();
  Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];
  bool _isTracking = false;
  final LocationService _locationService = LocationService();
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _initializeBackgroundService();
    _requestLocationPermission();
    _getCurrentLocation();
    _initializeLocationTracking();
  }

  Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: 'Location Tracking',
        initialNotificationContent: 'Tracking your delivery route',
        foregroundServiceNotificationId: 1,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Location Tracking Active",
            content: "Tracking your delivery route",
          );
        }
      }
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isDenied) {
      return;
    }

    if (status.isPermanentlyDenied) {
      openAppSettings();
      return;
    }

    final backgroundStatus = await Permission.locationAlways.request();
    if (backgroundStatus.isDenied) {
      return;
    }

    if (backgroundStatus.isPermanentlyDenied) {
      openAppSettings();
      return;
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      
      setState(() {
        _initialPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        );
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_initialPosition),
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _initializeLocationTracking() {
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (_isTracking && mounted) {
        setState(() {
          _routePoints.add(LatLng(
            currentLocation.latitude!,
            currentLocation.longitude!,
          ));
          _updatePolylines();
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(currentLocation.latitude!, currentLocation.longitude!),
          ),
        );
      }
    });
  }

  void _updatePolylines() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: _routePoints,
          color: Colors.blue,
          width: 5,
        ),
      };
    });
  }

  void _toggleTracking() async {
    setState(() {
      _isTracking = !_isTracking;
      if (!_isTracking && _routePoints.isNotEmpty) {
        _saveRoute();
      } else if (_isTracking) {
        _routePoints.clear();
        _updatePolylines();
      }
    });

    final service = FlutterBackgroundService();
    if (_isTracking) {
      await service.startService();
    } else {
      service.invoke('stopService');
    }
  }

  void _saveRoute() async {
    try {
      await _locationService.saveDeliveryRoute(_routePoints);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving route: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
            mapType: MapType.normal,
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
          ),
          if (_isTracking)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.blue.withOpacity(0.9),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Text(
                    'Recording Route...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleTracking,
        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
        label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
        backgroundColor: _isTracking ? Colors.red : Colors.green,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 