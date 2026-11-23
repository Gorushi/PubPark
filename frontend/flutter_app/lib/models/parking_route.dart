import 'package:flutter/material.dart';
import 'parking_lot.dart';

class ParkingRouteResult {
  final ParkingLot parkingLot;
  final double distanceMeters;
  final int? driveDurationSeconds;
  final int? walkDurationSeconds;

  const ParkingRouteResult({
    required this.parkingLot,
    required this.distanceMeters,
    this.driveDurationSeconds,
    this.walkDurationSeconds,
  });

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
    }
    return '${distanceMeters.round()}m';
  }

  /// 예상 총 소요 시간 (분)
  int get estimatedTotalMinutes {
    if (driveDurationSeconds != null || walkDurationSeconds != null) {
      final totalSec = (driveDurationSeconds ?? 0) + (walkDurationSeconds ?? 0);
      return (totalSec / 60).ceil();
    }
    // 기본 추정치: 시속 25km 운전 + 평균 3분 주차/도보
    final driveMinutes = (distanceMeters / 400).ceil(); // ~24km/h
    return mathMax(driveMinutes + 3, 2);
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  String get durationText {
    return '약 $estimatedTotalMinutes분 소요';
  }

  /// 주차장 여유 상태 텍스트
  String get availabilityBadgeText {
    final available = parkingLot.availableSpaces;
    if (available == null) return '현황 확인 불가';
    if (available > 15) return '여유';
    if (available > 5) return '보통';
    if (available > 0) return '혼잡';
    return '만차';
  }

  /// 여유 상태에 따른 색상
  Color get availabilityBadgeColor {
    final available = parkingLot.availableSpaces;
    if (available == null) return Colors.grey;
    if (available > 15) return const Color(0xFF16A34A); // 초록
    if (available > 5) return const Color(0xFFD97706);  // 주황
    if (available > 0) return const Color(0xFFEA580C);  // 진한 주황
    return const Color(0xFFDC2626);                     // 빨강
  }
}
