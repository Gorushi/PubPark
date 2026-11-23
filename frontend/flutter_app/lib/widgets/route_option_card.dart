import 'package:flutter/material.dart';
import '../models/parking_lot.dart';
import '../models/parking_route.dart';

class RouteOptionCard extends StatelessWidget {
  final int index;
  final ParkingRouteResult routeResult;
  final bool isSelected;
  final bool isLoadingSelectedRoute;
  final ValueChanged<ParkingLot> onSelect;

  const RouteOptionCard({
    super.key,
    required this.index,
    required this.routeResult,
    required this.isSelected,
    required this.isLoadingSelectedRoute,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final lot = routeResult.parkingLot;

    return ListTile(
      selected: isSelected,
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text(lot.name),
      subtitle: Text(
        '직선거리 ${routeResult.distanceText}\n'
        '잔여 ${lot.availableSpaces} / ${lot.totalSpaces}면',
      ),
      isThreeLine: true,
      trailing: isLoadingSelectedRoute && isSelected
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => onSelect(lot),
    );
  }
}
