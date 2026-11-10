import 'dart:math' as math;

class MapPoint {
  const MapPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  factory MapPoint.fromJson(Map<String, dynamic> j) => MapPoint(
    (j['latitude'] as num).toDouble(),
    (j['longitude'] as num).toDouble(),
  );
  double distanceTo(MapPoint other) {
    double rad(double x) => x * math.pi / 180;
    final a =
        math.pow(math.sin(rad(other.latitude - latitude) / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(rad(other.longitude - longitude) / 2), 2);
    return 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a.clamp(0, 1)));
  }
}

class ParkingResult {
  const ParkingResult({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    required this.distance,
    required this.total,
    required this.available,
    required this.status,
    this.sourceUpdatedAt,
  });
  final String id, name, address, status;
  final MapPoint point;
  final double distance;
  final int? total, available;
  final DateTime? sourceUpdatedAt;
  String get badge => available == null
      ? '확인 불가'
      : available == 0
      ? '만차'
      : available! / (total ?? 1) < 0.2
      ? '혼잡'
      : '여유';
  factory ParkingResult.fromJson(Map<String, dynamic> j) => ParkingResult(
    id: j['id'],
    name: j['name'],
    address: j['address'],
    point: MapPoint.fromJson(j),
    distance: (j['distance_m'] as num).toDouble(),
    total: j['total_spaces'],
    available: j['available_spaces'],
    status: j['status'],
    sourceUpdatedAt: DateTime.tryParse(j['source_updated_at'] ?? ''),
  );
}

class DrivingRoute {
  const DrivingRoute({
    required this.points,
    required this.distance,
    required this.duration,
  });
  final List<MapPoint> points;
  final double distance;
  final Duration duration;
  factory DrivingRoute.fromJson(Map<String, dynamic> j) => DrivingRoute(
    points: (j['path'] as List)
        .map(
          (p) => MapPoint((p[1] as num).toDouble(), (p[0] as num).toDouble()),
        )
        .toList(),
    distance: (j['distance_m'] as num).toDouble(),
    duration: Duration(milliseconds: (j['duration_ms'] as num).toInt()),
  );
}

class SearchResult {
  const SearchResult({
    required this.destination,
    required this.destinationName,
    required this.parkings,
    required this.fetchedAt,
    this.route,
    this.notice,
  });
  final MapPoint destination;
  final String destinationName;
  final List<ParkingResult> parkings;
  final DateTime fetchedAt;
  final DrivingRoute? route;
  final String? notice;
  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
    destination: MapPoint.fromJson(j['destination']),
    destinationName: j['destination']['name'],
    parkings: (j['parkings'] as List)
        .map((p) => ParkingResult.fromJson(p))
        .toList(),
    fetchedAt: DateTime.parse(j['fetched_at']),
    notice: j['notice'],
    route: j['route'] == null ? null : DrivingRoute.fromJson(j['route']),
  );
}

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()}m'
    : '${(meters / 1000).toStringAsFixed(1)}km';
