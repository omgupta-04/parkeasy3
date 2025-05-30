import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parking_space_model.dart';
import '../services/parking_service.dart';

class OwnerDashboardScreen extends StatefulWidget {
  @override
  _OwnerDashboardScreenState createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ParkingService _parkingService = ParkingService();
  String? _ownerId;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _ownerId = _user?.uid;
  }

  void _showEditDialog(ParkingSpace space) {
    final _priceController = TextEditingController(text: space.pricePerHour.toString());
    final _slotsController = TextEditingController(text: space.availableSpots.toString());
    final _upiController = TextEditingController(text: space.upiId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Parking Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Price per hour'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _slotsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Available spots'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _upiController,
              decoration: InputDecoration(labelText: 'Owner UPI ID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(_priceController.text) ?? space.pricePerHour;
              final newSlots = int.tryParse(_slotsController.text) ?? space.availableSpots;
              final newUpi = _upiController.text.trim();
              await _parkingService.updateParkingSpace(
                space.id,
                pricePerHour: newPrice,
                availableSpots: newSlots,
                upiId: newUpi,
              );
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Profile'),
        content: _user == null
            ? Text('No user info available.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_user!.photoURL != null)
                    Center(
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(_user!.photoURL!),
                        radius: 32,
                      ),
                    ),
                  SizedBox(height: 12),
                  Text('Name: ${_user!.displayName ?? "N/A"}'),
                  Text('Email: ${_user!.email ?? "N/A"}'),
                  SizedBox(height: 12),
                  Text('UID: ${_user!.uid}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logged out successfully!')),
              );
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddParkingDialog() {
    final _addressController = TextEditingController();
    final _priceController = TextEditingController();
    final _slotsController = TextEditingController();
    final _latController = TextEditingController();
    final _lngController = TextEditingController();
    final _upiController = TextEditingController();
    bool useCurrentLocation = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Parking Space'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(labelText: 'Address'),
                  ),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Price per hour'),
                  ),
                  TextField(
                    controller: _slotsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Available spots'),
                  ),
                  TextField(
                    controller: _upiController,
                    decoration: InputDecoration(labelText: 'Owner UPI ID'),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: useCurrentLocation,
                        onChanged: (val) async {
                          setState(() => useCurrentLocation = val!);
                          if (val == true) {
                            try {
                              LocationPermission permission = await Geolocator.requestPermission();
                              Position pos = await Geolocator.getCurrentPosition(
                                  desiredAccuracy: LocationAccuracy.high);
                              _latController.text = pos.latitude.toString();
                              _lngController.text = pos.longitude.toString();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Location error: $e')),
                              );
                            }
                          }
                        },
                      ),
                      Text('Use current location'),
                    ],
                  ),
                  if (!useCurrentLocation) ...[
                    TextField(
                      controller: _latController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Latitude'),
                    ),
                    TextField(
                      controller: _lngController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Longitude'),
                    ),
                  ],
                  if (useCurrentLocation) ...[
                    Text('Latitude: ${_latController.text}'),
                    Text('Longitude: ${_lngController.text}'),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final address = _addressController.text.trim();
                  final price = double.tryParse(_priceController.text) ?? 0.0;
                  final slots = int.tryParse(_slotsController.text) ?? 0;
                  final lat = double.tryParse(_latController.text) ?? 0.0;
                  final lng = double.tryParse(_lngController.text) ?? 0.0;
                  final upiId = _upiController.text.trim();

                  if (address.isEmpty || price <= 0 || slots <= 0 || upiId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please fill all fields correctly.')),
                    );
                    return;
                  }
                  await _parkingService.addParkingSpace(
                    ownerId: _ownerId!,
                    address: address,
                    pricePerHour: price,
                    availableSpots: slots,
                    latitude: lat,
                    longitude: lng,
                    upiId: upiId,
                  );
                  Navigator.pop(context);
                  setState(() {});
                },
                child: Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildDashboardHeader(List<ParkingSpace> spaces) {
    int totalSlots = spaces.fold(0, (sum, s) => sum + s.availableSpots);
    int totalReviews = spaces.fold(0, (sum, s) => sum + (s.reviews.length));
    return Card(
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DashboardStat(label: "Spaces", value: spaces.length.toString(), icon: Icons.local_parking),
            _DashboardStat(label: "Slots", value: totalSlots.toString(), icon: Icons.event_seat),
            _DashboardStat(label: "Reviews", value: totalReviews.toString(), icon: Icons.star),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Owner Dashboard'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.account_circle, size: 28),
            onPressed: _showProfileDialog,
            tooltip: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddParkingDialog,
        child: Icon(Icons.add),
        tooltip: 'Add Parking Space',
      ),
      body: _ownerId == null
          ? Center(child: Text('Not logged in'))
          : StreamBuilder<List<ParkingSpace>>(
              stream: _parkingService.getParkingSpacesByOwnerStream(_ownerId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No records found'));
                }
                final spaces = snapshot.data!;
                return Column(
                  children: [
                    _buildDashboardHeader(spaces),
                    Expanded(
                      child: ListView.builder(
                        itemCount: spaces.length,
                        itemBuilder: (context, idx) {
                          final space = spaces[idx];
                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: space.photoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(space.photoUrl, width: 56, height: 56, fit: BoxFit.cover),
                                    )
                                  : Icon(Icons.local_parking, size: 40, color: Colors.blue),
                              title: Text(
                                space.address,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('₹${space.pricePerHour}/hr • ${space.availableSpots} slots'),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 16),
                                      SizedBox(width: 2),
                                      Text(
                                        space.reviews.isNotEmpty
                                            ? (space.reviews.map((r) => r.rating).reduce((a, b) => a + b) / space.reviews.length).toStringAsFixed(1)
                                            : 'No rating',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(width: 8),
                                      Text('(${space.reviews.length} reviews)'),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text('UPI: ${space.upiId}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showEditDialog(space),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      await _parkingService.deleteParkingSpace(space.id);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                // Optionally navigate to details or analytics
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DashboardStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }
}
