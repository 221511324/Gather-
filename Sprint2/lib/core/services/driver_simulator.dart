import 'package:latlong2/latlong.dart';

import '../models/order.dart';
import '../utils/demo_geo.dart';
import 'order_service.dart';
import 'result.dart';

/// A stand-in for the driver app that this project does not have (US11).
///
/// SIMULATION ONLY. Nothing here observes a real position: [step] walks a made
/// up driver one stage further along the restaurant → customer run and writes
/// that as if it had come from a phone. It exists so the tracking map can be
/// demonstrated — the admin order screen drives it, and the tracking screen
/// keeps a debug control for the same thing. When a real driver app starts
/// calling [OrderService.updateDriverLocation], delete this file; the model,
/// the service and the map do not depend on it.
abstract final class DriverSimulator {
  /// A fixed crew of one, so the demo driver has a name and a number to call.
  static const driverName = 'Faisal A.';
  static const driverPhone = '+966 50 118 2244';

  /// The next stage of the run, or null once the driver has arrived and there
  /// is nothing left to simulate.
  static DriverStage? nextStage(DriverStage? current) {
    if (current == null) return DriverStage.assigned;
    final next = current.index + 1;
    return next >= DriverStage.values.length ? null : DriverStage.values[next];
  }

  /// Where a driver at [stage] stands. The whole run is laid out along the
  /// straight line between the two endpoints: before the pickup the driver
  /// closes in on the restaurant, after it on the customer. A real route would
  /// follow roads, but a monotone walk is enough to read the stages off a map.
  static LatLng positionFor({
    required DriverStage stage,
    required LatLng restaurant,
    required LatLng delivery,
  }) =>
      switch (stage) {
        DriverStage.assigned => _lerp(delivery, restaurant, 0.3),
        DriverStage.headingToRestaurant => _lerp(delivery, restaurant, 0.72),
        // Waiting at the door and leaving with the order are the same spot —
        // the difference the client asked about is the stage, not the pin.
        DriverStage.atRestaurant => restaurant,
        DriverStage.pickedUp => restaurant,
        DriverStage.onTheWay => _lerp(restaurant, delivery, 0.55),
        DriverStage.arrived => delivery,
      };

  /// Advances [order]'s driver by one stage. Returns an [Err] when the run is
  /// already finished so the caller can say so instead of silently doing
  /// nothing.
  static Future<Result<DriverStage>> step({
    required OrderService service,
    required FoodOrder order,
  }) async {
    final stage = nextStage(order.driverStage);
    if (stage == null) return const Err('The driver has already arrived');

    final position = positionFor(
      stage: stage,
      restaurant: DemoGeo.restaurant(order.restaurantId),
      delivery: DemoGeo.delivery(address: order.deliveryAddress, orderId: order.id),
    );

    final result = await service.updateDriverLocation(
      orderId: order.id,
      lat: position.latitude,
      lng: position.longitude,
      stage: stage,
      driverName: order.driverName == null ? driverName : null,
      driverPhone: order.driverPhone == null ? driverPhone : null,
    );
    return result.when(ok: (_) => Ok(stage), err: Err.new);
  }

  static LatLng _lerp(LatLng from, LatLng to, double t) => LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
}
