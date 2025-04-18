import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../screens/login_screen.dart';
import 'route_viewer_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final LocationService _locationService = LocationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();
  double _pricePerKm = 0.5;
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPricePerKm();
  }

  Future<void> _loadPricePerKm() async {
    final price = await _settingsService.getPricePerKm();
    setState(() {
      _pricePerKm = price;
      _priceController.text = price.toString();
    });
  }

  Future<void> _updatePricePerKm() async {
    final newPrice = double.tryParse(_priceController.text);
    if (newPrice != null && newPrice > 0) {
      await _settingsService.setPricePerKm(newPrice);
      setState(() {
        _pricePerKm = newPrice;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Price per km updated successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid price')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All Routes'),
              Tab(text: 'Reimbursements'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAllRoutesTab(),
            _buildReimbursementsTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price per Kilometer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price per km',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _updatePricePerKm,
                child: const Text('Update'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Current price: \$${_pricePerKm.toStringAsFixed(2)} per km',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAllRoutesTab() {
    return StreamBuilder<QuerySnapshot>(
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
          return const Center(child: Text('No routes recorded yet'));
        }

        return ListView.builder(
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            final userId = route['userId'] as String? ?? '';
            if (userId.isEmpty) {
              return const ListTile(
                title: Text('Invalid Route'),
                subtitle: Text('Missing user information'),
              );
            }
            // final timestamp = (route['timestamp'] as Timestamp).toDate();

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final userEmail = userData?['email'] as String? ?? 'Unknown User';

                return ExpansionTile(
                  title: Text('Route by $userEmail'),
                  // subtitle: Text('Date: ${_formatDate(timestamp)}'),
                  children: [
                    FutureBuilder<double>(
                      future: _locationService.calculateRouteDistance(route.id),
                      builder: (context, distanceSnapshot) {
                        final distance = distanceSnapshot.data ?? 0.0;
                        final reimbursement = distance * _pricePerKm;

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distance: ${distance.toStringAsFixed(2)} km'),
                              Text(
                                  'Reimbursement: \$${reimbursement.toStringAsFixed(2)}'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      child: ElevatedButton.icon(
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
                                        icon: const Icon(Icons.map),
                                        label: const Text('View Route'),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          _markAsReimbursed(context, route.id);
                                        },
                                        icon: const Icon(Icons.payment),
                                        label: const Text('Reimburse'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReimbursementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('reimbursements')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reimbursements = snapshot.data?.docs ?? [];

        if (reimbursements.isEmpty) {
          return const Center(child: Text('No reimbursements recorded'));
        }

        return ListView.builder(
          itemCount: reimbursements.length,
          itemBuilder: (context, index) {
            final reimbursement = reimbursements[index];
            final amount = double.tryParse(reimbursement['amount'].toString()) ?? 0.0;
            final calculatedAmount = double.tryParse(reimbursement['calculated_amount'].toString()) ?? 0.0;
            final status = reimbursement['status'] as String? ?? 'Approved';
            final userId = reimbursement['userId'] as String? ?? '';
            
            if (userId.isEmpty) {
              return const ListTile(
                title: Text('Invalid Reimbursement'),
                subtitle: Text('Missing user information'),
              );
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final userEmail = userData?['email'] as String? ?? 'Unknown User';

                Color statusColor = Colors.green;
                IconData statusIcon = Icons.check_circle;
                
                if (status == 'Partially Approved') {
                  statusColor = Colors.orange;
                  statusIcon = Icons.warning;
                } else if (status == 'Rejected') {
                  statusColor = Colors.red;
                  statusIcon = Icons.cancel;
                }

                return ListTile(
                  title: Text('Reimbursement to $userEmail'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $status'),
                      Text('Calculated Amount: \$${calculatedAmount.toStringAsFixed(2)}'),
                      Text('Approved Amount: \$${amount.toStringAsFixed(2)}'),
                    ],
                  ),
                  trailing: Icon(statusIcon, color: statusColor),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _markAsReimbursed(BuildContext context, String routeId) async {
    if (routeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid route ID')),
      );
      return;
    }
    
    try {
      final route = await _firestore.collection('routes').doc(routeId).get();
      if (!route.exists) {
        throw Exception('Route not found');
      }

      // Check if route is already reimbursed
      final isReimbursed = route['reimbursed'] as bool? ?? false;
      if (isReimbursed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This route has already been reimbursed')),
          );
        }
        return;
      }

      // Check if reimbursement already exists for this route
      final reimbursementQuery = await _firestore
          .collection('reimbursements')
          .where('routeId', isEqualTo: routeId)
          .get();

      if (reimbursementQuery.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This route has already been reimbursed')),
          );
        }
        return;
      }

      final distance = await _locationService.calculateRouteDistance(routeId);
      final calculatedReimbursement = distance * _pricePerKm;

      if (!context.mounted) return;

      // Show dialog for reimbursement amount and status
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => ReimbursementDialog(
          calculatedAmount: calculatedReimbursement,
        ),
      );

      if (result == null) return;

      final reimbursement = result['amount'] as double;
      final status = result['status'] as String;

      await _firestore.collection('reimbursements').add({
        'routeId': routeId,
        'userId': route['userId'],
        'amount': reimbursement,
        'status': status,
        'calculated_amount': calculatedReimbursement,
        'timestamp': Timestamp.now(),
      });

      await _firestore.collection('routes').doc(routeId).update({
        'reimbursed': true,
        'reimbursement_date': Timestamp.now(),
        'reimbursement_status': status,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route marked as reimbursed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

}

class ReimbursementDialog extends StatefulWidget {
  final double calculatedAmount;

  const ReimbursementDialog({
    super.key,
    required this.calculatedAmount,
  });

  @override
  State<ReimbursementDialog> createState() => _ReimbursementDialogState();
}

class _ReimbursementDialogState extends State<ReimbursementDialog> {
  late TextEditingController _amountController;
  String _selectedStatus = 'Approved';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.calculatedAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reimbursement Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Calculated Amount: \$${widget.calculatedAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Approved Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Approved', child: Text('Approved')),
              DropdownMenuItem(value: 'Partially Approved', child: Text('Partially Approved')),
              DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text);
            if (amount != null && amount >= 0) {
              Navigator.pop(context, {
                'amount': amount,
                'status': _selectedStatus,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a valid amount')),
              );
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
} 