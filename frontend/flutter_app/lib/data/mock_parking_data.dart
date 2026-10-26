import '../models/parking_lot.dart';

const List<ParkingLot> sampleParkingLots = [
  ParkingLot(
    id: 'gyeongbokgung_parking',
    name: '경복궁 주차장',
    address: '서울특별시 종로구 사직로 161',
    destinationName: '경복궁',
    latitude: 37.5760,
    longitude: 126.9769,
    totalSpaces: 240,
    availableSpaces: 32,
  ),
  ParkingLot(
    id: 'sin-gyo-parking',
    name: '신교 공영주차장',
    address: '서울특별시 종로구 자하문로 일대',
    destinationName: '경복궁',
    latitude: 37.5830,
    longitude: 126.9675,
    totalSpaces: 158,
    availableSpaces: 21,
  ),
  ParkingLot(
    id: 'sejong-ro-parking',
    name: '세종로 공영주차장',
    address: '서울특별시 종로구 세종로 일대',
    destinationName: '경복궁',
    latitude: 37.5725,
    longitude: 126.9765,
    totalSpaces: 1260,
    availableSpaces: 185,
  ),
];