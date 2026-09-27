import '../models/delivery_exception_model.dart';
import '../models/price_model.dart';
import '../models/subscription_model.dart';

/// What a customer is scheduled to get for one milk type on one day, after
/// applying any in-effect exception for that date (Requirements §5.2: "Today's
/// /tomorrow's scheduled delivery").
///
/// Pure and Firestore-free, so it works the same on the dashboard today and
/// inside the Phase 6 delivery-list generator later.
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
/// [exceptions] applied. Callers may pass exceptions of any status — only
/// `approved` ones affect the plan (Requirements §5.5: "the old/default
/// quantity remains in effect until approved"); `pending`/`rejected` ones are
/// ignored here.
///
/// A `single`-scope exception applies only on its own date; an `onward` one
/// applies from its date forward until superseded by a later `approved`
/// exception for the same milk type (or, for a skip, any milk type) — the
/// same "date-effective, most-recent-wins" pattern [PricingService] uses for
/// prices. On a tie (two exceptions effective on the same date for the same
/// type), a skip wins over a quantity change, matching the same-day rule; if
/// both are the same kind, the more recently created one wins.
List<PlannedDelivery> plannedDeliveriesForDate({
  required List<SubscriptionModel> subscriptions,
  required List<DeliveryExceptionModel> exceptions,
  required DateTime date,
}) {
  final day = PriceModel.dateOnly(date);
  final inEffect = [
    for (final e in exceptions)
      if (e.status == ExceptionStatus.approved && _covers(e, day)) e,
  ];

  // "Most recent wins": order candidates so the one that should apply ends up
  // last, then simply overwrite as we go.
  final ranked = [...inEffect]..sort(_byRecency);

  DeliveryExceptionModel? skip;
  final quantityByType = <MilkType, DeliveryExceptionModel>{};
  for (final e in ranked) {
    if (e.type == ExceptionType.skip) {
      skip = e;
    } else if (e.milkType != null) {
      quantityByType[e.milkType!] = e;
    }
  }

  return [
    for (final sub in subscriptions)
      if (sub.active && !day.isBefore(PriceModel.dateOnly(sub.startDate)))
        _plan(sub, skip, quantityByType[sub.milkType]),
  ];
}

bool _covers(DeliveryExceptionModel e, DateTime day) {
  return e.appliesFrom == ExceptionScope.onward
      ? !day.isBefore(e.date)
      : e.date == day;
}

/// Sorts so the exception that should win ends up last: later
/// [DeliveryExceptionModel.date] wins; on a tie, a skip outranks a quantity
/// change; a further tie (same date, same kind) falls back to whichever was
/// created more recently (nulls — not yet server-timestamped — sort first).
int _byRecency(DeliveryExceptionModel a, DeliveryExceptionModel b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final aIsSkip = a.type == ExceptionType.skip;
  final bIsSkip = b.type == ExceptionType.skip;
  if (aIsSkip != bIsSkip) return aIsSkip ? -1 : 1; // skip sorts last (wins)
  final aCreated = a.createdAt;
  final bCreated = b.createdAt;
  if (aCreated == null || bCreated == null) return 0;
  return aCreated.compareTo(bCreated);
}

PlannedDelivery _plan(SubscriptionModel sub,
    DeliveryExceptionModel? skip, DeliveryExceptionModel? quantityChange) {
  if (skip != null) {
    return PlannedDelivery(
      milkType: sub.milkType,
      quantityLitres: sub.quantityLitres,
      skipped: true,
    );
  }
  return PlannedDelivery(
    milkType: sub.milkType,
    quantityLitres: quantityChange?.requestedQty ?? sub.quantityLitres,
    skipped: false,
  );
}
