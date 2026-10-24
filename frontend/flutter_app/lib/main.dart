
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주차장 경로 안내',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// 주차장 경로 데이터 모델
class ParkingRoute {
  final String id;
  final String parkingName;
  final String distance;
  final String duration;
  final int totalSpaces;
  final int availableSpaces;

  const ParkingRoute({
    required this.id,
    required this.parkingName,
    required this.distance,
    required this.duration,
    required this.totalSpaces,
    required this.availableSpaces,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InAppWebViewController? _mapController;

  final TextEditingController _destinationController =
  TextEditingController();

  String _destination = '';
  bool _showRoutes = true;

  // 테스트용 주차장 데이터
  // 실제 API를 연결하면 API 응답으로 교체할 수 있음.
  final List<ParkingRoute> _routes = const [
    ParkingRoute(
      id: 'parking1',
      parkingName: '제1 공영주차장',
      distance: '300m',
      duration: '도보 4분',
      totalSpaces: 100,
      availableSpaces: 25,
    ),
    ParkingRoute(
      id: 'parking2',
      parkingName: '제2 공영주차장',
      distance: '500m',
      duration: '도보 7분',
      totalSpaces: 80,
      availableSpaces: 12,
    ),
  ];

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  // 목적지 검색
  void _searchDestination() {
    final destination = _destinationController.text.trim();

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('목적지를 입력해주세요.'),
        ),
      );
      return;
    }

    setState(() {
      _destination = destination;
      _showRoutes = true;
    });

    FocusScope.of(context).unfocus();

    // 현재는 테스트 주차장 목록을 표시한다.
    // 실제 목적지 검색 및 경로 탐색은 API 연결이 필요하다.
  }

  // JavaScript에서 전달한 주차장 마커 클릭 이벤트 수신
  void _registerParkingMarkerHandler(
      InAppWebViewController controller,
      ) {
    controller.addJavaScriptHandler(
      handlerName: 'parkingMarkerClicked',
      callback: (args) {
        if (args.isEmpty || !mounted) {
          return null;
        }

        final parkingId = args.first.toString();

        final index = _routes.indexWhere(
              (route) => route.id == parkingId,
        );

        if (index != -1) {
          _showParkingDetails(_routes[index]);
        }

        return null;
      },
    );
  }

  // 주차장 데이터를 Kakao 지도에 전달
  Future<void> _sendParkingMarkers() async {
    final controller = _mapController;

    if (controller == null) {
      return;
    }

    final parkingLots = [
      {
        'id': 'parking1',
        'name': '제1 공영주차장',
        'latitude': 36.6358,
        'longitude': 127.4914,
      },
      {
        'id': 'parking2',
        'name': '제2 공영주차장',
        'latitude': 36.6390,
        'longitude': 127.4960,
      },
    ];

    try {
      await controller.evaluateJavascript(
        source:
        'window.setParkingLots(${jsonEncode(parkingLots)});',
      );
    } catch (e) {
      debugPrint('주차장 마커 전송 오류: $e');
    }
  }

  // 주차장 상세 정보 바텀시트
  void _showParkingDetails(ParkingRoute parking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final double availableRatio =
        parking.totalSpaces > 0
            ? parking.availableSpaces / parking.totalSpaces
            : 0.0;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  parking.parkingName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${parking.distance} · ${parking.duration}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildParkingInfo(
                        title: '전체 주차면',
                        value: '${parking.totalSpaces}대',
                        icon: Icons.local_parking,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildParkingInfo(
                        title: '현재 여유',
                        value: '${parking.availableSpaces}대',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '주차 가능 현황',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: availableRatio.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: availableRatio > 0.3
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '주차 가능 ${parking.availableSpaces}대 / '
                      '${parking.totalSpaces}대',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${parking.parkingName}: 경로 선택 기능은 '
                                '경로 API 연결 후 구현할 수 있습니다.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('이 주차장 선택'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 상세 정보의 주차면 정보 카드
  Widget _buildParkingInfo({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.blue,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 하단 주차장 경로 후보 카드
  Widget _buildRouteCard(ParkingRoute parking, int index) {
    final bool hasSpace = parking.availableSpaces > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showParkingDetails(parking),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parking.parkingName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${parking.distance} · ${parking.duration}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '여유 주차 ${parking.availableSpaces}대',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasSpace ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 배경 Kakao 지도
            Positioned.fill(
              child: InAppWebView(
                initialFile: 'assets/map.html',
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: true,
                ),
                onWebViewCreated: (controller) {
                  _mapController = controller;
                  _registerParkingMarkerHandler(controller);
                },
                onLoadStop: (controller, url) async {
                  // 지도 초기화 시간을 잠시 확보
                  await Future.delayed(
                    const Duration(milliseconds: 500),
                  );

                  if (mounted) {
                    await _sendParkingMarkers();
                  }
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint(
                    'Kakao Map: ${consoleMessage.message}',
                  );
                },
              ),
            ),

            // 상단 목적지 검색창
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    0,
                  ),
                  child: Material(
                    elevation: 5,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Colors.blue,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _destinationController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _searchDestination(),
                              decoration: InputDecoration(
                                hintText: '목적지를 입력하세요',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _searchDestination,
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 현재 위치 버튼
            Positioned(
              right: 16,
              bottom: _showRoutes ? 230 : 24,
              child: FloatingActionButton.small(
                heroTag: 'currentLocationButton',
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                elevation: 4,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '현재 위치 기능은 위치 권한 및 GPS 연결 후 '
                            '구현할 수 있습니다.',
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.my_location),
              ),
            ),

            // 하단 주차장 후보 목록
            if (_showRoutes)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight:
                      MediaQuery.of(context).size.height * 0.42,
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      10,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _destination.isEmpty
                                    ? '주변 주차장'
                                    : '$_destination 주변 경로',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '목록 접기',
                              onPressed: () {
                                setState(() {
                                  _showRoutes = false;
                                });
                              },
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _routes.length,
                            itemBuilder: (context, index) {
                              return _buildRouteCard(
                                _routes[index],
                                index,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 접힌 목록 다시 열기
            if (!_showRoutes)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SafeArea(
                  top: false,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showRoutes = true;
                      });
                    },
                    icon: const Icon(Icons.local_parking),
                    label: const Text('주변 주차장 보기'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      elevation: 5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
