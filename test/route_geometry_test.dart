import 'package:flutter_test/flutter_test.dart';
import 'package:ride_on/core/utils/route_geometry.dart';

void main() {
  // L-shaped road: east ~500 m, then north ~500 m
  const a = (lat: 28.6000, lng: 77.2000);
  const corner = (lat: 28.6000, lng: 77.2051);
  const b = (lat: 28.6045, lng: 77.2051);
  final route = [a, corner, b];

  test('GPS drift within 25 m snaps onto the road', () {
    final s = snapToRoute((lat: 28.60009, lng: 77.2020), route)!;
    expect(s.segment, 0);
    expect(s.offRoute, closeTo(10, 1.5));
  });

  test('no snap when the driver is off the route', () {
    expect(snapToRoute((lat: 28.60054, lng: 77.2020), route), isNull);
  });

  test('glide follows the bend and never loops backwards', () {
    expect(pathAlongRoute(route, (lat: 28.6000, lng: 77.2040), (lat: 28.6010, lng: 77.2051))[1], corner);
    expect(pathAlongRoute(route, (lat: 28.6010, lng: 77.2051), (lat: 28.6000, lng: 77.2040)).length, 2);
  });

  test('trimming keeps only the route ahead', () {
    final s = snapToRoute((lat: 28.60009, lng: 77.2020), route)!;
    expect(routeAhead(route, s), [s.point, corner, b]);
  });

  test('camera target 60 m ahead', () {
    expect(metersBetween(a, pointAhead(a, 0, 60)), closeTo(60, 0.5));
  });
}
