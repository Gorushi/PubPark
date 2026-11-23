import 'package:flutter/material.dart';
import '../models/destination_place.dart';
import '../models/parking_lot.dart';
import '../models/parking_route.dart';
import 'route_option_card.dart';

class ParkingDetailSheet extends StatelessWidget {
  final DestinationPlace? selectedDestination;
  final List<ParkingRouteResult> routeResults;
  final String? selectedParkingLotId;
  final bool isLoadingRoutes;
  final bool isLoadingSelectedRoute;
  final String? routeError;
  final ValueChanged<ParkingLot> onSelectParkingLot;

  const ParkingDetailSheet({
    super.key,
    required this.selectedDestination,
    required this.routeResults,
    required this.selectedParkingLotId,
    required this.isLoadingRoutes,
    required this.isLoadingSelectedRoute,
    required this.routeError,
    required this.onSelectParkingLot,
  });

  Widget _buildParkingRouteList() {
    if (selectedDestination == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('목적지를 검색하면 가까운 주차장을 보여 줍니다.'),
      );
    }

    if (isLoadingRoutes) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: routeResults.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = routeResults[index];
        final lot = result.parkingLot;
        final selected = selectedParkingLotId == lot.id;

        return RouteOptionCard(
          index: index,
          routeResult: result,
          isSelected: selected,
          isLoadingSelectedRoute: isLoadingSelectedRoute,
          onSelect: onSelectParkingLot,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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
                  if (selectedDestination != null)
                    Text(
                      '${routeResults.length}곳',
                      style: const TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (routeError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  routeError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Flexible(child: _buildParkingRouteList()),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Text(
                '서울시 공공 데이터 · 후보 정렬은 직선거리 기준',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
