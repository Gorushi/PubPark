import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';
import '../models/parking_search.dart';
import '../services/naver_map_initializer.dart';
import '../services/parking_repository.dart';
import '../widgets/demo_map_preview.dart';
import '../widgets/parking_sheet.dart';

class NaverMapScreen extends StatefulWidget {
  const NaverMapScreen({
    super.key,
    this.clientId = AppConfig.naverMapsClientId,
    this.initializer = const NaverMapInitializer(),
    this.repository,
  });
  final String clientId;
  final NaverMapInitializer initializer;
  final ParkingRepository? repository;
  @override
  State<NaverMapScreen> createState() => _NaverMapScreenState();
}

class _NaverMapScreenState extends State<NaverMapScreen>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  final _scaffold = GlobalKey<ScaffoldState>();
  final _sheet = DraggableScrollableController();
  double _sheetExtent = .39;
  late final ParkingRepository _repository;
  Timer? _timer;
  NaverMapController? _map;
  SearchResult? _result;
  MapPoint? _origin;
  String? _selectedId, _mapError, _message;
  bool _ready = false, _busy = false, _locating = false;
  int _generation = 0;
  Future<void> _mapWork = Future.value();
  int _mapEpoch = 0;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  NLatLng _n(MapPoint p) => NLatLng(p.latitude, p.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository =
        widget.repository ??
        (AppConfig.useMockData
            ? MockParkingRepository()
            : HttpParkingRepository(AppConfig.apiBaseUrl));
    if (widget.clientId.trim().isNotEmpty && _supported) {
      _initialize();
    }
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
    if (_repository.isDemo) {
      _origin = MockParkingRepository.origin;
      _search.text = '서울시청';
      _performSearch();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _result != null &&
        DateTime.now().difference(_result!.fetchedAt).inMinutes >= 5) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sheet.dispose();
    _search.dispose();
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await widget.initializer.initialize(widget.clientId.trim(), () {
        if (mounted) {
          setState(
            () => _mapError =
                '네이버 지도 인증에 실패했습니다. Client ID, 앱 등록 정보 및 사용 한도를 확인해주세요.',
          );
        }
      });
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => _mapError = '네이버 지도를 초기화하지 못했습니다. 앱을 다시 실행해주세요.');
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    final generation = ++_generation;
    try {
      final result = await _repository.search(query, _origin);
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _selectedId = null;
        _message = result.notice;
      });
      await _syncMap(fit: true);
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final current = _result;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    try {
      final refreshed = await _repository.refresh(current);
      if (!mounted) return;
      setState(() {
        _result = SearchResult(
          destination: refreshed.destination,
          destinationName: refreshed.destinationName,
          parkings: refreshed.parkings,
          fetchedAt: refreshed.fetchedAt,
          route: current.route,
          notice: refreshed.notice,
        );
        _message = refreshed.notice;
        if (!refreshed.parkings.any((p) => p.id == _selectedId)) {
          _selectedId = null;
        }
      });
      await _syncMap();
    } catch (_) {
      if (mounted) setState(() => _message = '갱신하지 못했어요. 이전 조회 결과를 표시하고 있습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _locate() async {
    if (_locating || _busy) return;
    if (_repository.isDemo) {
      setState(() => _message = '데모의 출발지는 서울역 인근 샘플 위치입니다.');
      if (_map != null) {
        await _map!.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: _n(_origin!), zoom: 14),
        );
      }
      return;
    }
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('기기의 위치 서비스를 켜주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한을 허용하면 이동 경로를 안내할 수 있어요.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() => _origin = MapPoint(p.latitude, p.longitude));
      if (_search.text.trim().isNotEmpty) await _performSearch();
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _select(ParkingResult lot) async {
    setState(() => _selectedId = lot.id);
    if (_sheet.isAttached && _sheet.size > .4) {
      await _sheet.animateTo(
        .39,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
    }
    await _syncMap();
    try {
      await _map?.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: _n(lot.point), zoom: 16),
      );
    } catch (_) {}
  }

  Future<void> _syncMap({bool fit = false}) async {
    final epoch = _mapEpoch;
    _mapWork = _mapWork.then((_) async {
      if (!mounted || epoch != _mapEpoch) return;
      await _renderMap(fit: fit);
    });
    await _mapWork;
  }

  Future<void> _renderMap({bool fit = false}) async {
    final map = _map, result = _result;
    if (map == null || result == null) return;
    try {
      await map.clearOverlays();
      if (!mounted || map != _map) return;
      final overlays = <NAddableOverlay>{};
      overlays.add(
        NMarker(
          id: 'destination',
          position: _n(result.destination),
          iconTintColor: const Color(0xFF213C4A),
          caption: NOverlayCaption(text: result.destinationName),
        ),
      );
      if (_origin != null) {
        overlays.add(
          NMarker(
            id: 'origin',
            position: _n(_origin!),
            iconTintColor: const Color(0xFF2C68E9),
            caption: const NOverlayCaption(text: '출발지'),
          ),
        );
      }
      for (final lot in result.parkings) {
        final marker = NMarker(
          id: lot.id,
          position: _n(lot.point),
          iconTintColor: lot.id == _selectedId
              ? const Color(0xFF205CDF)
              : const Color(0xFF07826C),
          caption: NOverlayCaption(
            text: lot.id == _selectedId
                ? lot.name
                : 'P ${lot.available ?? '—'}',
          ),
        );
        marker.setOnTapListener((_) => _select(lot));
        overlays.add(marker);
      }
      if (result.route != null && result.route!.points.length >= 2) {
        overlays.add(
          NPolylineOverlay(
            id: 'driving',
            coords: result.route!.points.map(_n),
            color: const Color(0xFF2C68E9),
            width: 5,
          ),
        );
      }
      await map.addOverlayAll(overlays);
      if (fit) {
        await map.updateCamera(
          NCameraUpdate.fitBounds(
            NLatLngBounds.from([
              _n(result.destination),
              ...?result.route?.points.map(_n),
              ...result.parkings.take(3).map((p) => _n(p.point)),
            ]),
            padding: const EdgeInsets.all(38),
          ),
        );
      }
    } catch (error) {
      debugPrint('PubPark map update failed: ${error.runtimeType}');
      if (mounted) {
        setState(() => _message = '지도 표시를 갱신하지 못했어요. 주차장 목록을 확인해주세요.');
      }
    }
  }

  Widget _mapView() {
    String? reason;
    if (widget.clientId.trim().isEmpty) {
      reason = 'NAVER_MAPS_CLIENT_ID 설정이 필요합니다.';
    } else if (!_supported) {
      reason = '네이버 지도는 Android와 iOS 앱에서 사용할 수 있습니다.';
    } else if (_mapError != null && _map == null) {
      reason = _mapError;
    }
    if (reason != null) {
      return Stack(
        children: [
          if (_repository.isDemo)
            DemoMapPreview(result: _result, selectedId: _selectedId)
          else
            const ColoredBox(
              color: Color(0xFFEAF0EC),
              child: SizedBox.expand(),
            ),
          Positioned(
            top: 248,
            left: 28,
            right: 28,
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF536F6A)),
            ),
          ),
        ],
      );
    }
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        Positioned.fill(
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: const NCameraPosition(
                target: NLatLng(37.5666, 126.9784),
                zoom: 14,
              ),
              contentPadding: EdgeInsets.fromLTRB(
                18,
                math.max(
                  20,
                  math.min(
                    205,
                    MediaQuery.sizeOf(context).height * (1 - _sheetExtent) - 80,
                  ),
                ),
                18,
                MediaQuery.sizeOf(context).height * _sheetExtent,
              ),
            ),
            onMapReady: (controller) {
              _mapEpoch++;
              _map = controller;
              _syncMap(fit: true);
            },
          ),
        ),
        if (_mapError != null)
          Positioned(
            top: 248,
            left: 24,
            right: 24,
            child: Material(
              color: const Color(0xFFFFF5DA),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _mapError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF785817),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _result?.route;
    return Scaffold(
      key: _scaffold,
      resizeToAvoidBottomInset: false,
      drawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PubPark',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF087F6B),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('가까운 주차장, 여유로운 도착.'),
                const Divider(height: 36),
                Text(
                  _repository.isDemo
                      ? '데모 모드\n주차 현황·주소·이동 경로는 샘플입니다.'
                      : '서울시 실시간 현황\n주차 현황은 5분마다 조회합니다.',
                ),
                const SizedBox(height: 22),
                const Text(
                  '여유: 잔여 비율 20% 이상\n혼잡: 20% 미만\n만차: 잔여 0대\n확인 불가: 미연계·지연·불일치',
                  style: TextStyle(height: 1.8),
                ),
                const Spacer(),
                const Text(
                  '주차 현황은 실제 상황과 다를 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _mapView()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: IconButton(
                          tooltip: '메뉴',
                          onPressed: () => _scaffold.currentState?.openDrawer(),
                          icon: const Icon(
                            Icons.menu_rounded,
                            color: Color(0xFF25434B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'PubPark',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0A6456),
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _repository.isDemo ? 'DEMO' : 'SEOUL LIVE',
                          style: const TextStyle(
                            color: Color(0xFF087F6B),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    elevation: 5,
                    shadowColor: const Color(0x22294E40),
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 5, 6, 5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF087F6B),
                            size: 23,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.text,
                              hintLocales: const [
                                Locale('ko', 'KR'),
                                Locale('en', 'US'),
                              ],
                              autocorrect: false,
                              controller: _search,
                              onSubmitted: (_) => _performSearch(),
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: '어디에 주차할까요? 목적지 주소 검색',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          FilledButton(
                            onPressed: _busy ? null : _performSearch,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF087F6B),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('검색'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (_repository.isDemo)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final label in ['서울시청', '세종문화회관', '강남역'])
                            ActionChip(
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              onPressed: _busy
                                  ? null
                                  : () {
                                      _search.text = label;
                                      _performSearch();
                                    },
                            ),
                        ],
                      ),
                    ),
                  if (route != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF213D4A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_car_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              '${(route.duration.inSeconds / 60).ceil()}분',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '  ·  ${formatDistance(route.distance)}',
                              style: const TextStyle(
                                color: Color(0xFFC9D9DF),
                                fontSize: 12,
                              ),
                            ),
                            if (_repository.isDemo)
                              const Text(
                                '  샘플 경로',
                                style: TextStyle(
                                  color: Color(0xFF9FD2C5),
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_message != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5DA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: Color(0xFF785817),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 18,
            bottom: MediaQuery.sizeOf(context).height * .40 + 14,
            child: FloatingActionButton.small(
              heroTag: 'location',
              tooltip: '현재 위치',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF087F6B),
              onPressed: _locating ? null : _locate,
              child: _locating
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if ((notification.extent - _sheetExtent).abs() > .005) {
                setState(() => _sheetExtent = notification.extent);
              }
              return false;
            },
            child: ParkingSheet(
              controller: _sheet,
              result: _result,
              selectedId: _selectedId,
              loading: _busy,
              onSelect: _select,
              onRefresh: _refresh,
            ),
          ),
          if (_repository.isDemo)
            Positioned(
              left: 20,
              bottom: MediaQuery.sizeOf(context).height * .40 + 17,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '주차 현황·경로는 샘플 데이터',
                  style: TextStyle(fontSize: 10, color: Color(0xFF607D78)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
