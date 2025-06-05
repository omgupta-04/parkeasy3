import 'package:flutter/material.dart';
import '../../services/parking_service.dart';
import '../../models/booking_model.dart';
import '../../models/parking_space_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryUserScreen extends StatefulWidget {
  @override
  _HistoryUserScreenState createState() => _HistoryUserScreenState();
}

class _HistoryUserScreenState extends State<HistoryUserScreen> {
  final ParkingService _parkingService = ParkingService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parking History')),
      body: FutureBuilder<List<Booking>>(
        future:
            _userId == null
                ? Future.value([])
                : _parkingService.getBookingsByUser(_userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No records found'));
          }
          final bookings = snapshot.data!;
          final ongoing = bookings.where((b) => b.status == 'active').toList();
          final past = bookings.where((b) => b.status == 'completed').toList();

          return ListView(
            children: [
              if (ongoing.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Ongoing Bookings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...ongoing.map(
                  (booking) => ListTile(
                    title: Text('Parked at ${booking.parkingSpaceAddress}'),
                    subtitle: Text(
                      'From ${booking.startTime} to ${booking.endTime}\nStatus: ${booking.status}',
                    ),
                    trailing: Text('₹${booking.cost}'),
                  ),
                ),
              ],
              if (past.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Past Bookings',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...past.map(
                  (booking) => FutureBuilder<bool>(
                    future: _parkingService.hasUserReviewed(
                      booking.parkingSpaceId,
                      _userId!,
                    ),
                    builder: (context, reviewSnapshot) {
                      final hasReviewed = reviewSnapshot.data ?? false;
                      return ListTile(
                        title: Text('Parked at ${booking.parkingSpaceAddress}'),
                        subtitle: Text(
                          'From ${booking.startTime} to ${booking.endTime}\nStatus: ${booking.status}',
                        ),
                        trailing:
                            hasReviewed
                                ? Text(
                                  'Reviewed',
                                  style: TextStyle(color: Colors.green),
                                )
                                : ElevatedButton(
                                  onPressed: () async {
                                    double tempRating = 3.0;
                                    String comment = '';
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
                                              Slider(
                                                value: tempRating,
                                                min: 0,
                                                max: 5,
                                                divisions: 10,
                                                label: tempRating.toString(),
                                                onChanged: (value) {
                                                  tempRating = value;
                                                  (context as Element)
                                                      .markNeedsBuild();
                                                },
                                              ),
                                              TextField(
                                                decoration: InputDecoration(
                                                  labelText: 'Comment',
                                                ),
                                                onChanged:
                                                    (val) => comment = val,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    null,
                                                  ),
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
                                      final user =
                                          FirebaseAuth.instance.currentUser!;
                                      await _parkingService
                                          .addReviewToParkingSpace(
                                            booking.parkingSpaceId,
                                            Review(
                                              userId: user.uid,
                                              userName:
                                                  user.displayName ??
                                                  'Anonymous',
                                              rating: result['rating'],
                                              comment: result['comment'],
                                              date: DateTime.now(),
                                            ),
                                          );
                                      setState(() {});
                                    }
                                  },
                                  child: Text('Add Review'),
                                ),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
