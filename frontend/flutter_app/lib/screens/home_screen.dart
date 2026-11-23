import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/destination_place.dart';
import '../models/parking_lot.dart';
import '../models/parking_route.dart';
import '../services/kakao_search_service.dart';
import '../services/parking_route_service.dart';
import '../widgets/destination_search_bar.dart';
import '../widgets/parking_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _kakaoRestApiKey = '3557fa79b5938254d737cb5762a9fa11';

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
      final results = await KakaoSearchService.searchPlaces(
        query: query,
        apiKey: _kakaoRestApiKey,
      );
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

    final results = ParkingRouteService.calculateRoutes(place);
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

  Future<void> _drawCarRouteToParkingLot(ParkingLot lot) async {
    if (_kakaoRestApiKey.isEmpty) {
      throw Exception('KAKAO_REST_API_KEY가 설정되지 않았습니다.');
    }

    final position = await ParkingRouteService.getCurrentPosition();
    final path = await KakaoSearchService.fetchCarRoutePath(
      apiKey: _kakaoRestApiKey,
      startLongitude: position.longitude,
      startLatitude: position.latitude,
      endLongitude: lot.longitude,
      endLatitude: lot.latitude,
    );

    final controller = _webViewController;
    if (controller == null || !_mapReady) {
      throw Exception('지도가 아직 준비되지 않았습니다.');
    }

    await controller.evaluateJavascript(
      source: 'window.drawCarRoute(${jsonEncode(path)});',
    );
  }

  Future<void> _drawWalkingRoute(ParkingLot lot) async {
    final destination = _selectedDestination;
    if (destination == null) {
      throw Exception('먼저 최종 목적지를 검색해 주세요.');
    }
    if (_kakaoRestApiKey.isEmpty) {
      throw Exception('KAKAO_REST_API_KEY가 설정되지 않았습니다.');
    }

    final path = await KakaoSearchService.fetchWalkRoutePath(
      apiKey: _kakaoRestApiKey,
      lot: lot,
      destination: destination,
    );

    final controller = _webViewController;
    if (controller == null || !_mapReady) {
      throw Exception('지도가 아직 준비되지 않았습니다.');
    }

    await controller.evaluateJavascript(
      source: 'window.drawWalkingRoute(${jsonEncode(path)});',
    );
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
              child: DestinationSearchBar(
                searchController: _searchController,
                isSearching: _isSearching,
                searchError: _searchError,
                searchResults: _searchResults,
                onSearch: _searchDestination,
                onSelectDestination: _selectDestination,
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ParkingDetailSheet(
                selectedDestination: _selectedDestination,
                routeResults: _routeResults,
                selectedParkingLotId: _selectedParkingLotId,
                isLoadingRoutes: _isLoadingRoutes,
                isLoadingSelectedRoute: _isLoadingSelectedRoute,
                routeError: _routeError,
                onSelectParkingLot: _selectParkingLot,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.extended(
                heroTag: 'currentLocation',
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final position =
                        await ParkingRouteService.getCurrentPosition();
                    if (!mounted) return;

                    final controller = _webViewController;
                    if (controller == null || !_mapReady) {
                      messenger.showSnackBar(
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
                    messenger.showSnackBar(
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
