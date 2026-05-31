import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/parking_lot.dart';

class ParkingApiService {
  static const String _baseUrl = 'https://api.example.com';
  static const Duration _timeout = Duration(seconds: 10);

  /// 주차장 목록 조회 (GET /api/parking-lots)
  Future<List<ParkingLot>> fetchParkingLots() async {
    final url = Uri.parse('$_baseUrl/api/parking-lots');

    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(
        _timeout,
        onTimeout: () {
          throw TimeoutException('서버 응답 시간 초과');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((json) => ParkingLot.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('인증 실패: 토큰을 확인해주세요.');
      } else if (response.statusCode == 404) {
        throw Exception('데이터를 찾을 수 없습니다.');
      } else if (response.statusCode >= 500) {
        throw Exception('서버 오류 (${response.statusCode}): 잠시 후 다시 시도해주세요.');
      } else {
        throw Exception('요청 실패: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
    } on SocketException {
      throw Exception('인터넷 연결을 확인해주세요.');
    }
  }

  /// 특정 주차장 조회 (GET /api/parking-lots/{id})
  Future<ParkingLot> fetchParkingLotById(String id) async {
    final url = Uri.parse('$_baseUrl/api/parking-lots/$id');

    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(_timeout, onTimeout: () {
        throw TimeoutException('서버 응답 시간 초과');
      });

      if (response.statusCode == 200) {
        return ParkingLot.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        throw Exception('해당 주차장을 찾을 수 없습니다.');
      } else {
        throw Exception('요청 실패: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
    } on SocketException {
      throw Exception('인터넷 연결을 확인해주세요.');
    }
  }
}