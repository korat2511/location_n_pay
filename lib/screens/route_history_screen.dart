import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import 'route_viewer_screen.dart';

class RouteHistoryScreen extends StatefulWidget {
  const RouteHistoryScreen({super.key});

  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  final LocationService _locationService = LocationService();
  final SettingsService _settingsService = SettingsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('routes')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data?.docs ?? [];

          if (routes.isEmpty) {
            return const Center(child: Text('No routes found'));
          }

          return ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              final timestamp = route['timestamp'] as Timestamp;
              final isReimbursed = route['reimbursed'] as bool? ?? false;
              final reimbursementStatus = route['reimbursement_status'] as String? ?? '';

              return FutureBuilder<double>(
                future: _locationService.calculateRouteDistance(route.id),
                builder: (context, distanceSnapshot) {
                  final distance = distanceSnapshot.data ?? 0.0;
                  return FutureBuilder<double>(
                    future: _settingsService.getPricePerKm(),
                    builder: (context, priceSnapshot) {
                      final pricePerKm = priceSnapshot.data ?? 0.5;
                      final reimbursement = distance * pricePerKm;

                      return ListTile(
                        title: Text('Route ${index + 1}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${_formatDate(timestamp)}'),
                            Text('Distance: ${distance.toStringAsFixed(2)} km'),
                            Text('Reimbursement: \$${reimbursement.toStringAsFixed(2)}'),
                            if (isReimbursed)
                              Text(
                                'Status: $reimbursementStatus',
                                style: TextStyle(
                                  color: reimbursementStatus == 'Approved'
                                      ? Colors.green
                                      : reimbursementStatus == 'Partially Approved'
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RouteViewerScreen(
                                  routeId: route.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 