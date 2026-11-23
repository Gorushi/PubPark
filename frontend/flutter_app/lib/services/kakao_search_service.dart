import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/destination_place.dart';
import '../models/parking_lot.dart';

class KakaoSearchService {
  static Future<List<DestinationPlace>> searchPlaces({
    required String query,
    required String apiKey,
  }) async {
    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/search/keyword.json',
      {'query': query, 'size': '10'},
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $apiKey'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        '장소 검색 실패: HTTP ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = data['documents'] as List<dynamic>;

    return documents.map((item) {
      final place = item as Map<String, dynamic>;
      final roadAddress = (place['road_address_name'] as String?)?.trim();
      final address = roadAddress != null && roadAddress.isNotEmpty
          ? roadAddress
          : (place['address_name'] as String? ?? '');

      return DestinationPlace(
        name: place['place_name'] as String? ?? '이름 없는 장소',
        address: address,
        longitude: double.parse(place['x'].toString()),
        latitude: double.parse(place['y'].toString()),
      );
    }).toList();
  }

  static Future<List<List<double>>> fetchCarRoutePath({
    required String apiKey,
    required double startLongitude,
    required double startLatitude,
    required double endLongitude,
    required double endLatitude,
  }) async {
    final uri = Uri.https(
      'apis-navi.kakaomobility.com',
      '/v1/directions',
      {
        'origin': '$startLongitude,$startLatitude',
        'destination': '$endLongitude,$endLatitude',
        'summary': 'false',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'KakaoAK $apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        '자동차 경로 요청 실패: HTTP ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw Exception('자동차 경로 결과가 없습니다.');
    }

    final route = routes.first as Map<String, dynamic>;
    if (route['result_code'] != 0) {
      throw Exception(
        '자동차 경로 탐색 실패: ${route['result_code']} / ${route['result_msg']}',
      );
    }

    final path = <List<double>>[];
    for (final section in route['sections'] as List<dynamic>) {
      for (final road in section['roads'] as List<dynamic>) {
        final vertexes = road['vertexes'] as List<dynamic>;
        for (int i = 0; i + 1 < vertexes.length; i += 2) {
          path.add([
            (vertexes[i] as num).toDouble(),
            (vertexes[i + 1] as num).toDouble(),
          ]);
        }
      }
    }

    if (path.length < 2) throw Exception('자동차 경로 좌표가 없습니다.');

    final summary = route['summary'] as Map<String, dynamic>;
    debugPrint('자동차 경로 표시 성공: 거리 ${summary['distance']}m, 시간 ${summary['duration']}초');

    return path;
  }

  static Future<List<List<double>>> fetchWalkRoutePath({
    required String apiKey,
    required ParkingLot lot,
    required DestinationPlace destination,
  }) async {
    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/routing/walk',
      {
        'start_x': lot.longitude.toString(),
        'start_y': lot.latitude.toString(),
        'end_x': destination.longitude.toString(),
        'end_y': destination.latitude.toString(),
        'route_mode': 'BROAD_FIRST',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $apiKey'},
    );

    debugPrint('도보 경로 HTTP 상태: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception(
        '도보 경로 요청 실패: HTTP ${response.statusCode}\n${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      throw Exception('도보 경로 탐색 실패: ${data['status']}');
    }

    final route = data['route'] as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>;
    final path = <List<double>>[];

    for (final leg in legs) {
      for (final step in leg['steps'] as List<dynamic>) {
        final pathData = step['path'] as Map<String, dynamic>;
        final points = pathData['points'] as List<dynamic>;
        for (final point in points) {
          final coordinates = point as List<dynamic>;
          if (coordinates.length < 2) continue;
          path.add([
            (coordinates[0] as num).toDouble(),
            (coordinates[1] as num).toDouble(),
          ]);
        }
      }
    }

    if (path.length < 2) throw Exception('도보 경로 좌표가 충분하지 않습니다.');

    final properties = route['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      debugPrint('도보 경로 표시 성공: 거리 ${properties['totalDistance']}m, 시간 ${properties['totalTime']}초');
    }

    return path;
  }
}
