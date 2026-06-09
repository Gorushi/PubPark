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
      id: json['id'] as String,
      name: json['name'] as String,
      availableSpaces: json['available_spaces'] as int,
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
}