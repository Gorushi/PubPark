import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/destination_place.dart';
import '../models/parking_lot.dart';
import '../models/parking_route.dart';
import 'parking_route_service.dart';

class ParkingApiService {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000',
  );

  final String baseUrl;
  final http.Client _client;

  ParkingApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? _defaultApiBaseUrl,
        _client = client ?? http.Client();

  /// POST /api/nearby: 백엔드 서버에 목적지 주변 주차장 요청
  Future<List<ParkingRouteResult>> fetchNearbyParkingLots(
    DestinationPlace destination,
  ) async {
    final url = Uri.parse('$baseUrl/api/nearby');

    final payload = {
      'destination': {
        'name': destination.name,
        'address': destination.address,
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      }
    };

    final response = await _client
        .post(
          url,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final parkings = data['parkings'] as List<dynamic>? ?? [];

      return parkings.map((item) {
        final lotJson = item as Map<String, dynamic>;
        final lot = ParkingLot.fromJson(
          lotJson,
          destinationName: destination.name,
        );

        final distance = (lotJson['distance_m'] as num?)?.toDouble() ??
            ParkingRouteService.calculateDistance(
              startLatitude: lot.latitude,
              startLongitude: lot.longitude,
              endLatitude: destination.latitude,
              endLongitude: destination.longitude,
            );

        return ParkingRouteResult(
          parkingLot: lot,
          distanceMeters: distance,
        );
      }).toList();
    } else {
      throw Exception('백엔드 응답 오류: HTTP ${response.statusCode}');
    }
  }
}
