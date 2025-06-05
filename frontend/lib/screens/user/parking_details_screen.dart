import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/parking_space_model.dart';
import '../../models/booking_model.dart';
import '../../services/parking_service.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final ParkingSpace parkingSpace;
  final double userLat;
  final double userLng;

  const ParkingDetailsScreen({
    Key? key,
    required this.parkingSpace,
    required this.userLat,
    required this.userLng,
  }) : super(key: key);

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  final ParkingService _parkingService = ParkingService();
  bool _isBooking = false;
  int _selectedHours = 1;

  double calculateDistanceKm(
    double userLat,
    double userLng,
    double destLat,
    double destLng,
  ) {
    return Geolocator.distanceBetween(userLat, userLng, destLat, destLng) /
        1000.0;
  }

  Future<void> _bookParking() async {
    setState(() => _isBooking = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('You must be logged in to book.')));
      setState(() => _isBooking = false);
      return;
    }

    final totalAmount = widget.parkingSpace.pricePerHour * _selectedHours;

    // TODO: Add your payment logic here (UPI, etc.)
    // For demo, we'll assume payment is always successful:

    final now = DateTime.now();
    final endTime = now.add(Duration(hours: _selectedHours));
    final booking = Booking(
      id: '', // Firebase will set this
      userId: user.uid,
      parkingSpaceId: widget.parkingSpace.id,
      parkingSpaceAddress: widget.parkingSpace.address,
      startTime: now,
      endTime: endTime,
      cost: totalAmount,
      status: 'active',
    );
    await _parkingService.addBooking(booking);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking added to your ongoing history!')),
    );

    setState(() => _isBooking = false);
    Navigator.pop(context); // Go back to home or history
  }

  @override
  Widget build(BuildContext context) {
    final parkingSpace = widget.parkingSpace;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final distanceKm = calculateDistanceKm(
      widget.userLat,
      widget.userLng,
      parkingSpace.latitude,
      parkingSpace.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(parkingSpace.address),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            parkingSpace.photoUrl.isNotEmpty
                ? Image.network(
                  parkingSpace.photoUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
                : Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[300],
                  child: Icon(
                    Icons.local_parking,
                    size: 80,
                    color: Colors.grey[700],
                  ),
                ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  parkingSpace.availableSpots > 0
                      ? Icons.circle
                      : Icons.circle_outlined,
                  color:
                      parkingSpace.availableSpots > 0
                          ? Colors.green
                          : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  parkingSpace.availableSpots > 0 ? "Empty" : "Full",
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        parkingSpace.availableSpots > 0
                            ? Colors.green
                            : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoIcon(
                  icon: Icons.attach_money,
                  label: '${parkingSpace.pricePerHour} Rs/hr',
                ),
                _InfoIcon(
                  icon: Icons.location_on,
                  label: '${distanceKm.toStringAsFixed(2)} km',
                ),
                FutureBuilder<List<Review>>(
                  future: _parkingService.getReviewsForParkingSpace(
                    parkingSpace.id,
                  ),
                  builder: (context, snapshot) {
                    double avgRating = 0.0;
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      avgRating =
                          snapshot.data!
                              .map((r) => r.rating)
                              .reduce((a, b) => a + b) /
                          snapshot.data!.length;
                    }
                    return _InfoIcon(
                      icon: Icons.star,
                      label:
                          snapshot.hasData && snapshot.data!.isNotEmpty
                              ? '${avgRating.toStringAsFixed(1)} ⭐'
                              : '0.0 ⭐',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- PAYMENT/TIMER/BOOKING SECTION ---
            Text(
              "Select Duration (hours):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            DropdownButton<int>(
              value: _selectedHours,
              items:
                  List.generate(12, (i) => i + 1)
                      .map((h) => DropdownMenuItem(value: h, child: Text('$h')))
                      .toList(),
              onChanged: (val) => setState(() => _selectedHours = val ?? 1),
            ),
            const SizedBox(height: 24),
            _isBooking
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                  onPressed: _bookParking,
                  icon: Icon(Icons.check_circle),
                  label: Text(
                    "Book Now for ₹${(parkingSpace.pricePerHour * _selectedHours).toStringAsFixed(2)}",
                  ),
                ),
            const SizedBox(height: 24),

            // --- USER REVIEW STAR ROW ---
            FutureBuilder<List<Review>>(
              future: _parkingService.getReviewsForParkingSpace(
                parkingSpace.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reviews = snapshot.data ?? [];
                final avgRating =
                    reviews.isEmpty
                        ? 0.0
                        : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                            reviews.length;
                return Row(
                  children: [
                    Text(
                      "User Rating: ",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...List.generate(
                      5,
                      (index) => Icon(
                        index < avgRating.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(avgRating.toStringAsFixed(1)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              "User Feedback",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            FutureBuilder<List<Review>>(
              future: _parkingService.getReviewsForParkingSpace(
                parkingSpace.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final reviews = snapshot.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reviews.isEmpty)
                      Text(
                        'No reviews yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ...reviews.map(
                      (review) => ListTile(
                        title: Text(review.userName),
                        subtitle: Text(review.comment),
                        trailing: Text('${review.rating} ⭐'),
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: _parkingService.hasUserReviewed(
                        parkingSpace.id,
                        userId,
                      ),
                      builder: (context, userReviewedSnapshot) {
                        if (userReviewedSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SizedBox.shrink();
                        }
                        if (userReviewedSnapshot.data == false) {
                          double tempRating = 3.0;
                          String comment = '';
                          return ElevatedButton(
                            onPressed: () async {
                              final result = await showDialog<
                                Map<String, dynamic>
                              >(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('Add Review'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Rate this parking:'),
                                        StatefulBuilder(
                                          builder: (context, setModalState) {
                                            return Slider(
                                              value: tempRating,
                                              min: 0,
                                              max: 5,
                                              divisions: 10,
                                              label: tempRating.toString(),
                                              onChanged: (value) {
                                                setModalState(() {
                                                  tempRating = value;
                                                });
                                              },
                                            );
                                          },
                                        ),
                                        TextField(
                                          decoration: InputDecoration(
                                            labelText: 'Comment',
                                          ),
                                          onChanged: (val) => comment = val,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, null),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, {
                                              'rating': tempRating,
                                              'comment': comment,
                                            }),
                                        child: Text('Submit'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (result != null) {
                                final user = FirebaseAuth.instance.currentUser!;
                                await _parkingService.addReviewToParkingSpace(
                                  parkingSpace.id,
                                  Review(
                                    userId: user.uid,
                                    userName: user.displayName ?? 'Anonymous',
                                    rating: result['rating'],
                                    comment: result['comment'],
                                    date: DateTime.now(),
                                  ),
                                );
                                setState(() {});
                              }
                            },
                            child: Text('Add Review'),
                          );
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
