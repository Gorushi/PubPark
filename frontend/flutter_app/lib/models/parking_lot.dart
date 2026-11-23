class ParkingLot {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int totalSpaces;
  final int? availableSpaces;
  final DateTime? sourceUpdatedAt;
  final String destinationName;
  final bool isMockAvailability;

  const ParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalSpaces,
    required this.availableSpaces,
    this.sourceUpdatedAt,
    this.destinationName = '',
    this.isMockAvailability = true,
  });

  factory ParkingLot.fromJson(Map<String, dynamic> json, {String destinationName = ''}) {
    return ParkingLot(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '이름 없음',
      address: json['address']?.toString() ?? '주소 정보 없음',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      totalSpaces: (json['total_spaces'] as num?)?.toInt() ?? (json['totalSpaces'] as num?)?.toInt() ?? 0,
      availableSpaces: (json['available_spaces'] as num?)?.toInt() ?? (json['availableSpaces'] as num?)?.toInt(),
      sourceUpdatedAt: DateTime.tryParse(json['source_updated_at']?.toString() ?? ''),
      destinationName: destinationName,
      isMockAvailability: json['status'] == null || json['status'] == 'unlinked',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'total_spaces': totalSpaces,
        'available_spaces': availableSpaces,
        'source_updated_at': sourceUpdatedAt?.toIso8601String(),
        'destinationName': destinationName,
        'isMockAvailability': isMockAvailability,
      };

  double get occupancyRate {
    final available = availableSpaces;
    if (totalSpaces <= 0 || available == null) return 0;
    return (totalSpaces - available) / totalSpaces;
  }
}
