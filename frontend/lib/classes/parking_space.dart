import 'package:parkeasy2/models/parking_space_model.dart';

class Parking {
  final String imagePath;
  final String name;
  final bool isBooked;
  final double price;
  final double distance;
  final double rating;

  Parking({
    required this.imagePath,
    required this.name,
    required this.isBooked,
    required this.price,
    required this.distance,
    required this.rating,
  });

  Parking copyWith({double? distance, double? rating}) => Parking(
    imagePath: imagePath,
    name: name,
    isBooked: isBooked,
    price: price,
    distance: distance ?? this.distance,
    rating: rating ?? this.rating,
  );
}

Parking parkingSpaceToParking(ParkingSpace space, double avgRating) {
  return Parking(
    imagePath:
        space.photoUrl.isNotEmpty
            ? space.photoUrl
            : 'assets/images/dummylot.jpg',
    name: space.address,
    isBooked: space.availableSpots == 0,
    price: space.pricePerHour,
    distance: 1.0,
    rating: avgRating,
  );
}
