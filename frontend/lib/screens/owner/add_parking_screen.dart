import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parkeasy2/services/parking_service.dart';

class AddParkingScreen extends StatefulWidget {
  final String ownerId;
  const AddParkingScreen({super.key, required this.ownerId});

  @override
  State<AddParkingScreen> createState() => _AddParkingScreenState();
}

class _AddParkingScreenState extends State<AddParkingScreen>
    with SingleTickerProviderStateMixin {
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _slotsController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _upiController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  double _scale = 1.0;

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latController.text = pos.latitude.toString();
        _lngController.text = pos.longitude.toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location error: $e')));
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _selectedImage = File(file.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Add Parking Slot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 1,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purpleAccent, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCard(
                  title: "Slot Photos",
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey),
                        color: Colors.grey[300],
                        image:
                            _selectedImage != null
                                ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          _selectedImage == null
                              ? const Icon(Icons.camera_alt, size: 40)
                              : null,
                    ),
                  ),
                ),

                _buildCard(
                  title: "Slot Location",
                  child: Column(
                    children: [
                      _isFetchingLocation
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.location_pin),
                            label: const Text("Use Current Location"),
                          ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        _latController,
                        "Latitude",
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        _lngController,
                        "Longitude",
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildCard(
                  title: "Total Slots",
                  child: _buildTextField(
                    _slotsController,
                    "e.g. 12",
                    keyboardType: TextInputType.number,
                  ),
                ),

                _buildCard(
                  title: "Address",
                  child: _buildTextField(_addressController, "Enter Address"),
                ),

                _buildCard(
                  title: "Price per Hour",
                  child: _buildTextField(
                    _priceController,
                    "e.g. 40",
                    keyboardType: TextInputType.number,
                  ),
                ),

                _buildCard(
                  title: "Owner UPI ID",
                  child: _buildTextField(_upiController, "e.g. example@upi"),
                ),

                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : GestureDetector(
                      onTapDown: (_) => setState(() => _scale = 0.95),
                      onTapUp: (_) => setState(() => _scale = 1.0),
                      onTapCancel: () => setState(() => _scale = 1.0),
                      child: AnimatedScale(
                        scale: _scale,
                        duration: const Duration(milliseconds: 150),
                        child: ElevatedButton.icon(
                          onPressed: _saveParkingSlot,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 15,
                            ),
                          ),
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            "Save Slot",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveParkingSlot() async {
    final int totalSlots = int.tryParse(_slotsController.text) ?? 0;
    final double price = double.tryParse(_priceController.text) ?? 0.0;
    final String upi = _upiController.text.trim();
    final double lat = double.tryParse(_latController.text) ?? 0.0;
    final double lng = double.tryParse(_lngController.text) ?? 0.0;
    final String address = _addressController.text.trim();

    if (totalSlots <= 0 ||
        price <= 0 ||
        upi.isEmpty ||
        address.isEmpty ||
        lat == 0.0 ||
        lng == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fill all details correctly to save"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await ParkingService().addParkingSpace(
      ownerId: widget.ownerId,
      address: address,
      pricePerHour: price,
      availableSpots: totalSlots,
      latitude: lat,
      longitude: lng,
      upiId: upi,
      photoUrl: '', // You can later upload _selectedImage and use its URL
    );

    setState(() => _isLoading = false);

    Navigator.pop(context, {
      'slots': totalSlots,
      'price': price,
      'upiId': upi,
      'latitude': lat,
      'longitude': lng,
      'address': address,
    });
  }
}
