import '../models/delivery_exception_model.dart';
import '../models/price_model.dart';
import '../models/subscription_model.dart';

/// What a customer is scheduled to get for one milk type on one day, after
/// applying any Admin-set exception for that date (Requirements §5.2: "Today's
/// /tomorrow's scheduled delivery").
///
/// Pure and Firestore-free, so it works the same on the dashboard today and
/// inside the Phase 6 delivery-list generator later. Only handles daily
/// subscriptions and single-date exceptions — the only kinds either side
/// creates so far (see PROJECT_STATUS.md's Phase 3 "left open" note).
class PlannedDelivery {
  const PlannedDelivery({
    required this.milkType,
    required this.quantityLitres,
    required this.skipped,
  });

  final MilkType milkType;

  /// The quantity that would be delivered if not skipped (already reflects
  /// any quantity-change exception for the day).
  final double quantityLitres;
  final bool skipped;
}

/// What [subscriptions] (as of [date]) would be delivered on [date], with
/// [exceptions] applied. A skip exception always wins over a quantity change
/// for the same day (matches [DeliveryExceptionModel]'s own rule). Only
/// active subscriptions that had started by [date] are included.
List<PlannedDelivery> plannedDeliveriesForDate({
  required List<SubscriptionModel> subscriptions,
  required List<DeliveryExceptionModel> exceptions,
  required DateTime date,
}) {
  final day = PriceModel.dateOnly(date);
  final dayExceptions = [for (final e in exceptions) if (e.date == day) e];
  final skipAll = dayExceptions.any((e) => e.type == ExceptionType.skip);
  final quantityOverrides = {
    for (final e in dayExceptions)
      if (e.type == ExceptionType.quantityChange && e.milkType != null)
        e.milkType!: e.requestedQty ?? 0,
  };

  return [
    for (final sub in subscriptions)
      if (sub.active && !day.isBefore(PriceModel.dateOnly(sub.startDate)))
        PlannedDelivery(
          milkType: sub.milkType,
          quantityLitres: quantityOverrides[sub.milkType] ?? sub.quantityLitres,
          skipped: skipAll,
        ),
  ];
}
