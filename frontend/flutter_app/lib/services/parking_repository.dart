import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parking_search.dart';

abstract class ParkingRepository {
  bool get isDemo;
  Future<SearchResult> search(String query, MapPoint? origin);
  Future<SearchResult> refresh(SearchResult current);
  void dispose() {}
}

class HttpParkingRepository extends ParkingRepository {
  HttpParkingRepository(this.baseUrl);
  final String baseUrl;
  final _client = http.Client();
  @override
  bool get isDemo => false;
  Future<SearchResult> _post(String path, Map<String, dynamic> data) async {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      throw Exception('API_BASE_URL에 서버 주소를 설정해주세요.');
    }
    final response = await _client
        .post(
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 90));
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['error'] ?? '서버에 연결하지 못했습니다.');
    }
    return SearchResult.fromJson(body);
  }

  @override
  Future<SearchResult> search(String query, MapPoint? origin) =>
      _post('/api/search', {'query': query, 'origin': origin?.toJson()});
  @override
  Future<SearchResult> refresh(SearchResult current) => _post('/api/nearby', {
    'destination': {
      ...current.destination.toJson(),
      'name': current.destinationName,
    },
  });
  @override
  void dispose() => _client.close();
}

class MockParkingRepository extends ParkingRepository {
  static const origin = MapPoint(37.5596, 126.9753);
  @override
  bool get isDemo => true;
  @override
  Future<SearchResult> search(String query, MapPoint? origin) async {
    // Explicit, deterministic demo destinations. Never claim arbitrary addresses resolved.
    final MapPoint point;
    final String name;
    if (query.contains('종로') || query.contains('세종')) {
      point = const MapPoint(37.5725, 126.9769);
      name = '세종문화회관';
    } else if (query.contains('강남')) {
      point = const MapPoint(37.4979, 127.0276);
      name = '강남역';
    } else if (query.contains('시청') || query.contains('세종대로 110')) {
      point = const MapPoint(37.5666, 126.9784);
      name = '서울시청';
    } else {
      throw Exception('데모에서는 서울시청, 세종문화회관, 강남역을 검색할 수 있어요.');
    }
    final from = origin ?? MockParkingRepository.origin;
    final route = DrivingRoute(
      points: [
        from,
        MapPoint(
          from.latitude + (point.latitude - from.latitude) * 0.35,
          from.longitude,
        ),
        MapPoint(
          from.latitude + (point.latitude - from.latitude) * 0.35,
          point.longitude,
        ),
        point,
      ],
      distance: from.distanceTo(point) * 1.3,
      duration: Duration(seconds: (from.distanceTo(point) * 1.3 / 6).round()),
    );
    return _result(point, name, route);
  }

  SearchResult _result(MapPoint point, String name, DrivingRoute? route) {
    final now = DateTime.now();
    const names = [
      '시청광장',
      '서소문',
      '정동길',
      '무교동',
      '청계천',
      '세종로',
      '광화문',
      '종묘',
      '을지로',
      '남산',
      '회현',
      '충무로',
    ];
    final lots = List.generate(12, (i) {
      final location = MapPoint(
        point.latitude + (i % 2 == 0 ? 1 : -1) * (i + 1) * 0.0007,
        point.longitude + (i % 3 - 1) * (i + 1) * 0.0006,
      );
      final available = i == 4
          ? null
          : i == 2
          ? 0
          : i == 1
          ? 8
          : 42 + i * 3;
      return ParkingResult(
        id: 'demo-$i',
        name: '${names[i]} 시영주차장',
        address: '서울특별시 · $name 인근 (샘플 주소)',
        point: location,
        distance: point.distanceTo(location),
        total: 100 + i * 10,
        available: available,
        status: available == null ? 'unlinked' : 'ok',
        sourceUpdatedAt: available == null ? null : now,
      );
    })..sort((a, b) => a.distance.compareTo(b.distance));
    return SearchResult(
      destination: point,
      destinationName: name,
      parkings: lots.take(10).toList(),
      fetchedAt: now,
      route: route,
    );
  }

  @override
  Future<SearchResult> refresh(SearchResult current) async =>
      _result(current.destination, current.destinationName, current.route);
}
