
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '주차장 길찾기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeScreen(),
    );
  }
}

class ParkingRoute {
  final String parkingName;
  final String distance;
  final String duration;
  final int totalSpaces;
  final int availableSpaces;

  const ParkingRoute({
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
  final TextEditingController _searchController =
  TextEditingController();

  InAppWebViewController? _mapController;

  bool _showRoutes = false;
  int? _selectedRoute;

  final List<ParkingRoute> _routes = const [
    ParkingRoute(
      parkingName: '제1 공영주차장',
      distance: '1.2 km',
      duration: '5분',
      totalSpaces: 120,
      availableSpaces: 18,
    ),
    ParkingRoute(
      parkingName: '제2 공영주차장',
      distance: '1.6 km',
      duration: '7분',
      totalSpaces: 80,
      availableSpaces: 32,
    ),
  ];

  void _searchDestination() {
    final destination = _searchController.text.trim();

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('목적지를 입력해 주세요.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _showRoutes = true;
      _selectedRoute = null;
    });

    // TODO: 검색한 목적지를 지도에 표시하고
    // 백엔드에서 실제 경로와 주차장 정보를 받아오도록 연결
  }

  void _selectRoute(int index) {
    setState(() {
      _selectedRoute = index;
    });

    // TODO: 선택한 경로를 카카오맵에 표시
  }

  void _showParkingDetails(ParkingRoute parking) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final availableRatio =
        parking.totalSpaces == 0
            ? 0.0
            : parking.availableSpaces / parking.totalSpaces;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
                const Text(
                  '주차장 상세 정보',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ParkingStat(
                        title: '전체 주차 면수',
                        value: '${parking.totalSpaces}면',
                        icon: Icons.local_parking,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ParkingStat(
                        title: '잔여 주차 면수',
                        value: '${parking.availableSpaces}면',
                        icon: Icons.check_circle_outline,
                        valueColor: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('잔여 공간 비율'),
                    Text('${(availableRatio * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: availableRatio,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                const Text(
                  '※ 현재 표시되는 정보는 화면 테스트용 예시입니다.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      final index = _routes.indexOf(parking);
                      if (index >= 0) _selectRoute(index);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('이 주차장 경로 선택'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 전체 화면 지도
            Positioned.fill(
              child: InAppWebView(
                initialFile: 'assets/map.html',
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: false,
                ),
                onWebViewCreated: (controller) {
                  _mapController = controller;

                  controller.addJavaScriptHandler(
                    handlerName: 'mapStatus',
                    callback: (args) {
                      debugPrint('[Map status] ${args.first}');
                      return null;
                    },
                  );
                },
                onLoadStop: (controller, url) async {
                  final size = await controller.evaluateJavascript(
                    source: '''
                JSON.stringify({
                  windowWidth: window.innerWidth,
                  windowHeight: window.innerHeight,
                  mapWidth: document.getElementById('map').clientWidth,
                  mapHeight: document.getElementById('map').clientHeight
                })
              ''',
                  );

                  debugPrint('[Map dimensions] $size');
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('[WebView] ${consoleMessage.message}');
                },
                onReceivedError: (controller, request, error) {
                  debugPrint(
                    '[WebView error] ${request.url}: ${error.description}',
                  );
                },
              ),
            ),

            // 2. 상단 목적지 검색창
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    elevation: 5,
                    shadowColor: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchDestination(),
                      decoration: InputDecoration(
                        hintText: '어디로 이동하시나요?',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF2563EB),
                        ),
                        suffixIcon: IconButton(
                          tooltip: '목적지 검색',
                          onPressed: _searchDestination,
                          icon: const Icon(Icons.arrow_forward),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. 현재 위치 버튼
            Positioned(
              right: 16,
              bottom: _showRoutes ? 285 : 28,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'currentLocation',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  elevation: 4,
                  tooltip: '현재 위치',
                  onPressed: () {
                    // TODO: GPS 위치를 받아 지도 중심 이동
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '현재 위치 기능은 추후 연결할 예정입니다.',
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.my_location),
                ),
              ),
            ),

            // 4. 목적지 검색 후 표시되는 경로 후보 패널
            if (_showRoutes)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '주차장 경로 추천',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '경로 닫기',
                              onPressed: () {
                                setState(() {
                                  _showRoutes = false;
                                  _selectedRoute = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const Text(
                          '목적지까지의 경로와 주차장 정보를 확인하세요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ...List.generate(_routes.length, (index) {
                          final route = _routes[index];
                          final selected = _selectedRoute == index;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _selectRoute(index),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade300,
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: selected
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            route.parkingName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${route.distance} · '
                                                '${route.duration} · '
                                                '잔여 ${route.availableSpaces}면',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '주차장 상세 정보',
                                      onPressed: () {
                                        _showParkingDetails(route);
                                      },
                                      icon: const Icon(
                                        Icons.info_outline,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
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

class _ParkingStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _ParkingStat({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
