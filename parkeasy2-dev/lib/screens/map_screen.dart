import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:parkeasy2/models/parking_space_model.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng _center = LatLng(28.6139, 77.2090); // fallback default
  Set<Marker> _markers = {};
  List<ParkingSpace> _customParkingLots = [];
  double _maxDistance = 100000; // in meters
  double _maxPrice = 100; // max ₹ per hour
  LatLng? _searchCenter;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _center = LatLng(position.latitude, position.longitude);
    _searchCenter = _center;

    setState(() {});
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, 14));
    _fetchParkingLots(_center.latitude, _center.longitude);
  }

  Future<void> _searchLocation(String query) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$apiKey',
    );

    final response = await http.get(url);
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final lat = data['results'][0]['geometry']['location']['lat'];
      final lng = data['results'][0]['geometry']['location']['lng'];
      final location = LatLng(lat, lng);

      _searchCenter = location;

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));

      // Add marker for searched location
      _markers.removeWhere((m) => m.markerId.value == 'search-location');
      _markers.add(
        Marker(
          markerId: MarkerId('search-location'),
          position: location,
          infoWindow: InfoWindow(title: 'Searched Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );

      setState(() {});
      _fetchParkingLots(lat, lng);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location not found')));
    }
  }

  Future<void> _fetchParkingLots(double lat, double lng) async {
    final databaseRef = FirebaseDatabase.instance.ref('parking_spaces');
    final snapshot = await databaseRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    List<ParkingSpace> nearby = [];
    Set<Marker> newMarkers =
        _markers
            .where((m) => m.markerId.value == 'search-location')
            .toSet(); // Retain search marker

    for (var entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      final space = ParkingSpace.fromMap(Map<String, dynamic>.from(value));
      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        space.latitude,
        space.longitude,
      );

      if (space.pricePerHour <= _maxPrice && distance <= _maxDistance) {
        nearby.add(space);
        newMarkers.add(
          Marker(
            markerId: MarkerId('custom-$key'),
            position: LatLng(space.latitude, space.longitude),
            infoWindow: InfoWindow(
              title: space.address,
              snippet:
                  '₹${space.pricePerHour}/hr • ${space.availableSpots} spots',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }
    }

    setState(() {
      _customParkingLots = nearby;
      _markers = newMarkers;
    });

    if (nearby.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No parking lots found near this location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nearby Parking Lots')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Enter location",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchLocation(_searchController.text),
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Max Price: ₹${_maxPrice.toInt()}'),
                    Expanded(
                      child: Slider(
                        value: _maxPrice,
                        min: 0,
                        max: 200,
                        divisions: 20,
                        label: _maxPrice.round().toString(),
                        onChanged: (value) {
                          setState(() => _maxPrice = value);
                          if (_searchCenter != null) {
                            _fetchParkingLots(
                              _searchCenter!.latitude,
                              _searchCenter!.longitude,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'Max Distance: ${(_maxDistance / 1000).toStringAsFixed(1)} km',
                    ),
                    Expanded(
                      child: Slider(
                        value: _maxDistance,
                        min: 500,
                        max: 100000,
                        divisions: 19,
                        label: '${(_maxDistance / 1000).toStringAsFixed(1)} km',
                        onChanged: (value) {
                          setState(() => _maxDistance = value);
                          if (_searchCenter != null) {
                            _fetchParkingLots(
                              _searchCenter!.latitude,
                              _searchCenter!.longitude,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 14),
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_searchCenter != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_searchCenter!, 14),
                  );
                  _fetchParkingLots(
                    _searchCenter!.latitude,
                    _searchCenter!.longitude,
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _customParkingLots.length,
              itemBuilder: (context, index) {
                final lot = _customParkingLots[index];
                return ListTile(
                  title: Text(lot.address),
                  subtitle: Text(
                    '₹${lot.pricePerHour}/hr • ${lot.availableSpots} spots',
                  ),
                  onTap: () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(lot.latitude, lot.longitude),
                        17,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
