import 'package:flutter/material.dart';
import '../models/destination_place.dart';
import '../models/parking_lot.dart';
import '../models/parking_route.dart';
import '../services/parking_route_service.dart';
import 'route_option_card.dart';

class ParkingDetailSheet extends StatelessWidget {
  final DestinationPlace? selectedDestination;
  final bool isExpanded;
  final double maxHeight;
  final bool showWalkingOnly;
  final ValueChanged<bool> onExpandChanged;
  final ValueChanged<bool> onRouteViewChanged;
  final SortOption sortOption;
  final ValueChanged<SortOption> onSortChanged;
  final DateTime? destinationArrival;
  final int? arrivalAvailability;
  final List<ParkingRouteResult> routeResults;
  final String? selectedParkingLotId;
  final bool isLoadingRoutes;
  final bool isLoadingSelectedRoute;
  final String? routeError;
  final ValueChanged<ParkingLot> onSelectParkingLot;

  const ParkingDetailSheet({
    super.key,
    required this.selectedDestination,
    required this.isExpanded,
    required this.maxHeight,
    required this.showWalkingOnly,
    required this.onExpandChanged,
    required this.onRouteViewChanged,
    required this.sortOption,
    required this.onSortChanged,
    required this.destinationArrival,
    required this.arrivalAvailability,
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
      primary: false,
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
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
    String? selectedParkingName;
    for (final result in routeResults) {
      if (result.parkingLot.id == selectedParkingLotId) {
        selectedParkingName = result.parkingLot.name;
        break;
      }
    }
    final compactSelection = isExpanded ? null : selectedParkingName;
    final showList = compactSelection == null;
    final canExpand = routeResults.isNotEmpty;
    final arrival = destinationArrival;
    final arrivalTime = arrival == null
        ? null
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(arrival),
          );
    final prediction = arrivalAvailability == null
        ? '여유 추정 불가'
        : '여유 약 $arrivalAvailability면\n최근 관측값 유지 가정';
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: isExpanded ? maxHeight : maxHeight.clamp(0.0, 320.0).toDouble(),
        ),
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canExpand)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity != 0) onExpandChanged(velocity < 0);
                },
                onTap: () => onExpandChanged(!isExpanded),
                child: SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      compactSelection ?? (canExpand ? '주변 주차장 ${routeResults.length}곳' : '주변 주차장'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (canExpand)
                    TextButton(
                      onPressed: () => onExpandChanged(!isExpanded),
                      child: Text(isExpanded ? '접기' : '목록 더 보기'),
                    ),
                  if (showList && selectedDestination != null)
                    PopupMenuButton<SortOption>(
                      tooltip: '주차장 정렬',
                      initialValue: sortOption,
                      onSelected: onSortChanged,
                      itemBuilder: (context) => [
                        for (final option in SortOption.values)
                          PopupMenuItem(value: option, child: Text(option.label)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('${sortOption.label} ▾'),
                      ),
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
            if (!showList)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Column(
                    children: [
                      Text(
                        isLoadingSelectedRoute
                            ? '경로를 불러오는 중…'
                            : arrivalTime == null
                                ? '목적지 도착 시 여유 추정 불가'
                                : '목적지 도착 예상 $arrivalTime · $prediction',
                        textAlign: TextAlign.center,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('전체 경로'),
                            selected: !showWalkingOnly,
                            onSelected: (_) => onRouteViewChanged(false),
                          ),
                          ChoiceChip(
                            label: const Text('도보 구간'),
                            selected: showWalkingOnly,
                            onSelected: (_) => onRouteViewChanged(true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (showList) Flexible(child: _buildParkingRouteList()),
            if (showList) Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Text(
                sortOption == SortOption.optimal
                    ? '최적순은 현재 여유 대수와 직선거리를 함께 반영합니다.'
                    : '서울시 공공 데이터 · 목적지 주변 주차장',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
