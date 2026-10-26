
class ParkingLot {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int totalSpaces;
  final int availableSpaces;
  final String destinationName;
  final bool isMockAvailability;

  const ParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalSpaces,
    required this.availableSpaces,
    required this.destinationName,
    this.isMockAvailability = true,
  });

  double get occupancyRate {
    if (totalSpaces <= 0) return 0;
    return (totalSpaces - availableSpaces) / totalSpaces;
  }
}
