import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/parking_service.dart';

class AddParkingScreen extends StatefulWidget {
  @override
  State<AddParkingScreen> createState() => _AddParkingScreenState();
}

class _AddParkingScreenState extends State<AddParkingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _slotsController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _upiController = TextEditingController();
  bool useCurrentLocation = false;
  bool _isLoading = false;

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _latController.text = pos.latitude.toString();
      _lngController.text = pos.longitude.toString();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  Future<void> _addParkingSpace() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final ownerId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final address = _addressController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final slots = int.tryParse(_slotsController.text) ?? 0;
    final lat = double.tryParse(_latController.text) ?? 0.0;
    final lng = double.tryParse(_lngController.text) ?? 0.0;
    final upiId = _upiController.text.trim();

    await ParkingService().addParkingSpace(
      ownerId: ownerId,
      address: address,
      pricePerHour: price,
      availableSpots: slots,
      latitude: lat,
      longitude: lng,
      upiId: upiId,
    );
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Parking Space')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price per hour'),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _slotsController,
                decoration: InputDecoration(labelText: 'Available spots'),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _upiController,
                decoration: InputDecoration(labelText: 'Owner UPI ID'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: useCurrentLocation,
                    onChanged: (val) async {
                      setState(() => useCurrentLocation = val!);
                      if (val == true) {
                        await _getCurrentLocation();
                      }
                    },
                  ),
                  Text('Use current location'),
                ],
              ),
              if (!useCurrentLocation) ...[
                TextFormField(
                  controller: _latController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Latitude'),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _lngController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Longitude'),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
              ],
              if (useCurrentLocation) ...[
                Text('Latitude: ${_latController.text}'),
                Text('Longitude: ${_lngController.text}'),
              ],
              SizedBox(height: 24),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _addParkingSpace,
                      child: Text('Add Space'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
