import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parkeasy2/models/parking_space_model.dart';
import 'package:parkeasy2/services/parking_service.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ParkingService _parkingService = ParkingService();

  User? get currentUser => _auth.currentUser;

  // Controllers for editing parking space details
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _slotsControllers = {};
  final Map<String, TextEditingController> _upiControllers = {};

  // Add parking space controllers
  final _addAddressController = TextEditingController();
  final _addPriceController = TextEditingController();
  final _addSlotsController = TextEditingController();
  final _addLatitudeController = TextEditingController();
  final _addLongitudeController = TextEditingController();
  final _addUpiController = TextEditingController();

  File? _pickedImage;
  bool _isAddingSpace = false;

  @override
  void dispose() {
    _priceControllers.forEach((_, c) => c.dispose());
    _slotsControllers.forEach((_, c) => c.dispose());
    _upiControllers.forEach((_, c) => c.dispose());

    _addAddressController.dispose();
    _addPriceController.dispose();
    _addSlotsController.dispose();
    _addLatitudeController.dispose();
    _addLongitudeController.dispose();
    _addUpiController.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    final storageRef = FirebaseStorage.instance.ref();
    final imageRef = storageRef.child(
      'parking_photos/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await imageRef.putFile(imageFile);
    return await imageRef.getDownloadURL();
  }

  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Do you really want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _auth.signOut();
      // Navigate to login or initial screen here, e.g.:
      // Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _editParkingSpace(ParkingSpace space) {
    final priceController =
        _priceControllers[space.id] ??
        TextEditingController(text: space.pricePerHour.toString());
    final slotsController =
        _slotsControllers[space.id] ??
        TextEditingController(text: space.availableSpots.toString());
    final upiController =
        _upiControllers[space.id] ?? TextEditingController(text: space.upiId);

    _priceControllers[space.id] = priceController;
    _slotsControllers[space.id] = slotsController;
    _upiControllers[space.id] = upiController;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Edit Parking Space - ${space.address}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price per hour',
                  ),
                ),
                TextField(
                  controller: slotsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Available spots',
                  ),
                ),
                TextField(
                  controller: upiController,
                  decoration: const InputDecoration(labelText: 'UPI ID'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final price = double.tryParse(priceController.text);
                  final slots = int.tryParse(slotsController.text);
                  final upi = upiController.text.trim();

                  if (price == null || slots == null || upi.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid data')),
                    );
                    return;
                  }

                  await _parkingService.updateParkingSpace(
                    space.id,
                    pricePerHour: price,
                    availableSpots: slots,
                    upiId: upi,
                  );

                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _showAddParkingSpaceDialog() async {
    setState(() => _isAddingSpace = true);

    _addAddressController.clear();
    _addPriceController.clear();
    _addSlotsController.clear();
    _addLatitudeController.clear();
    _addLongitudeController.clear();
    _addUpiController.clear();
    _pickedImage = null;

    await showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('Add New Parking Space'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _addAddressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      TextField(
                        controller: _addPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price per hour',
                        ),
                      ),
                      TextField(
                        controller: _addSlotsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Available spots',
                        ),
                      ),
                      TextField(
                        controller: _addLatitudeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                      ),
                      TextField(
                        controller: _addLongitudeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                      TextField(
                        controller: _addUpiController,
                        decoration: const InputDecoration(labelText: 'UPI ID'),
                      ),
                      const SizedBox(height: 12),
                      _pickedImage == null
                          ? ElevatedButton.icon(
                            icon: const Icon(Icons.photo),
                            label: const Text('Pick Photo'),
                            onPressed: () async {
                              final pickedFile = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                              );
                              if (pickedFile != null) {
                                setStateDialog(() {
                                  _pickedImage = File(pickedFile.path);
                                });
                              }
                            },
                          )
                          : Image.file(_pickedImage!, height: 120),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final address = _addAddressController.text.trim();
                      final price = double.tryParse(_addPriceController.text);
                      final slots = int.tryParse(_addSlotsController.text);
                      final latitude = double.tryParse(
                        _addLatitudeController.text,
                      );
                      final longitude = double.tryParse(
                        _addLongitudeController.text,
                      );
                      final upi = _addUpiController.text.trim();

                      if (address.isEmpty ||
                          price == null ||
                          slots == null ||
                          latitude == null ||
                          longitude == null ||
                          upi.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill all fields with valid data',
                            ),
                          ),
                        );
                        return;
                      }

                      String photoUrl = '';
                      if (_pickedImage != null) {
                        photoUrl = await _uploadImage(_pickedImage!);
                      }

                      await _parkingService.addParkingSpace(
                        ownerId: currentUser!.uid,
                        address: address,
                        pricePerHour: price,
                        availableSpots: slots,
                        latitude: latitude,
                        longitude: longitude,
                        upiId: upi,
                        photoUrl: photoUrl,
                      );

                      Navigator.pop(context);
                      setState(() {
                        _pickedImage = null;
                        _isAddingSpace = false;
                      });
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          ),
    );

    setState(() => _isAddingSpace = false);
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: StreamBuilder<List<ParkingSpace>>(
        stream: _parkingService.getParkingSpacesByOwnerStream(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final parkingSpaces = snapshot.data ?? [];

          // Calculate total slots and total reviews
          final totalSlots = parkingSpaces.fold<int>(
            0,
            (sum, s) => sum + s.availableSpots,
          );
          final totalReviews = parkingSpaces.fold<int>(
            0,
            (sum, s) => sum + (s.reviews.length),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Owner info header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(
                        currentUser!.photoURL ?? '',
                      ),
                      onBackgroundImageError: (_, __) {},
                      child:
                          currentUser!.photoURL == null
                              ? const Icon(Icons.person, size: 30)
                              : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        currentUser!.displayName ?? currentUser!.email ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(
                      'Spaces',
                      parkingSpaces.length.toString(),
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Slots',
                      totalSlots.toString(),
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Reviews',
                      totalReviews.toString(),
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Parking spaces list
                Text(
                  'Your Parking Spaces',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                if (parkingSpaces.isEmpty)
                  const Center(child: Text('No parking spaces added yet.'))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: parkingSpaces.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final space = parkingSpaces[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              space.photoUrl.isNotEmpty
                                  ? NetworkImage(space.photoUrl)
                                  : const AssetImage(
                                        'assets/parking_placeholder.png',
                                      )
                                      as ImageProvider,
                        ),
                        title: Text(space.address),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price/hr: ₹${space.pricePerHour.toStringAsFixed(2)}',
                            ),
                            Text('Available spots: ${space.availableSpots}'),
                            Text('UPI ID: ${space.upiId}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editParkingSpace(space),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Add new parking space button
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Parking Space'),
                    onPressed:
                        _isAddingSpace ? null : _showAddParkingSpaceDialog,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      color: color.withOpacity(0.1),
      child: SizedBox(
        width: 100,
        height: 80,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 14, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
