import 'package:flutter/material.dart';
import '../models/parking_search.dart';
import 'parking_card.dart';

class ParkingSheet extends StatelessWidget {
  const ParkingSheet({
    super.key,
    required this.result,
    required this.selectedId,
    required this.loading,
    required this.onSelect,
    required this.onRefresh,
    this.controller,
  });
  final SearchResult? result;
  final String? selectedId;
  final bool loading;
  final ValueChanged<ParkingResult> onSelect;
  final VoidCallback onRefresh;
  final DraggableScrollableController? controller;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    controller: controller,
    initialChildSize: .39,
    minChildSize: .17,
    maxChildSize: .83,
    snap: true,
    snapSizes: const [.17, .39, .83],
    builder: (context, controller) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFCFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x180E3040),
            blurRadius: 28,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8E0E4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 14, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '목적지 주변 주차장',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF173643),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${result?.parkings.length ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFF087F6B),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        tooltip: '주차 현황 새로고침',
                        onPressed: loading || result == null ? null : onRefresh,
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 21),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 17),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 12,
                        color: Color(0xFF087F6B),
                      ),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          '직선거리순 · 최대 10곳',
                          style: TextStyle(
                            color: Color(0xFF71828C),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        result == null
                            ? '5분마다 갱신'
                            : '${result!.fetchedAt.toLocal().hour.toString().padLeft(2, '0')}:${result!.fetchedAt.toLocal().minute.toString().padLeft(2, '0')} 조회 · 5분 갱신',
                        style: const TextStyle(
                          color: Color(0xFF83929B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (result == null || result!.parkings.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  loading
                      ? '주변 주차장을 찾고 있어요.'
                      : result == null
                      ? '목적지 주소를 검색하면\n가까운 시영주차장을 찾아드려요.'
                      : '좌표가 확인된 주변 주차장이 없습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF7A8C96), height: 1.7),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: result!.parkings.length,
              itemBuilder: (context, i) {
                final lot = result!.parkings[i];
                return ParkingCard(
                  parking: lot,
                  index: i + 1,
                  selected: selectedId == lot.id,
                  onTap: () => onSelect(lot),
                );
              },
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 20),
          ),
        ],
      ),
    ),
  );
}
