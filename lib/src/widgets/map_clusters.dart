import 'dart:math' as math;

/// A group of map points close enough on screen to be drawn as one.
class MapCluster<T> {
  MapCluster._(this._seedX, this._seedY);

  final double _seedX;
  final double _seedY;
  final List<T> items = [];
  double _latSum = 0;
  double _lonSum = 0;

  /// Where the group is drawn: the middle of its points.
  double get latitude => _latSum / items.length;
  double get longitude => _lonSum / items.length;

  bool get isSingle => items.length == 1;

  void _add(T item, double lat, double lon) {
    items.add(item);
    _latSum += lat;
    _lonSum += lon;
  }
}

/// Groups points that would overlap at [zoom].
///
/// Thousands of courts drawn as pins at city scale are one grey smear, and
/// nobody can tap the one they want. Points are taken in order; each joins
/// the first group whose first point is within [radiusPx] screen pixels at
/// this zoom, or starts its own. A [radiusPx] of zero merges nothing. A grid of cells [radiusPx] wide keeps the
/// search to the nine cells around a point.
///
/// Pure arithmetic in Web Mercator pixels (the map's own projection), so it
/// is the same on every platform and runs in a test.
List<MapCluster<T>> clusterPoints<T>(
  Iterable<T> items, {
  required double Function(T) latitude,
  required double Function(T) longitude,
  required double zoom,
  double radiusPx = 56,
}) {
  if (radiusPx <= 0) {
    // Nothing merges: every point is its own pin.
    return [
      for (final item in items)
        MapCluster<T>._(0, 0).._add(item, latitude(item), longitude(item)),
    ];
  }
  final worldPx = 256 * math.pow(2, zoom).toDouble();
  final cells = <(int, int), List<MapCluster<T>>>{};
  final clusters = <MapCluster<T>>[];
  for (final item in items) {
    final lat = latitude(item);
    final lon = longitude(item);
    final (x, y) = _project(lat, lon, worldPx);
    final cx = (x / radiusPx).floor();
    final cy = (y / radiusPx).floor();
    MapCluster<T>? home;
    search:
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final cluster in cells[(cx + dx, cy + dy)] ?? <MapCluster<T>>[]) {
          final ddx = cluster._seedX - x;
          final ddy = cluster._seedY - y;
          if (ddx * ddx + ddy * ddy <= radiusPx * radiusPx) {
            home = cluster;
            break search;
          }
        }
      }
    }
    if (home == null) {
      home = MapCluster<T>._(x, y);
      (cells[(cx, cy)] ??= []).add(home);
      clusters.add(home);
    }
    home._add(item, lat, lon);
  }
  return clusters;
}

(double, double) _project(double lat, double lon, double worldPx) {
  final clamped = lat.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  final x = (lon + 180) / 360 * worldPx;
  final y =
      (1 - math.log(math.tan(clamped) + 1 / math.cos(clamped)) / math.pi) /
      2 *
      worldPx;
  return (x, y);
}
