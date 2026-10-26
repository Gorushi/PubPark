import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'models/parking_lot.dart';
import 'data/mock_parking_data.dart';

void main() {
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주차장 찾기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class DestinationPlace {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const DestinationPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}



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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _kakaoRestApiKey =
  String.fromEnvironment('KAKAO_REST_API_KEY');

  final TextEditingController _searchController = TextEditingController();

  InAppWebViewController? _webViewController;

  bool _mapReady = false;
  bool _isSearching = false;
  bool _isLoadingRoutes = false;
  bool _isLoadingSelectedRoute = false;

  String? _searchError;
  String? _routeError;

  List<DestinationPlace> _searchResults = [];
  List<ParkingRouteResult> _routeResults = [];
  DestinationPlace? _selectedDestination;
  String? _selectedParkingLotId;



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _calculateDistance({
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

  List<ParkingRouteResult> _calculateRoutes(
      DestinationPlace destination,
      ) {
    final results = sampleParkingLots.map((lot) {
      final distance = _calculateDistance(
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

    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }

  Future<List<DestinationPlace>> _searchKakaoPlaces(String query) async {
    final uri = Uri.https(
      'dapi.kakao.com',
      '/v2/local/search/keyword.json',
      {'query': query, 'size': '10'},
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $_kakaoRestApiKey'},
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

  Future<void> _searchDestination() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchError = '검색할 장소를 입력해 주세요.';
        _searchResults = [];
      });
      return;
    }

    if (_kakaoRestApiKey.isEmpty) {
      setState(() {
        _searchError = 'KAKAO_REST_API_KEY가 설정되지 않았습니다.';
        _searchResults = [];
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final results = await _searchKakaoPlaces(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty) _searchError = '검색 결과가 없습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString();
      });
    }
  }

  void _selectDestination(DestinationPlace place) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedDestination = place;
      _searchController.text = place.name;
      _searchResults = [];
      _searchError = null;
      _routeError = null;
      _isLoadingRoutes = true;
      _routeResults = [];
      _selectedParkingLotId = null;
    });

    final results = _calculateRoutes(place);
    if (!mounted) return;

    setState(() {
      _routeResults = results;
      _isLoadingRoutes = false;
    });

    _updateMap();
  }

  Future<void> _updateMap() async {
    final controller = _webViewController;
    if (controller == null || !_mapReady) return;

    final destination = _selectedDestination;
    final payload = <String, dynamic>{
      'destination': destination == null
          ? null
          : {
        'name': destination.name,
        'address': destination.address,
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      },
      'parkingLots': _routeResults.map((result) {
        final lot = result.parkingLot;
        return {
          'id': lot.id,
          'name': lot.name,
          'address': lot.address,
          'latitude': lot.latitude,
          'longitude': lot.longitude,
          'totalSpaces': lot.totalSpaces,
          'availableSpaces': lot.availableSpaces,
          'distanceText': result.distanceText,
        };
      }).toList(),
    };

    await controller.evaluateJavascript(
      source: 'window.updateParkingData(${jsonEncode(payload)});',
    );
  }

  Future<Position> _getCurrentPosition() async {
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

  Future<void> _drawCarRouteToParkingLot(ParkingLot lot) async {
    if (_kakaoRestApiKey.isEmpty) {
      throw Exception('KAKAO_REST_API_KEY가 설정되지 않았습니다.');
    }

    final position = await _getCurrentPosition();
    final uri = Uri.https(
      'apis-navi.kakaomobility.com',
      '/v1/directions',
      {
        'origin': '${position.longitude},${position.latitude}',
        'destination': '${lot.longitude},${lot.latitude}',
        'summary': 'false',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'KakaoAK $_kakaoRestApiKey',
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

    final controller = _webViewController;
    if (controller == null || !_mapReady) {
      throw Exception('지도가 아직 준비되지 않았습니다.');
    }

    await controller.evaluateJavascript(
      source: 'window.drawCarRoute(${jsonEncode(path)});',
    );

    final summary = route['summary'] as Map<String, dynamic>;
    debugPrint('자동차 경로 표시 성공');
    debugPrint('자동차 거리: ${summary['distance']}m');
    debugPrint('자동차 시간: ${summary['duration']}초');
  }

  Future<void> _drawWalkingRoute(ParkingLot lot) async {
    final destination = _selectedDestination;
    if (destination == null) {
      throw Exception('먼저 최종 목적지를 검색해 주세요.');
    }
    if (_kakaoRestApiKey.isEmpty) {
      throw Exception('KAKAO_REST_API_KEY가 설정되지 않았습니다.');
    }

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
      headers: {'Authorization': 'KakaoAK $_kakaoRestApiKey'},
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

    final controller = _webViewController;
    if (controller == null || !_mapReady) {
      throw Exception('지도가 아직 준비되지 않았습니다.');
    }

    await controller.evaluateJavascript(
      source: 'window.drawWalkingRoute(${jsonEncode(path)});',
    );

    final properties = route['properties'] as Map<String, dynamic>?;
    if (properties != null) {
      debugPrint('도보 경로 표시 성공');
      debugPrint('도보 거리: ${properties['totalDistance']}m');
      debugPrint('도보 시간: ${properties['totalTime']}초');
    }
  }

  Future<void> _selectParkingLot(ParkingLot lot) async {
    final controller = _webViewController;
    if (controller == null || !_mapReady) return;

    setState(() {
      _selectedParkingLotId = lot.id;
      _isLoadingSelectedRoute = true;
      _routeError = null;
    });

    try {
      await controller.evaluateJavascript(
        source: 'window.focusParkingLot(${jsonEncode(lot.id)});',
      );

      await controller.evaluateJavascript(
        source: 'window.clearRoutes();',
      );

      await _drawCarRouteToParkingLot(lot);
      await _drawWalkingRoute(lot);
    } catch (e) {
      debugPrint('경로 표시 실패: $e');
      if (mounted) {
        setState(() => _routeError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('경로 표시 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSelectedRoute = false);
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          _searchError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_searchResults.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = _searchResults[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined),
            title: Text(place.name),
            subtitle: Text(
              place.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _selectDestination(place),
          );
        },
      ),
    );
  }

  Widget _buildParkingRouteList() {
    if (_selectedDestination == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('목적지를 검색하면 가까운 주차장을 보여 줍니다.'),
      );
    }

    if (_isLoadingRoutes) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _routeResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _routeResults[index];
        final lot = result.parkingLot;
        final selected = _selectedParkingLotId == lot.id;

        return ListTile(
          selected: selected,
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(lot.name),
          subtitle: Text(
            '직선거리 ${result.distanceText}\n'
                '잔여 ${lot.availableSpaces} / ${lot.totalSpaces}면',
          ),
          isThreeLine: true,
          trailing: _isLoadingSelectedRoute && selected
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.chevron_right),
          onTap: () => _selectParkingLot(lot),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InAppWebView(
                initialFile: 'assets/map.html',
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: true,
                  transparentBackground: false,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'onMapReady',
                    callback: (args) {
                      if (!mounted) return false;
                      setState(() => _mapReady = true);
                      _updateMap();
                      return true;
                    },
                  );
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('지도 로딩 오류: ${error.description}');
                },
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _searchDestination(),
                              decoration: const InputDecoration(
                                hintText: '목적지를 검색하세요',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _searchDestination,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                    ),
                    if (_isSearching ||
                        _searchError != null ||
                        _searchResults.isNotEmpty)
                      const Divider(height: 1),
                    _buildSearchResults(),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '주변 주차장',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_selectedDestination != null)
                              Text(
                                '${_routeResults.length}곳',
                                style: const TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (_routeError != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _routeError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Flexible(child: _buildParkingRouteList()),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
                        child: Text(
                          '테스트용 가상 주차장 데이터 · 후보 정렬은 직선거리 기준',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.extended(
                heroTag: 'currentLocation',
                onPressed: () async {
                  try {
                    final position = await _getCurrentPosition();
                    if (!mounted) return;

                    final controller = _webViewController;
                    if (controller == null || !_mapReady) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('지도가 아직 준비되지 않았습니다.'),
                        ),
                      );
                      return;
                    }

                    await controller.evaluateJavascript(
                      source: 'window.moveToCurrentLocation('
                          '${position.latitude},${position.longitude});',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('현재 위치를 가져오지 못했습니다: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text('현위치'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
