import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/destination_place.dart';
import '../models/parking_route.dart';
import 'parking_api_service.dart';

class ParkingRouteService {
  final ParkingApiService _apiService;

  ParkingRouteService({ParkingApiService? apiService})
      : _apiService = apiService ?? ParkingApiService();

  /// 백엔드 API를 통해 목적지 주변 실시간 주차장 조회
  Future<List<ParkingRouteResult>> fetchRoutes(
    DestinationPlace destination,
  ) async {
    return await _apiService.fetchNearbyParkingLots(destination);
  }

  static double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadius = 6371000.0;

    double radians(double degrees) => degrees * math.pi / 180;

    final lat1 = radians(startLatitude);
    final lat2 = radians(endLatitude);
    final deltaLat = radians(endLatitude - startLatitude);
    final deltaLon = radians(endLongitude - startLongitude);

    final a = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.pow(math.sin(deltaLon / 2), 2);
    final safeA = a.clamp(0.0, 1.0);
    final c = 2 *
        math.atan2(
          math.sqrt(safeA),
          math.sqrt(1.0 - safeA),
        );

    return earthRadius * c;
  }

  static Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('기기의 위치 서비스를 켜 주세요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('앱의 위치 권한을 허용해 주세요.');
    }

    return Geolocator.getCurrentPosition();
  }
}
