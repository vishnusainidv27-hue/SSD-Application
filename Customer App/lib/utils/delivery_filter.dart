import 'package:ssd_shared/ssd_shared.dart';

/// Applies the Delivery History screen's date-range, milk-type and status
/// filters (Requirements §5.3). Mirrors the Admin app's
/// `utils/customer_filter.dart` — a pure, testable function, since Firestore
/// rules already restrict the underlying query to this customer's own docs.
List<DeliveryModel> filterDeliveries(
  List<DeliveryModel> deliveries, {
  DateTime? from,
  DateTime? to,
  MilkType? milkType,
  DeliveryStatus? status,
}) {
  return [
    for (final d in deliveries)
      if ((from == null || !d.date.isBefore(from)) &&
          (to == null || !d.date.isAfter(to)) &&
          (milkType == null || d.milkType == milkType) &&
          (status == null || d.status == status))
        d,
  ];
}
