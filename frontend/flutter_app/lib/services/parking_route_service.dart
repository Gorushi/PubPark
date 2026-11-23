import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/destination_place.dart';
import '../models/parking_route.dart';
import 'parking_api_service.dart';

enum SortOption {
  availability('여유순'),
  optimal('최적순'),
  distance('직선거리순');

  final String label;
  const SortOption(this.label);
}

class ParkingRouteService {
  final ParkingApiService _apiService;

  ParkingRouteService({ParkingApiService? apiService})
      : _apiService = apiService ?? ParkingApiService();

  /// 백엔드 API를 통해 목적지 주변 실시간 주차장 조회 및 정렬
  Future<List<ParkingRouteResult>> fetchRoutes(
    DestinationPlace destination, {
    SortOption sortOption = SortOption.availability,
  }) async {
    final results = await _apiService.fetchNearbyParkingLots(destination);
    return sortResults(results, sortOption);
  }

  /// 정렬 옵션에 맞춰 주차장 목록 정렬
  static List<ParkingRouteResult> sortResults(
    List<ParkingRouteResult> results,
    SortOption sortOption,
  ) {
    final sorted = List<ParkingRouteResult>.from(results);
    switch (sortOption) {
      case SortOption.availability:
        sorted.sort((a, b) {
          final comp = (b.parkingLot.availableSpaces ?? -1)
              .compareTo(a.parkingLot.availableSpaces ?? -1);
          if (comp != 0) return comp;
          return a.distanceMeters.compareTo(b.distanceMeters);
        });
        break;
      case SortOption.optimal:
        sorted.sort((a, b) {
          // 최적 점수 계산: (잔여 주차면수 * 20) - 직선거리(m)
          final availableA = a.parkingLot.availableSpaces;
          final availableB = b.parkingLot.availableSpaces;
          final group = ((availableB ?? -1) > 0 ? 2 : availableB == 0 ? 1 : 0)
              .compareTo((availableA ?? -1) > 0 ? 2 : availableA == 0 ? 1 : 0);
          if (group != 0) return group;
          final scoreA = (availableA ?? 0) * 20 - a.distanceMeters;
          final scoreB = (availableB ?? 0) * 20 - b.distanceMeters;
          return scoreB.compareTo(scoreA);
        });
        break;
      case SortOption.distance:
        sorted.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        break;
    }
    return sorted;
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
