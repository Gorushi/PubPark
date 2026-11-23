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

  final GlobalKey _parkingSheetKey = GlobalKey();
  InAppWebViewController? _webViewController;
  SortOption _sortOption = SortOption.availability;
  int _routeRequest = 0;
  bool _parkingListExpanded = false;
  bool _showWalkingOnly = false;
  DateTime? _destinationArrival;
  int? _arrivalAvailability;

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

  final ParkingRouteService _parkingRouteService = ParkingRouteService();

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

  Future<void> _selectDestination(DestinationPlace place) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _routeRequest++;
      _parkingListExpanded = false;
      _showWalkingOnly = false;
      _isLoadingSelectedRoute = false;
      _destinationArrival = null;
      _arrivalAvailability = null;
      _selectedDestination = place;
      _searchController.text = place.name;
      _searchResults = [];
      _searchError = null;
      _routeError = null;
      _isLoadingRoutes = true;
      _routeResults = [];
      _selectedParkingLotId = null;
    });

    _updateMap();
    try {
      final results = await _parkingRouteService.fetchRoutes(place);
      if (!mounted || _selectedDestination != place) return;

      setState(() {
        _routeResults = ParkingRouteService.sortResults(results, _sortOption);
        _isLoadingRoutes = false;
        if (results.isEmpty) {
          _routeError = '주변에 검색된 주차장이 없습니다.';
        }
      });
    } catch (e) {
      if (!mounted || _selectedDestination != place) return;
      setState(() {
        _isLoadingRoutes = false;
        _routeError = '주차장 정보를 불러오지 못했습니다.\n(백엔드 서버 상태 및 연결을 확인해주세요)';
      });
    }

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

  Future<void> _selectParkingLot(ParkingLot lot) async {
    final controller = _webViewController;
    final destination = _selectedDestination;
    if (controller == null || !_mapReady || destination == null) return;

    final request = ++_routeRequest;
    bool isCurrent() => mounted && request == _routeRequest;
    setState(() {
      _selectedParkingLotId = lot.id;
      _parkingListExpanded = false;
      _showWalkingOnly = false;
      _isLoadingSelectedRoute = true;
      _destinationArrival = null;
      _arrivalAvailability = null;
      _routeError = null;
    });

    await controller.evaluateJavascript(
      source: 'window.clearRoutes(); window.focusParkingLot(${jsonEncode(lot.id)});',
    );
    if (!isCurrent()) return;

    int? driveSeconds;
    int? walkSeconds;
    final failedLegs = <String>[];

    await Future.wait([
      () async {
        try {
          final position = await ParkingRouteService.getCurrentPosition()
              .timeout(const Duration(seconds: 15));
          if (!isCurrent()) return;
          final route = await KakaoSearchService.fetchCarRoutePath(
            apiKey: _kakaoRestApiKey,
            startLongitude: position.longitude,
            startLatitude: position.latitude,
            endLongitude: lot.longitude,
            endLatitude: lot.latitude,
          ).timeout(const Duration(seconds: 10));
          if (!isCurrent()) return;
          driveSeconds = route.seconds;
          await controller.evaluateJavascript(
            source: 'window.drawCarRoute(${jsonEncode(route.path)});',
          );
        } catch (_) {
          failedLegs.add('자동차');
        }
      }(),
      () async {
        try {
          final route = await KakaoSearchService.fetchWalkRoutePath(
            apiKey: _kakaoRestApiKey,
            lot: lot,
            destination: destination,
          ).timeout(const Duration(seconds: 10));
          if (!isCurrent()) return;
          walkSeconds = route.seconds;
          await controller.evaluateJavascript(
            source: 'window.drawWalkingRoute(${jsonEncode(route.path)});',
          );
          if (!isCurrent()) return;
          await _fitSelectedRoute(controller);
        } catch (_) {
          failedLegs.add('도보');
        }
      }(),
    ]);
    if (!mounted || request != _routeRequest) return;

    final drive = driveSeconds;
    final walk = walkSeconds;
    final now = DateTime.now();
    final arrival = drive == null || walk == null || drive < 0 || walk < 0
        ? null
        : now.add(Duration(seconds: drive + walk));
    final observedAt = lot.sourceUpdatedAt;
    final observationLead = arrival == null || observedAt == null
        ? null
        : arrival.difference(observedAt);
    setState(() {
      _isLoadingSelectedRoute = false;
      _destinationArrival = arrival;
      if (observationLead != null &&
          !observationLead.isNegative &&
          observationLead <= const Duration(minutes: 30)) {
        _arrivalAvailability = lot.availableSpaces;
      }
    });
    if (failedLegs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${failedLegs.join('·')} 경로를 불러오지 못했습니다.')),
      );
    }
    await WidgetsBinding.instance.endOfFrame;
    if (isCurrent()) await _fitSelectedRoute(controller);
  }

  Future<void> _fitSelectedRoute(InAppWebViewController controller) async {
    final sheetHeight = _parkingSheetKey.currentContext?.size?.height ?? 0;
    await controller.evaluateJavascript(
      source: 'window.fitSelectedRoute(${sheetHeight.ceil() + 28}, $_showWalkingOnly);',
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
                    handlerName: 'onParkingLotMarkerTapped',
                    callback: (args) {
                      if (args.isEmpty) return;
                      for (final result in _routeResults) {
                        if (result.parkingLot.id == args.first.toString()) {
                          _selectParkingLot(result.parkingLot);
                          break;
                        }
                      }
                    },
                  );
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
                key: _parkingSheetKey,
                isExpanded: _parkingListExpanded,
                maxHeight: MediaQuery.sizeOf(context).height * 0.64,
                showWalkingOnly: _showWalkingOnly,
                onExpandChanged: (expanded) async {
                  setState(() => _parkingListExpanded = expanded);
                  await WidgetsBinding.instance.endOfFrame;
                  final controller = _webViewController;
                  if (mounted && controller != null && _selectedParkingLotId != null) {
                    await _fitSelectedRoute(controller);
                  }
                },
                onRouteViewChanged: (walkingOnly) {
                  setState(() => _showWalkingOnly = walkingOnly);
                  final controller = _webViewController;
                  if (controller != null) _fitSelectedRoute(controller);
                },
                sortOption: _sortOption,
                destinationArrival: _destinationArrival,
                arrivalAvailability: _arrivalAvailability,
                onSortChanged: (option) => setState(() {
                  _sortOption = option;
                  _routeResults = ParkingRouteService.sortResults(_routeResults, option);
                }),
                selectedDestination: _selectedDestination,
                routeResults: _routeResults,
                selectedParkingLotId: _selectedParkingLotId,
                isLoadingRoutes: _isLoadingRoutes,
                isLoadingSelectedRoute: _isLoadingSelectedRoute,
                routeError: _routeError,
                onSelectParkingLot: _selectParkingLot,
              ),
            ),
            if (_selectedParkingLotId == null)
            Positioned(
              right: 16,
              top: 76,
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
