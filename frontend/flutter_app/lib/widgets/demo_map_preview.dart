import 'package:flutter/material.dart';
import '../models/parking_search.dart';

/// Coordinate-based fallback for UI previews; never presented as a real map.
class DemoMapPreview extends StatelessWidget {
  const DemoMapPreview({super.key, required this.result, this.selectedId});
  final SearchResult? result;
  final String? selectedId;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _MapPainter(result, selectedId),
    size: Size.infinite,
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.result, this.selectedId);
  final SearchResult? result;
  final String? selectedId;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFEAF0EC), BlendMode.src);
    final block = Paint()..color = const Color(0xFFE0E8DF);
    for (var x = -30.0; x < size.width; x += 85) {
      for (var y = 0.0; y < size.height; y += 72) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 8, y + 8, 66, 54),
            const Radius.circular(8),
          ),
          block,
        );
      }
    }
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12;
    for (var x = 0.0; x < size.width; x += 85) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), road);
    }
    for (var y = 0.0; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), road);
    }
    canvas.drawLine(
      Offset(0, size.height * .54),
      Offset(size.width, size.height * .35),
      Paint()
        ..color = const Color(0xFFD3E5F3)
        ..strokeWidth = 22,
    );
    final center = result?.destination ?? const MapPoint(37.5666, 126.9784);
    Offset project(MapPoint p) => Offset(
      size.width * .54 + (p.longitude - center.longitude) * 24000,
      size.height * .40 - (p.latitude - center.latitude) * 26000,
    );
    final route = result?.route;
    if (route != null && route.points.isNotEmpty) {
      final path = Path()
        ..moveTo(
          project(route.points.first).dx,
          project(route.points.first).dy,
        );
      for (final p in route.points.skip(1)) {
        final o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2C68E9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        project(route.points.first),
        8,
        Paint()..color = const Color(0xFF2C68E9),
      );
    }
    for (final lot in result?.parkings ?? <ParkingResult>[]) {
      final at = project(lot.point);
      canvas.drawCircle(
        at,
        lot.id == selectedId ? 18 : 13,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        at,
        lot.id == selectedId ? 15 : 10,
        Paint()..color = const Color(0xFF07826C),
      );
      final text = TextPainter(
        text: TextSpan(
          text: 'P',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }
    canvas.drawCircle(
      project(center),
      10,
      Paint()..color = const Color(0xFF213C4A),
    );
    canvas.drawCircle(project(center), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.result != result || old.selectedId != selectedId;
}
