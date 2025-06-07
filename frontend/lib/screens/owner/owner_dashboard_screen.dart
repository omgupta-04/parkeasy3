import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:parkeasy2/models/parking_space_model.dart';
import 'package:parkeasy2/screens/fun.dart';
import 'package:parkeasy2/services/parking_service.dart';
import 'package:parkeasy2/widgets/shimmer_owner_dashboard.dart';
import 'add_parking_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';
import 'package:showcaseview/showcaseview.dart';
import 'owner_profile_screen.dart';
import 'slot_analytics_screen.dart';
import 'package:provider/provider.dart';
import '/providers/slot_provider.dart';

class OwnerDashboardScreen extends StatefulWidget {
  @override
  _OwnerDashboardScreenState createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final ParkingService _parkingService = ParkingService();
  String? _ownerId;
  User? _user;
  bool isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final LocalAuthentication auth = LocalAuthentication();
  final GlobalKey _profileAvatarKey = GlobalKey();
  final GlobalKey _analyticsKey = GlobalKey();
  final GlobalKey _editKey = GlobalKey();
  File? _profileImage;
  // String _userName = '';
  // String _userEmail = '';
  //
  //
  // Future<void> _loadOwnerDataFromPrefs() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     _userName = prefs.getString('owner_name') ?? 'Parking Owner';
  //     _userEmail = prefs.getString('owner_email') ?? 'owner@example.com';
  //   });
  // }

  // Common text styles
  final TextStyle headerStyle = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  final TextStyle subtitleStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.grey[800],
  );

  final TextStyle smallGreyStyle = GoogleFonts.poppins(
    fontSize: 12,
    color: Colors.grey[600],
  );

  final TextStyle buttonTextStyle = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  Widget showcaseWrapper({
    required GlobalKey key,
    required Widget child,
    required String description,
  }) {
    return Showcase(
      key: key,
      description: description,
      descTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      tooltipBackgroundColor: Colors.blueAccent,
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
    _checkAndShowShowcase();
    _loadProfileImage();
    _user = FirebaseAuth.instance.currentUser;
    _ownerId = _user?.uid;
  }

  void _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('owner_profile_image');
    if (imagePath != null && mounted) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _checkAndShowShowcase() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenShowcase = prefs.getBool('hasSeenShowcase') ?? false;

    // For now, changed to always show showcase. Change to !hasSeenShowcase to show once.
    if (!hasSeenShowcase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShowCaseWidget.of(
          context,
        ).startShowCase([_profileAvatarKey, _analyticsKey, _editKey]);
      });
      await prefs.setBool('hasSeenShowcase', true);
    }
  }

  Future<bool> _authenticate() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication not available'),
          ),
        );
        return false;
      }
      bool isAuthenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to proceed',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Authentication error: $e')));
      return false;
    }
  }

  void _showDeleteConfirmationDialog(String spaceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 300),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Confirm Deletion',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text('Are you sure you want to delete this slot?'),
              actions: [
                TextButton(
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.blueAccent),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deletion Cancelled'),
                        backgroundColor: Colors.blueGrey,
                      ),
                    );
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Delete'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _parkingService.deleteParkingSpace(spaceId);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Slot deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(ParkingSpace space) {
    final _priceController = TextEditingController(
      text: space.pricePerHour.toString(),
    );
    final _slotsController = TextEditingController(
      text: space.availableSpots.toString(),
    );
    final _upiController = TextEditingController(text: space.upiId);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Edit",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit Parking Space', style: headerStyle),
                  const SizedBox(height: 20),
                  _buildStyledField(
                    'Price per hour',
                    _priceController,
                    TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    'Available spots',
                    _slotsController,
                    TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    'Owner UPI ID',
                    _upiController,
                    TextInputType.text,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final newPrice =
                              double.tryParse(_priceController.text) ??
                              space.pricePerHour;
                          final newSlots =
                              int.tryParse(_slotsController.text) ??
                              space.availableSpots;
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: buttonTextStyle,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedValue =
            Curves.easeInOutBack.transform(animation.value) - 1.0;
        return Transform(
          transform: Matrix4.translationValues(0.0, curvedValue * -50, 0.0),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
    );
  }

  Widget _buildStyledField(
    String label,
    TextEditingController controller,
    TextInputType inputType,
  ) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: subtitleStyle,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[100],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }

  void _showProfileDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile',
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: AlertDialog(
              title: Text('Profile', style: headerStyle),
              content:
                  _user == null
                      ? Text('No user info available.', style: subtitleStyle)
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
                          Text(
                            'Name: ${_user!.displayName ?? "N/A"}',
                            style: subtitleStyle,
                          ),
                          Text(
                            'Email: ${_user!.email ?? "N/A"}',
                            style: subtitleStyle,
                          ),
                          SizedBox(height: 12),
                          Text('UID: ${_user!.uid}', style: smallGreyStyle),
                        ],
                      ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Logged out successfully!',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Logout',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Parking',
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: AlertDialog(
                  title: Text('Add Parking Space', style: headerStyle),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(labelText: 'Address'),
                          style: subtitleStyle,
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Price per hour',
                          ),
                          style: subtitleStyle,
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _slotsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Available spots',
                          ),
                          style: subtitleStyle,
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _upiController,
                          decoration: InputDecoration(
                            labelText: 'Owner UPI ID',
                          ),
                          style: subtitleStyle,
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
                                    LocationPermission permission =
                                        await Geolocator.requestPermission();
                                    Position pos =
                                        await Geolocator.getCurrentPosition(
                                          desiredAccuracy:
                                              LocationAccuracy.high,
                                        );
                                    _latController.text =
                                        pos.latitude.toString();
                                    _lngController.text =
                                        pos.longitude.toString();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Location error: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            Text('Use current location', style: subtitleStyle),
                          ],
                        ),
                        SizedBox(height: 12),

                        // Animated crossfade between manual inputs and display
                        AnimatedCrossFade(
                          firstChild: Column(
                            children: [
                              TextField(
                                controller: _latController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                ),
                                style: subtitleStyle,
                              ),
                              SizedBox(height: 8),
                              TextField(
                                controller: _lngController,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                ),
                                style: subtitleStyle,
                              ),
                            ],
                          ),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latitude: ${_latController.text}',
                                style: subtitleStyle,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Longitude: ${_lngController.text}',
                                style: subtitleStyle,
                              ),
                            ],
                          ),
                          crossFadeState:
                              useCurrentLocation
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                          duration: Duration(milliseconds: 350),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.grey[700]),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final address = _addressController.text.trim();
                        final price =
                            double.tryParse(_priceController.text) ?? 0.0;
                        final slots = int.tryParse(_slotsController.text) ?? 0;
                        final lat = double.tryParse(_latController.text) ?? 0.0;
                        final lng = double.tryParse(_lngController.text) ?? 0.0;
                        final upiId = _upiController.text.trim();

                        if (address.isEmpty ||
                            price <= 0 ||
                            slots <= 0 ||
                            upiId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please fill all fields correctly.',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
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
                          photoUrl: '',
                        );
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        textStyle: buttonTextStyle,
                      ),
                      child: Text('Add'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(scale: curvedAnimation, child: child);
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
            _DashboardStat(
              label: "Spaces",
              value: spaces.length.toString(),
              icon: Icons.local_parking,
              textStyle: subtitleStyle,
            ),
            _DashboardStat(
              label: "Slots",
              value: totalSlots.toString(),
              icon: Icons.event_seat,
              textStyle: subtitleStyle,
            ),
            _DashboardStat(
              label: "Reviews",
              value: totalReviews.toString(),
              icon: Icons.star,
              textStyle: subtitleStyle,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: ShimmerOwnerDashboard());
    }
    return Builder(
      builder:
          (context) => Scaffold(
            key: _scaffoldKey,
            endDrawer: _buildEndDrawer(context),
            appBar: AppBar(
              leading: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.manage_accounts,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
              title: const Text(
                'Owner Dashboard',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 1,
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
                            description:
                                'Tap here to open your profile and settings.',
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
                                          fit: BoxFit.cover,
                                          width: 36,
                                          height: 36,
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
            floatingActionButton: FancyFAB(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 600),
                    pageBuilder:
                        (_, animation, __) => FadeTransition(
                          opacity: animation,
                          child: AddParkingScreen(ownerId: _ownerId!),
                        ),
                  ),
                );

                if (result != null && result is Map) {
                  print('New parking slot data: $result');

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Parking slot added successfully'),
                    ),
                  );
                  setState(() {}); // Refresh UI if needed
                }
              },
            ),

            body:
                _ownerId == null
                    ? Center(child: Text('Not logged in', style: headerStyle))
                    : StreamBuilder<List<ParkingSpace>>(
                      stream: _parkingService.getParkingSpacesByOwnerStream(
                        _ownerId!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              'No records found',
                              style: subtitleStyle,
                            ),
                          );
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
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Left Image or Icon
                                          space.photoUrl.isNotEmpty
                                              ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  space.photoUrl,
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                              : const Icon(
                                                Icons.local_parking,
                                                size: 40,
                                                color: Colors.blue,
                                              ),

                                          const SizedBox(width: 10),

                                          // Middle Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  space.address,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '₹${space.pricePerHour}/hr • ${space.availableSpots} slots',
                                                  style: subtitleStyle,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.star,
                                                      color: Colors.amber,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      space.reviews.isNotEmpty
                                                          ? (space.reviews
                                                                      .map(
                                                                        (r) =>
                                                                            r.rating,
                                                                      )
                                                                      .reduce(
                                                                        (
                                                                          a,
                                                                          b,
                                                                        ) =>
                                                                            a +
                                                                            b,
                                                                      ) /
                                                                  space
                                                                      .reviews
                                                                      .length)
                                                              .toStringAsFixed(
                                                                1,
                                                              )
                                                          : 'No rating',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '(${space.reviews.length} reviews)',
                                                      style: smallGreyStyle,
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 4),
                                                Text(
                                                  'UPI: ${space.upiId}',
                                                  style: smallGreyStyle,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Trailing buttons
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              idx == 0
                                                  ? showcaseWrapper(
                                                    key: _editKey,
                                                    description:
                                                        'Tap here to edit this parking slot.',
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        Icons.edit,
                                                        color: Colors.blue,
                                                      ),
                                                      onPressed: () async {
                                                        bool isAuth =
                                                            await _authenticate();
                                                        if (isAuth) {
                                                          _showEditDialog(
                                                            space,
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  )
                                                  : IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      color: Colors.blue,
                                                    ),
                                                    onPressed: () async {
                                                      bool isAuth =
                                                          await _authenticate();
                                                      if (isAuth) {
                                                        _showEditDialog(space);
                                                      }
                                                    },
                                                  ),

                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () async {
                                                  bool isAuth =
                                                      await _authenticate();
                                                  if (isAuth) {
                                                    _showDeleteConfirmationDialog(
                                                      space.id,
                                                    );
                                                  }
                                                },
                                              ),
                                              const SizedBox(height: 8),
                                              idx == 0
                                                  ? showcaseWrapper(
                                                    key:
                                                        _analyticsKey, // <-- make sure this GlobalKey is defined
                                                    description:
                                                        'Tap here to view analytics of this parking slot.',
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder:
                                                                (
                                                                  context,
                                                                ) => ChangeNotifierProvider(
                                                                  create:
                                                                      (_) =>
                                                                          SlotProvider(),
                                                                  child:
                                                                      const SlotAnalyticsScreen(),
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                      child: Row(
                                                        children: const [
                                                          Icon(
                                                            Icons.bar_chart,
                                                            size: 18,
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            'View Analytics',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                  : GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                context,
                                                              ) => ChangeNotifierProvider(
                                                                create:
                                                                    (_) =>
                                                                        SlotProvider(),
                                                                child:
                                                                    const SlotAnalyticsScreen(),
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    child: Row(
                                                      children: const [
                                                        Icon(
                                                          Icons.bar_chart,
                                                          size: 18,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          'View Analytics',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
          ),
    );
  }

  Widget _buildEndDrawer(BuildContext context) {
    return Drawer(
      width: 240,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: 1.0,
                    duration: Duration(milliseconds: 400),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey[200],
                      backgroundImage:
                          _profileImage != null
                              ? FileImage(_profileImage!)
                              : AssetImage('assets/images/profile_default.jpg')
                                  as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    duration: Duration(milliseconds: 400),
                    opacity: 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Name: ${_user!.displayName ?? "N/A"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.email,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 150,
                                  ),
                                  child: Text(
                                    'Email: ${_user!.email ?? "N/A"}',
                                    style: const TextStyle(color: Colors.black),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                'UID: ${_user!.uid}',
                                style: smallGreyStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider().animate().fadeIn(duration: 400.ms),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage('assets/images/blank_dp.png'),
                radius: 11,
              ),
              title: Text("Profile"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => OwnerProfileScreen(
                          name: _user?.displayName ?? 'N/A',
                          email: _user?.email ?? 'N/A',
                          uid: _user!.uid,
                        ),
                  ),
                );
              },
            ).animate().slideX(begin: -0.2).fadeIn(duration: 300.ms),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                AppSettings.openAppSettings();
              },
            ).animate().slideX(begin: -0.2).fadeIn(duration: 350.ms),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Logged out successfully!',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              },
            ).animate().slideX(begin: -0.2).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final TextStyle textStyle;

  const _DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        SizedBox(height: 2),
        Text(label, style: textStyle),
      ],
    );
  }
}
