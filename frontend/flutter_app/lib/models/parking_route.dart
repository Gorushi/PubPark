import 'parking_lot.dart';

class ParkingRouteResult {
  final ParkingLot parkingLot;
  final double distanceMeters;

  const ParkingRouteResult({
    required this.parkingLot,
    required this.distanceMeters,
  });

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.round()} m';
  }
}
