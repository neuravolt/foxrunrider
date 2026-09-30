import 'dart:math' as math;

/// Pure geometry for live ride tracking (no Flutter imports, unit-testable with plain `dart`).
/// Same file in foxrunrider and foxrundriver — keep them identical.
typedef RoutePoint = ({double lat, double lng});

class RouteSnap {
  /// Closest point on the route to the GPS fix.
  final RoutePoint point;

  /// Index of the route segment [route[segment], route[segment + 1]] the point lies on.
  final int segment;

  /// Metres from the route start to [point], measured along the route.
  final double along;

  /// Metres between the raw GPS fix and [point].
  final double offRoute;

  const RouteSnap(this.point, this.segment, this.along, this.offRoute);
}

const double _earthRadius = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;

double metersBetween(RoutePoint a, RoutePoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * _earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Snaps [p] onto [route] when it is within [maxMeters]; null means "use the raw GPS point"
/// (driver left the route, or no route yet) so the vehicle is never glued to the wrong road.
RouteSnap? snapToRoute(RoutePoint p, List<RoutePoint> route, {double maxMeters = 25}) {
  if (route.length < 2) return null;
  // Local flat projection around p (metres); exact enough for segments of a city route.
  final mPerLat = _earthRadius * math.pi / 180.0;
  final mPerLng = mPerLat * math.cos(_rad(p.lat));
  double x(RoutePoint q) => (q.lng - p.lng) * mPerLng;
  double y(RoutePoint q) => (q.lat - p.lat) * mPerLat;

  RouteSnap? best;
  double alongStart = 0;
  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i], b = route[i + 1];
    final ax = x(a), ay = y(a), bx = x(b), by = y(b);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (((-ax) * dx + (-ay) * dy) / len2).clamp(0.0, 1.0);
    final px = ax + t * dx, py = ay + t * dy;
    final dist = math.sqrt(px * px + py * py);
    final segLen = math.sqrt(len2);
    if (best == null || dist < best.offRoute) {
      best = RouteSnap(
        (lat: a.lat + t * (b.lat - a.lat), lng: a.lng + t * (b.lng - a.lng)),
        i,
        alongStart + t * segLen,
        dist,
      );
    }
    alongStart += segLen;
  }
  return (best != null && best.offRoute <= maxMeters) ? best : null;
}

/// The part of the route still ahead of the vehicle (for trimming the drawn line).
List<RoutePoint> routeAhead(List<RoutePoint> route, RouteSnap snap) =>
    [snap.point, ...route.sublist(snap.segment + 1)];

/// Path the marker should glide along from [from] to [to]: follows the road's bends when both
/// fixes are on the route in forward order and not absurdly far apart, else a straight line.
List<RoutePoint> pathAlongRoute(
  List<RoutePoint> route,
  RoutePoint rawFrom,
  RoutePoint rawTo, {
  double maxMeters = 25,
  double maxGap = 1500,
}) {
  final from = snapToRoute(rawFrom, route, maxMeters: maxMeters);
  final to = snapToRoute(rawTo, route, maxMeters: maxMeters);
  if (from == null || to == null || to.along < from.along || to.along - from.along > maxGap) {
    return [rawFrom, to?.point ?? rawTo];
  }
  return [from.point, ...route.sublist(from.segment + 1, to.segment + 1), to.point];
}

/// Point [meters] ahead of [p] in direction [bearingDeg] (camera looks a little ahead).
RoutePoint pointAhead(RoutePoint p, double bearingDeg, double meters) {
  final d = meters / _earthRadius;
  final brg = _rad(bearingDeg);
  final lat1 = _rad(p.lat), lng1 = _rad(p.lng);
  final lat2 = math.asin(math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(brg));
  final lng2 = lng1 +
      math.atan2(math.sin(brg) * math.sin(d) * math.cos(lat1), math.cos(d) - math.sin(lat1) * math.sin(lat2));
  return (lat: lat2 * 180 / math.pi, lng: lng2 * 180 / math.pi);
}

/// Position [t] (0..1) of the way along [path], at constant speed.
RoutePoint pointAlongPath(List<RoutePoint> path, double t) {
  if (path.length == 1 || t <= 0) return path.first;
  if (t >= 1) return path.last;
  final lengths = <double>[];
  var total = 0.0;
  for (var i = 0; i < path.length - 1; i++) {
    final l = metersBetween(path[i], path[i + 1]);
    lengths.add(l);
    total += l;
  }
  if (total == 0) return path.last;
  var target = total * t;
  for (var i = 0; i < lengths.length; i++) {
    if (target <= lengths[i] || i == lengths.length - 1) {
      final f = lengths[i] == 0 ? 1.0 : (target / lengths[i]).clamp(0.0, 1.0);
      final a = path[i], b = path[i + 1];
      return (lat: a.lat + f * (b.lat - a.lat), lng: a.lng + f * (b.lng - a.lng));
    }
    target -= lengths[i];
  }
  return path.last;
}
