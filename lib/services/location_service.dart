import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save delivery route
  Future<void> saveDeliveryRoute(List<LatLng> routePoints) async {
    if (_auth.currentUser == null) {
      debugPrint('Cannot save route: No user logged in');
      return;
    }

    debugPrint('Saving route for user: ${_auth.currentUser?.uid}');
    debugPrint('Number of points in route: ${routePoints.length}');

    final route = {
      'userId': _auth.currentUser!.uid,
      'timestamp': Timestamp.now(),
      'reimbursed': false,
      'points': routePoints.map((point) => {
            'latitude': point.latitude,
            'longitude': point.longitude,
          }).toList(),
    };

    try {
      final docRef = await _firestore.collection('routes').add(route);
      debugPrint('Route saved successfully with ID: ${docRef.id}');
    } catch (e) {
      debugPrint('Error saving route: $e');
      rethrow;
    }
  }

  // Get delivery routes for current user
  Stream<QuerySnapshot> getUserRoutes() {
    if (_auth.currentUser == null) {
      throw Exception('No user logged in');
    }

    try {
      // Using only where clause without orderBy to avoid index requirement
      return _firestore
          .collection('routes')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .snapshots();
    } catch (e) {
      debugPrint('Error getting user routes: $e');
      rethrow;
    }
  }

  // Get specific route by ID
  Future<List<LatLng>> getRouteById(String routeId) async {
    final doc = await _firestore.collection('routes').doc(routeId).get();
    if (!doc.exists) {
      throw Exception('Route not found');
    }

    final data = doc.data() as Map<String, dynamic>;
    final points = (data['points'] as List).map((point) {
      return LatLng(
        point['latitude'] as double,
        point['longitude'] as double,
      );
    }).toList();

    return points;
  }

  // Calculate total distance for reimbursement
  Future<double> calculateRouteDistance(String routeId) async {
    final points = await getRouteById(routeId);
    double totalDistance = 0;

    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _calculateDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }

    return totalDistance;
  }

  // Helper method to calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the earth in km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distance in km
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }
} 