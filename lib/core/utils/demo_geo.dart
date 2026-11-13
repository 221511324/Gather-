import 'package:latlong2/latlong.dart';

/// Coordinates for the live tracking map (US11).
///
/// DEMO DATA — none of these points are real. The catalogue stores no lat/lng
/// for a restaurant and an address is a free-text line, so there is nothing
/// truthful to plot; an empty map would make the feature impossible to show.
/// Each point is therefore folded out of a hash of the id it belongs to, which
/// keeps it *stable*: a restaurant lands on the same corner of Riyadh on every
/// run and in every build, so a demo looks the same twice and screenshots stay
/// valid. Replace both lookups with stored coordinates once the catalogue and
/// the address book carry them — nothing else needs to change.
abstract final class DemoGeo {
  /// Central Riyadh, the city this project is scoped to.
  static const city = LatLng(24.7136, 46.6753);

  /// Keeps every generated point inside roughly 6 km of the centre, so a
  /// restaurant and its delivery address always fit on one small map.
  static const _spread = 0.055;

  /// The restaurant the order was placed with.
  static LatLng restaurant(String restaurantId) => _pointFor('restaurant:$restaurantId');

  /// The customer's door. Seeded from the address text when there is one, and
  /// from the order id otherwise, so an order without an address still plots.
  static LatLng delivery({required String address, required String orderId}) =>
      _pointFor('delivery:${address.isEmpty ? orderId : address}');

  /// FNV-1a over the seed, then two independent halves of the hash become the
  /// latitude and longitude offsets. A plain modulo of one hash would line
  /// every point up on a diagonal.
  static LatLng _pointFor(String seed) {
    var hash = 2166136261;
    for (final unit in seed.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    final latUnit = (hash & 0xffff) / 0xffff;
    final lngUnit = ((hash >> 16) & 0xffff) / 0xffff;
    return LatLng(
      city.latitude + (latUnit * 2 - 1) * _spread,
      city.longitude + (lngUnit * 2 - 1) * _spread,
    );
  }
}
