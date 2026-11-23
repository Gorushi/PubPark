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
    final available = lot.availableSpaces;

    return InkWell(
      onTap: () => onSelect(lot),
      child: Container(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade200,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lot.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: routeResult.availabilityBadgeColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: routeResult.availabilityBadgeColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          available == null
                              ? routeResult.availabilityBadgeText
                              : '현재 ${routeResult.availabilityBadgeText} $available면',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: routeResult.availabilityBadgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '목적지까지 직선 ${routeResult.distanceText}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '총 ${lot.totalSpaces}면 · ${lot.address}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isLoadingSelectedRoute && isSelected
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
