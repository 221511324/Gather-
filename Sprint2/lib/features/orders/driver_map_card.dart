import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/utils/demo_geo.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/state_views.dart';

/// The driver's position on a map, for the order tracking screen (US11).
///
/// OpenStreetMap tiles rather than Google Maps: the team has no Maps API key,
/// and a map that cannot render is worse than no map. Tiles are also the only
/// part of this that needs the network — markers and the route line are drawn
/// by us, so a failed tile fetch leaves a plain coloured map with the three
/// pins still correct rather than a broken widget.
class DriverMapCard extends StatelessWidget {
  const DriverMapCard({super.key, required this.order});

  final FoodOrder order;

  /// How tall the map reads well at phone width without pushing the timeline
  /// off the first screen.
  static const _mapHeight = 220.0;

  @override
  Widget build(BuildContext context) {
    final lat = order.driverLat;
    final lng = order.driverLng;
    // Defensive: the screen only builds this card for an order with a driver,
    // but a position that arrives half-written must not throw.
    if (lat == null || lng == null) return const SizedBox.shrink();

    final driver = LatLng(lat, lng);
    final restaurant = DemoGeo.restaurant(order.restaurantId);
    final delivery = DemoGeo.delivery(address: order.deliveryAddress, orderId: order.id);
    final stage = order.driverStage ?? DriverStage.assigned;

    return GatherCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(order: order, stage: stage),
          SizedBox(
            height: _mapHeight,
            child: FlutterMap(
              options: MapOptions(
                // Framed on all three points, which is also what keeps the
                // driver in view: the fit is applied once and never again, and
                // every simulated position lies on the restaurant → customer
                // line, so it can never leave the frame. Not re-fitting also
                // means a position update does not undo the user's own pan.
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [restaurant, delivery, driver],
                  padding: const EdgeInsets.all(Insets.xxxl),
                  maxZoom: 15,
                ),
                // Rotation only ever happens by accident inside a scrolling
                // list, and a tilted map is hard to read.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                backgroundColor: AppColors.surfaceAlt,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OSM's tile policy asks for an identifying user agent.
                  userAgentPackageName: 'edu.psu.gather',
                ),
                PolylineLayer(
                  polylines: [
                    // The whole run, faint, so the two endpoints read as one
                    // journey even before the driver moves.
                    Polyline(
                      points: [restaurant, delivery],
                      color: AppColors.inkFaint,
                      strokeWidth: 3,
                      pattern: const StrokePattern.dotted(),
                    ),
                    // The leg the driver is actually on: toward the restaurant
                    // until the pickup, toward the customer after it.
                    Polyline(
                      points: [driver, stage.hasOrder ? delivery : restaurant],
                      color: AppColors.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    _pin(
                      point: restaurant,
                      icon: Icons.storefront_rounded,
                      color: AppColors.accentDeep,
                    ),
                    _pin(
                      point: delivery,
                      icon: Icons.home_rounded,
                      color: AppColors.ink,
                    ),
                    _pin(
                      point: driver,
                      icon: Icons.delivery_dining_rounded,
                      color: AppColors.primary,
                      emphasised: true,
                    ),
                  ],
                ),
                SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors', style: AppType.caption),
                  backgroundColor: AppColors.surface,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.description, style: AppType.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: Insets.md),
                Row(
                  children: [
                    const _Legend(
                      icon: Icons.storefront_rounded,
                      color: AppColors.accentDeep,
                      label: 'Restaurant',
                    ),
                    const SizedBox(width: Insets.md),
                    const _Legend(
                      icon: Icons.home_rounded,
                      color: AppColors.ink,
                      label: 'You',
                    ),
                    const Spacer(),
                    // Said plainly, because a dot on a map always looks live
                    // even when the last report is minutes old.
                    if (order.driverUpdatedAt != null)
                      Text(_freshness(order.driverUpdatedAt!), style: AppType.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Marker _pin({
    required LatLng point,
    required IconData icon,
    required Color color,
    bool emphasised = false,
  }) =>
      Marker(
        point: point,
        width: 38,
        height: 38,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2.5),
            boxShadow: emphasised ? Shadows.glow(color) : Shadows.card,
          ),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      );

  static String _freshness(DateTime at) {
    final minutes = DateTime.now().difference(at).inMinutes;
    if (minutes <= 0) return 'Updated just now';
    if (minutes == 1) return 'Updated 1 min ago';
    return 'Updated $minutes min ago';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.stage});

  final FoodOrder order;
  final DriverStage stage;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.lg, Insets.lg, Insets.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delivery_dining_rounded,
                size: 22,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(order.driverName ?? 'Your driver', style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(stage.label, style: AppType.caption.copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            if (order.driverPhone != null)
              StatusPill(
                label: order.driverPhone!,
                color: AppColors.inkMuted,
                icon: Icons.phone_rounded,
                compact: true,
              ),
          ],
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppType.caption),
        ],
      );
}
