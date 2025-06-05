// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:parkeasy2/screens/user/history_user_screen.dart';
// import 'package:parkeasy2/screens/user/parking_details_screen.dart';
// import 'package:parkeasy2/screens/user/user_profile_screen.dart';
// import 'package:parkeasy2/services/notifi_handler.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:showcaseview/showcaseview.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:app_settings/app_settings.dart';

// import 'auth_screen.dart';
// import '../services/profile_image_service.dart';
// import '../models/parking_space_model.dart';
// import '../services/parking_service.dart';

// // CLASS Parking MOVED ABOVE FOR VISIBILITY
// class Parking {
//   final String imagePath;
//   final String name;
//   final bool isBooked;
//   final double price;
//   final double distance;
//   final double rating;

//   Parking({
//     required this.imagePath,
//     required this.name,
//     required this.isBooked,
//     required this.price,
//     required this.distance,
//     required this.rating,
//   });

//   Parking copyWith({double? distance, double? rating}) => Parking(
//     imagePath: imagePath,
//     name: name,
//     isBooked: isBooked,
//     price: price,
//     distance: distance ?? this.distance,
//     rating: rating ?? this.rating,
//   );
// }

// Parking parkingSpaceToParking(ParkingSpace space, double avgRating) {
//   return Parking(
//     imagePath:
//         space.photoUrl.isNotEmpty
//             ? space.photoUrl
//             : 'assets/images/dummylot.jpg',
//     name: space.address,
//     isBooked: space.availableSpots == 0,
//     price: space.pricePerHour,
//     distance: 1.0,
//     rating: avgRating,
//   );
// }

// Future<Position> getCurrentPosition() async {
//   bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//   if (!serviceEnabled) throw Exception('Location services are disabled.');

//   LocationPermission permission = await Geolocator.checkPermission();
//   if (permission == LocationPermission.denied) {
//     permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.denied)
//       throw Exception('Location permissions are denied');
//   }
//   if (permission == LocationPermission.deniedForever)
//     throw Exception('Location permissions are permanently denied.');

//   return await Geolocator.getCurrentPosition();
// }

// double calculateDistanceKm(
//   double startLat,
//   double startLng,
//   double endLat,
//   double endLng,
// ) {
//   return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
//       1000.0;
// }

// Future<void> openGoogleMaps(double lat, double lng) async {
//   final url =
//       'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
//   if (await canLaunchUrl(Uri.parse(url))) {
//     await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
//   } else {
//     throw 'Could not open Google Maps.';
//   }
// }

// class HomeScreen extends StatefulWidget {
//   final String email;
//   const HomeScreen({Key? key, required this.email}) : super(key: key);

//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   double _selectedRadius = 1.0;
//   double _selectedMinRating = 0.0;
//   int _selectedIndex = 0;
//   File? _profileImage;
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   final GlobalKey _profileAvatarKey = GlobalKey();
//   final GlobalKey _searchBoxKey = GlobalKey();
//   final GlobalKey _filterKey = GlobalKey();
//   final GlobalKey _historyKey = GlobalKey();
//   GoogleMapController? _mapController;
//   final TextEditingController _searchController = TextEditingController();
//   LatLng _center = LatLng(28.6139, 77.2090); // fallback default
//   Set<Marker> _markers = {};
//   List<ParkingSpace> _customParkingLots = [];
//   double _maxDistance = 100000; // in meters
//   double _maxPrice = 100; // max ₹ per hour
//   LatLng? _searchCenter;

//   final ParkingService _parkingService = ParkingService();

//   late Future<Position> _positionFuture;
//   late Future<List<ParkingSpace>> _parkingSpacesFuture;

//   @override
//   void initState() {
//     super.initState();
//     _checkAndShowShowcase();
//     _loadProfileImage();
//     _positionFuture = getCurrentPosition().then((pos) {
//       _center = LatLng(pos.latitude, pos.longitude);
//       _searchCenter = _center;
//       _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, 14));
//       _parkingSpacesFuture = _fetchParkingLots(pos.latitude, pos.longitude);
//       return pos;
//     });
//   }

//   void _loadProfileImage() async {
//     final imageFile = await ProfileImageService.getProfileImage();
//     if (imageFile != null && mounted) {
//       setState(() {
//         _profileImage = imageFile;
//       });
//     }
//   }

//   Future _checkAndShowShowcase() async {
//     final prefs = await SharedPreferences.getInstance();
//     bool hasSeenShowcase = prefs.getBool('hasSeenShowcase') ?? false;
//     if (!hasSeenShowcase || hasSeenShowcase) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         ShowCaseWidget.of(context).startShowCase([
//           _profileAvatarKey,
//           _searchBoxKey,
//           _filterKey,
//           _historyKey,
//         ]);
//       });
//       await prefs.setBool('hasSeenShowcase', true);
//     }
//   }

//   Future<void> _locateUser() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return;

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) return;
//     }

//     if (permission == LocationPermission.deniedForever) return;

//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );

//     _center = LatLng(position.latitude, position.longitude);
//     _searchCenter = _center;

//     setState(() {
//       _parkingSpacesFuture = _fetchParkingLots(
//         position.latitude,
//         position.longitude,
//       );
//     });

//     _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_center, 14));
//   }

//   Future<void> _searchLocation(String query) async {
//     final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
//     final url = Uri.parse(
//       'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$apiKey',
//     );

//     final response = await http.get(url);
//     final data = json.decode(response.body);

//     if (data['status'] == 'OK') {
//       final lat = data['results'][0]['geometry']['location']['lat'];
//       final lng = data['results'][0]['geometry']['location']['lng'];
//       final location = LatLng(lat, lng);

//       _searchCenter = location;

//       _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));

//       // Add marker for searched location
//       _markers.removeWhere((m) => m.markerId.value == 'search-location');
//       _markers.add(
//         Marker(
//           markerId: MarkerId('search-location'),
//           position: location,
//           infoWindow: InfoWindow(title: 'Searched Location'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueAzure,
//           ),
//         ),
//       );

//       setState(() {});
//       _parkingSpacesFuture = _fetchParkingLots(lat, lng);
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Location not found')));
//     }
//   }

//   Future<List<ParkingSpace>> _fetchParkingLots(double lat, double lng) async {
//     final databaseRef = FirebaseDatabase.instance.ref('parking_spaces');
//     final snapshot = await databaseRef.get();

//     if (!snapshot.exists) return [];

//     final data = snapshot.value as Map<dynamic, dynamic>;
//     List<ParkingSpace> nearby = [];
//     Set<Marker> newMarkers =
//         _markers.where((m) => m.markerId.value == 'search-location').toSet();

//     for (var entry in data.entries) {
//       final space = ParkingSpace.fromMap(
//         Map<String, dynamic>.from(entry.value),
//       );
//       final distance = Geolocator.distanceBetween(
//         lat,
//         lng,
//         space.latitude,
//         space.longitude,
//       );

//       if (space.pricePerHour <= _maxPrice && distance <= _maxDistance) {
//         nearby.add(space);
//         newMarkers.add(
//           Marker(
//             markerId: MarkerId('custom-${entry.key}'),
//             position: LatLng(space.latitude, space.longitude),
//             infoWindow: InfoWindow(
//               title: space.address,
//               snippet:
//                   '₹${space.pricePerHour}/hr • ${space.availableSpots} spots',
//             ),
//             icon: BitmapDescriptor.defaultMarkerWithHue(
//               BitmapDescriptor.hueOrange,
//             ),
//           ),
//         );
//       }
//     }

//     setState(() {
//       _customParkingLots = nearby;
//       _markers = newMarkers;
//     });

//     if (nearby.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('No parking lots found near this location')),
//       );
//     }

//     return nearby;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: Colors.white,
//       appBar: _buildAppBar(),
//       body: FutureBuilder<Position>(
//         future: _positionFuture,
//         builder: (context, positionSnapshot) {
//           if (positionSnapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           }
//           if (!positionSnapshot.hasData) {
//             return Center(child: Text('Could not get location'));
//           }
//           final userPosition = positionSnapshot.data!;
//           return FutureBuilder<List<ParkingSpace>>(
//             future: _parkingSpacesFuture,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return Center(child: CircularProgressIndicator());
//               }
//               if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                 return Center(child: Text('No records found'));
//               }
//               final parkingSpaces = snapshot.data!;
//               // Calculate distance and rating for each space
//               final parkingWithDistance =
//                   parkingSpaces.map((space) {
//                     final reviews = space.reviews;
//                     final avgRating =
//                         reviews.isEmpty
//                             ? 0.0
//                             : reviews
//                                     .map((r) => r.rating)
//                                     .reduce((a, b) => a + b) /
//                                 reviews.length;
//                     final dist = calculateDistanceKm(
//                       userPosition.latitude,
//                       userPosition.longitude,
//                       space.latitude,
//                       space.longitude,
//                     );
//                     return {
//                       'space': space,
//                       'distance': dist,
//                       'avgRating': avgRating,
//                     };
//                   }).toList();

//               // Filter by distance and rating
//               final filteredParkingWithDistance =
//                   parkingWithDistance
//                       .where(
//                         (entry) =>
//                             (entry['distance'] as double) <= _selectedRadius &&
//                             (entry['avgRating'] as double) >=
//                                 _selectedMinRating,
//                       )
//                       .toList();

//               // Sort by distance
//               filteredParkingWithDistance.sort(
//                 (a, b) => (a['distance'] as double).compareTo(
//                   b['distance'] as double,
//                 ),
//               );

//               // Convert to UI model
//               final parkingList =
//                   filteredParkingWithDistance.map((entry) {
//                     final space = entry['space'] as ParkingSpace;
//                     final avgRating = entry['avgRating'] as double;
//                     return parkingSpaceToParking(space, avgRating).copyWith(
//                       distance: entry['distance'] as double,
//                       rating: avgRating,
//                     );
//                   }).toList();
//               final sortedSpaces =
//                   filteredParkingWithDistance
//                       .map((e) => e['space'] as ParkingSpace)
//                       .toList();

//               return _buildBody(parkingList, sortedSpaces, userPosition);
//             },
//           );
//         },
//       ),
//       bottomNavigationBar: _buildBottomNavBar(),
//       endDrawer: _buildProfileDrawer(widget.email),
//       endDrawerEnableOpenDragGesture: false,
//     );
//   }

//   PreferredSizeWidget _buildAppBar() {
//     return AppBar(
//       backgroundColor: Colors.white,
//       elevation: 5,
//       title: Row(
//         children: [
//           Icon(Icons.location_on, color: Colors.blue),
//           SizedBox(width: 6),
//           Text("Nearby Slots", style: TextStyle(color: Colors.black)),
//         ],
//       ),
//       actions: [
//         Builder(
//           builder:
//               (context) => Padding(
//                 padding: const EdgeInsets.only(right: 12),
//                 child: GestureDetector(
//                   onTap: () {
//                     _scaffoldKey.currentState?.openEndDrawer();
//                   },
//                   child: showcaseWrapper(
//                     key: _profileAvatarKey,
//                     description: 'Tap here to open your profile and settings.',
//                     child: CircleAvatar(
//                       radius: 18,
//                       backgroundColor: Colors.grey[200],
//                       child: ClipOval(
//                         child:
//                             _profileImage != null
//                                 ? Image.file(
//                                   _profileImage!,
//                                   width: 36,
//                                   height: 36,
//                                   fit: BoxFit.cover,
//                                 )
//                                 : Image.asset(
//                                   'assets/images/profile_default.jpg',
//                                   fit: BoxFit.cover,
//                                   width: 36,
//                                   height: 36,
//                                 ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//         ),
//       ],
//     );
//   }

//   Widget _buildProfileDrawer(String email) {
//     return Drawer(
//       child: SafeArea(
//         child: Column(
//           children: [
//             SizedBox(height: 20),
//             CircleAvatar(
//               radius: 40,
//               backgroundColor: Colors.grey[200],
//               backgroundImage:
//                   _profileImage != null
//                       ? FileImage(_profileImage!)
//                       : AssetImage('assets/images/profile_default.jpg')
//                           as ImageProvider,
//             ),
//             SizedBox(height: 10),
//             Text(
//               "User Name",
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.email, size: 16, color: Colors.grey[600]),
//                 SizedBox(width: 4),
//                 Text(email, style: TextStyle(color: Colors.grey[800])),
//               ],
//             ),
//             Divider(),
//             ListTile(
//               leading: CircleAvatar(
//                 backgroundImage: AssetImage('assets/images/blank_dp.png'),
//                 radius: 11,
//               ),
//               title: Text("Profile"),
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const ProfileScreen(),
//                   ),
//                 );
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.settings),
//               title: Text("Settings"),
//               onTap: () {
//                 AppSettings.openAppSettings();
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.logout),
//               title: Text("Logout"),
//               onTap: () {
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (_) => AuthScreen()),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBody(
//     List<Parking> parkingList,
//     List<ParkingSpace> parkingSpaces,
//     Position userPosition,
//   ) {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(height: 1, color: Colors.black.withOpacity(0.3)),
//               SizedBox(height: 16),
//               Row(
//                 children: [
//                   Expanded(
//                     child: showcaseWrapper(
//                       key: _searchBoxKey,
//                       description:
//                           'Tap here to search nearby parking locations.',
//                       child: TextField(
//                         controller: _searchController,
//                         decoration: InputDecoration(
//                           hintText: 'Search address or area',
//                           suffixIcon: IconButton(
//                             icon: Icon(Icons.search),
//                             onPressed:
//                                 () => _searchLocation(_searchController.text),
//                           ),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           contentPadding: EdgeInsets.symmetric(
//                             vertical: 0,
//                             horizontal: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   IconButton(
//                     icon: Icon(Icons.notifications, color: Colors.blue),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (_) => const NotifiHandler(),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//               SizedBox(height: 15),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   showcaseWrapper(
//                     key: _filterKey,
//                     description:
//                         'Tap to filter parking locations by distance and rating.',
//                     child: _buildFeatureItem(
//                       Icons.filter_list,
//                       "Filters",
//                       onTap: _showDistanceBottomSheet,
//                     ),
//                   ),
//                   _buildFeatureItem(
//                     Icons.attach_money,
//                     "Price",
//                     iconColor: Colors.green,
//                   ),
//                   _buildFeatureItem(
//                     Icons.star,
//                     "Rating",
//                     iconColor: Colors.yellow[700],
//                   ),
//                 ],
//               ),
//               SizedBox(height: 16),
//             ],
//           ),
//         ),
//         SizedBox(
//           height: 250, // Fixed height for map
//           child: GoogleMap(
//             initialCameraPosition: CameraPosition(target: _center, zoom: 14),
//             markers: _markers,
//             onMapCreated: (controller) {
//               _mapController = controller;
//               if (_searchCenter != null) {
//                 _mapController!.animateCamera(
//                   CameraUpdate.newLatLngZoom(_searchCenter!, 14),
//                 );
//                 setState(() {
//                   _parkingSpacesFuture = _fetchParkingLots(
//                     _searchCenter!.latitude,
//                     _searchCenter!.longitude,
//                   );
//                 });
//               }
//             },
//             myLocationEnabled: true,
//             myLocationButtonEnabled: true,
//           ),
//         ),
//         SizedBox(height: 20),
//         Expanded(
//           child: ListView.builder(
//             physics: BouncingScrollPhysics(),
//             padding: EdgeInsets.symmetric(horizontal: 16),
//             shrinkWrap: true,
//             itemCount: parkingList.length,
//             itemBuilder:
//                 (context, i) => _buildParkingItem(
//                   parkingList[i],
//                   parkingSpaces[i],
//                   userPosition,
//                 ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildParkingItem(
//     Parking parking,
//     ParkingSpace parkingSpace,
//     Position userPosition,
//   ) {
//     final distanceKm = calculateDistanceKm(
//       userPosition.latitude,
//       userPosition.longitude,
//       parkingSpace.latitude,
//       parkingSpace.longitude,
//     );

//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Image box
//           Container(
//             width: 80,
//             height: 60,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(8),
//               image: DecorationImage(
//                 image: AssetImage(parking.imagePath),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           SizedBox(width: 12),
//           // Info Column
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Name and status with dot
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         parking.name,
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     SizedBox(width: 6),
//                     // Status dot and text
//                     Row(
//                       children: [
//                         Container(
//                           width: 10,
//                           height: 10,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: parking.isBooked ? Colors.red : Colors.green,
//                           ),
//                         ),
//                         SizedBox(width: 4),
//                         Text(
//                           parking.isBooked ? "Booked" : "Empty",
//                           style: TextStyle(
//                             color: parking.isBooked ? Colors.red : Colors.green,
//                             fontWeight: FontWeight.w600,
//                             fontSize: 12,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 6),
//                 // Price with icon
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.attach_money,
//                       size: 16,
//                       color: Colors.green[700],
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       "\₹${parking.price.toStringAsFixed(2)}",
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 4),
//                 // Distance with icon (show exact distance)
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.location_on,
//                       size: 16,
//                       color: Colors.blueAccent[700],
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       "${distanceKm.toStringAsFixed(2)} km",
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 4),
//                 // Rating with parking icon (show 0 if no reviews)
//                 Row(
//                   children: [
//                     Icon(Icons.star, size: 16, color: Colors.yellowAccent[700]),
//                     SizedBox(width: 4),
//                     Text(
//                       parking.rating.toStringAsFixed(1),
//                       style: TextStyle(fontSize: 14),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           // Book Button
//           Column(
//             children: [
//               ElevatedButton(
//                 onPressed: () {
//                   if (!parking.isBooked) {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder:
//                             (_) => ParkingDetailsScreen(
//                               parkingSpace: parkingSpace,
//                               userLat: userPosition.latitude,
//                               userLng: userPosition.longitude,
//                             ),
//                       ),
//                     );
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         backgroundColor: Colors.red,
//                         content: Text(
//                           "Parking space not available here, try another place",
//                           style: TextStyle(color: Colors.white),
//                         ),
//                       ),
//                     );
//                   }
//                 },
//                 child: Text("Book"),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor:
//                       parking.isBooked ? Colors.grey[600] : Colors.blue,
//                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 4),
//               OutlinedButton.icon(
//                 onPressed: () {
//                   openGoogleMaps(parkingSpace.latitude, parkingSpace.longitude);
//                 },
//                 icon: Icon(Icons.navigation),
//                 label: Text("Navigate"),
//                 style: OutlinedButton.styleFrom(
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFeatureItem(
//     IconData icon,
//     String label, {
//     VoidCallback? onTap,
//     Color? iconColor,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Column(
//         children: [
//           CircleAvatar(
//             radius: 18,
//             backgroundColor: Colors.blue.shade50,
//             child: Icon(icon, color: iconColor ?? Colors.blue),
//           ),
//           SizedBox(height: 6),
//           Text(
//             label,
//             textAlign: TextAlign.center,
//             style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showDistanceBottomSheet() {
//     double _currentRadius = _selectedRadius;
//     double _currentMinRating = _selectedMinRating;
//     showModalBottomSheet(
//       context: context,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             return Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     "Select Radius within you want Park",
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 20),
//                   Slider(
//                     value: _currentRadius,
//                     min: 0.1,
//                     max: 5.0,
//                     divisions: 49,
//                     label: "${_currentRadius.toStringAsFixed(1)} km",
//                     onChanged: (value) {
//                       setModalState(() {
//                         _currentRadius = value;
//                       });
//                     },
//                   ),
//                   Text(
//                     "${_currentRadius.toStringAsFixed(1)} km",
//                     style: TextStyle(fontSize: 16),
//                   ),
//                   SizedBox(height: 16),
//                   Text(
//                     "Minimum Rating",
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                   Slider(
//                     value: _currentMinRating,
//                     min: 0.0,
//                     max: 5.0,
//                     divisions: 10,
//                     label: "${_currentMinRating.toStringAsFixed(1)}+ ⭐",
//                     onChanged: (value) {
//                       setModalState(() {
//                         _currentMinRating = value;
//                       });
//                     },
//                   ),
//                   Text(
//                     "Min Rating: ${_currentMinRating.toStringAsFixed(1)}+ ⭐",
//                   ),
//                   SizedBox(height: 20),
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         _selectedRadius = _currentRadius;
//                         _selectedMinRating = _currentMinRating;
//                       });
//                       Navigator.pop(context);
//                     },
//                     child: Text("Apply"),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget showcaseWrapper({
//     required GlobalKey key,
//     required Widget child,
//     required String description,
//   }) {
//     return Showcase(
//       key: key,
//       description: description,
//       descTextStyle: TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.w500,
//         color: Colors.white,
//       ),
//       tooltipBackgroundColor: Colors.blueAccent,
//       child: child,
//     );
//   }

//   Widget _buildBottomNavBar() {
//     return BottomNavigationBar(
//       currentIndex: _selectedIndex,
//       selectedItemColor: Colors.blue,
//       unselectedItemColor: Colors.grey,
//       type: BottomNavigationBarType.fixed,
//       onTap: (index) {
//         setState(() {
//           _selectedIndex = index;
//         });
//         if (index == 1) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (_) => HistoryUserScreen()),
//           ).then((_) {
//             setState(() {
//               _selectedIndex = 0;
//             });
//           });
//         } else if (index == 2) {
//           _scaffoldKey.currentState?.openEndDrawer();
//         }
//       },
//       items: [
//         BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
//         BottomNavigationBarItem(
//           icon: showcaseWrapper(
//             key: _historyKey,
//             description: 'Check your past bookings here.',
//             child: Icon(Icons.history),
//           ),
//           label: "History",
//         ),
//         BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
//       ],
//     );
//   }
// }
