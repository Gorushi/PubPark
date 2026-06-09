class ParkingLot {
  final String id;
  final String name;
  final int availableSpaces;

  ParkingLot({
    required this.id,
    required this.name,
    required this.availableSpaces,
  });

  /// 역직렬화: 서버 JSON → Dart 객체
  factory ParkingLot.fromJson(Map<String, dynamic> json) {
    return ParkingLot(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '이름 없음',
      availableSpaces: (json['available_spaces'] as num?)?.toInt() ?? 0,
    );
  }

  /// 직렬화: Dart 객체 → 서버 전송용 JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'available_spaces': availableSpaces,
  };

  @override
  String toString() => 'ParkingLot(id: $id, name: $name, availableSpaces: $availableSpaces)';

  ParkingLot copyWith({String? id, String? name, int? availableSpaces}) {
    return ParkingLot(
      id: id ?? this.id,
      name: name ?? this.name,
      availableSpaces: availableSpaces ?? this.availableSpaces,
    );
  }
}