import 'package:flutter/material.dart';
import '../models/parking_search.dart';

class ParkingCard extends StatelessWidget {
  const ParkingCard({
    super.key,
    required this.parking,
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final ParkingResult parking;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = switch (parking.badge) {
      '여유' => const Color(0xFF087F6B),
      '혼잡' => const Color(0xFFB5680C),
      '만차' => const Color(0xFFC34450),
      _ => const Color(0xFF667085),
    };
    final time = parking.sourceUpdatedAt?.toLocal();
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        elevation: 0,
        color: selected ? const Color(0xFFF0FAF6) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? const Color(0xFF159B7B) : const Color(0xFFE7EBEE),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF087F6B)
                            : const Color(0xFFF1F4F6),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF4B5C67),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        parking.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF182E3C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        parking.badge,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  parking.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7C8791),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '주차 현황: ${parking.available ?? '확인 불가'} / ${parking.total ?? '—'}대',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '목적지에서 ${formatDistance(parking.distance)}',
                      style: const TextStyle(
                        color: Color(0xFF5B6D78),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (time != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} 제공 정보 기준',
                    style: const TextStyle(
                      color: Color(0xFF8B969E),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
