import 'dart:math';

double calculateDistance(
  double currentLatitude,
  double currentLongitude,
  double targetLatitude,
  double targetLongitude,
) {
  const double earthRadius = 6371; // in kilometers

  double dLat = _toRadians(targetLatitude - currentLatitude);
  double dLon = _toRadians(targetLongitude - currentLongitude);

  double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(currentLatitude)) *
          cos(_toRadians(targetLatitude)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c; // distance in km
}

double _toRadians(double degree) {
  return degree * pi / 180;
}
