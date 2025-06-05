import 'dart:convert';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:parkeasy2/models/parking_space_model.dart';
import 'package:parkeasy2/screens/auth_screen.dart';
import 'package:parkeasy2/screens/user/history_user_screen.dart';
import 'package:parkeasy2/screens/user/parking_details_screen.dart';
import 'package:parkeasy2/screens/user/user_profile_screen.dart';
import 'package:parkeasy2/services/profile_image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class MapScreen extends StatefulWidget {
  final String email;
  const MapScreen({Key? key, required this.email}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng _center = LatLng(
    28.6139,
    77.2090,
  ); // Default fallback location (Delhi)
  Set<Marker> _markers = {};
  List<ParkingSpace> _customParkingLots = [];
  double _maxDistance = 100000; // max distance filter (meters)
  double _maxPrice = 100; // max price filter (₹ per hour)
  LatLng? _searchCenter;
  int _selectedIndex = 0;
  File? _profileImage;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Showcase Keys
  final GlobalKey _profileAvatarKey = GlobalKey();
  final GlobalKey _searchBoxKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _locateUser();
    _loadProfileImage();
    _checkAndShowShowcase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadProfileImage() async {
    final imageFile = await ProfileImageService.getProfileImage();
    if (imageFile != null && mounted) {
      setState(() {
        _profileImage = imageFile;
      });
    }
  }

  Future _checkAndShowShowcase() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenShowcase = prefs.getBool('hasSeenShowcase') ?? false;
    if (!hasSeenShowcase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final showcase = ShowCaseWidget.of(context);
        if (showcase != null) {
          showcase.startShowCase([
            _profileAvatarKey,
            _searchBoxKey,
            _filterKey,
            _historyKey,
          ]);
        }
      });
      await prefs.setBool('hasSeenShowcase', true);
    }
  }

  Future<void> _locateUser() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location permission denied')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location permission denied forever. Enable in settings.',
          ),
        ),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _center = LatLng(position.latitude, position.longitude);
    _searchCenter = _center;

    if (mounted) {
      setState(() {});
    }

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, 14));
    _fetchParkingLots(_center.latitude, _center.longitude);
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Maps API key not set')));
      return;
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final lat = data['results'][0]['geometry']['location']['lat'];
        final lng = data['results'][0]['geometry']['location']['lng'];
        final location = LatLng(lat, lng);

        _searchCenter = location;

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));

        // Remove old search marker, add new one
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

        if (mounted) setState(() {});

        _fetchParkingLots(lat, lng);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location not found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to search location: $e')));
    }
  }

  Future<void> _fetchParkingLots(double lat, double lng) async {
    try {
      final databaseRef = FirebaseDatabase.instance.ref('parking_spaces');
      final snapshot = await databaseRef.get();

      if (!snapshot.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No parking data found')));
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      List<ParkingSpace> nearby = [];
      Set<Marker> newMarkers =
          _markers
              .where((m) => m.markerId.value == 'search-location')
              .toSet(); // Keep the search marker

      for (var entry in data.entries) {
        final space = ParkingSpace.fromMap(
          Map<String, dynamic>.from(entry.value),
        );

        final distance = Geolocator.distanceBetween(
          lat,
          lng,
          space.latitude,
          space.longitude,
        );

        // Filter by price and distance
        if (space.pricePerHour <= _maxPrice && distance <= _maxDistance) {
          nearby.add(space);

          // Marker color: grey if fully booked, else orange
          final isBooked = space.availableSpots == 0;

          newMarkers.add(
            Marker(
              markerId: MarkerId('custom-${entry.key}'),
              position: LatLng(space.latitude, space.longitude),
              infoWindow: InfoWindow(
                title: space.address,
                snippet:
                    '₹${space.pricePerHour}/hr • ${space.availableSpots} spots',
              ),
              icon:
                  isBooked
                      ? BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      )
                      : BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _customParkingLots = nearby;
          _markers = newMarkers;
        });
      }

      if (nearby.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No parking lots found near this location')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch parking lots: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: Showcase(
              key: _searchBoxKey,
              description: 'Search for a location here.',
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Showcase(
              key: _filterKey,
              description: 'Adjust filters to find suitable parking.',
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
                          label:
                              '${(_maxDistance / 1000).toStringAsFixed(1)} km',
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
                final isBooked = lot.availableSpots == 0;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lot.address,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '₹${lot.pricePerHour}/hr • ${lot.availableSpots} spots',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              isBooked
                                  ? null
                                  : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => ParkingDetailsScreen(
                                              parkingSpace: lot,
                                              userLat:
                                                  _searchCenter?.latitude ??
                                                  _center.latitude,
                                              userLng:
                                                  _searchCenter?.longitude ??
                                                  _center.longitude,
                                            ),
                                      ),
                                    );
                                  },
                          child: Text("Book", style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isBooked ? Colors.grey[600] : Colors.blue,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      endDrawer: _buildProfileDrawer(widget.email),
      endDrawerEnableOpenDragGesture: false,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 5,
      title: Flexible(
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                "Nearby Slots",
                style: TextStyle(color: Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Builder(
          builder:
              (context) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                  child: showcaseWrapper(
                    key: _profileAvatarKey,
                    description: 'Tap here to open your profile and settings.',
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      child: ClipOval(
                        child:
                            _profileImage != null
                                ? Image.file(
                                  _profileImage!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                )
                                : Image.asset(
                                  'assets/images/profile_default.jpg',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget showcaseWrapper({
    required GlobalKey key,
    required Widget child,
    required String description,
  }) {
    return Showcase(
      key: key,
      description: description,
      descTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      tooltipBackgroundColor: Colors.blueAccent,
      child: child,
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HistoryUserScreen()),
          ).then((_) {
            setState(() => _selectedIndex = 0);
          });
        } else if (index == 2) {
          _scaffoldKey.currentState?.openEndDrawer();
        }
      },
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(
          icon: showcaseWrapper(
            key: _historyKey,
            description: 'Check your past bookings here.',
            child: Icon(Icons.history),
          ),
          label: "History",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }

  Widget _buildProfileDrawer(String email) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage:
                  _profileImage != null
                      ? FileImage(_profileImage!)
                      : AssetImage('assets/images/profile_default.jpg')
                          as ImageProvider,
            ),
            SizedBox(height: 10),
            Text(
              "User Name",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(email, style: TextStyle(color: Colors.grey[800])),
              ],
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.person),
              title: Text("Profile"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text("Settings"),
              onTap: () {
                AppSettings.openAppSettings();
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text("Logout"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => AuthScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
