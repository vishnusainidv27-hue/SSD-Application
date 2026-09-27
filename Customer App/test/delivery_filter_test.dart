import 'package:customer_app/utils/delivery_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  DeliveryModel d(
    DateTime date, {
    MilkType type = MilkType.cow,
    DeliveryStatus status = DeliveryStatus.delivered,
    double qty = 1,
  }) =>
      DeliveryModel(
        customerId: 'c1',
        date: date,
        milkType: type,
        quantityLitres: qty,
        rateApplied: 60,
        status: status,
      );

  final deliveries = [
    d(DateTime(2026, 8, 1)),
    d(DateTime(2026, 8, 14), type: MilkType.buffalo),
    d(DateTime(2026, 8, 20), status: DeliveryStatus.skipped),
    d(DateTime(2026, 9, 1)),
  ];

  test('no filters returns everyone', () {
    expect(filterDeliveries(deliveries), hasLength(4));
  });

  test('date range is inclusive on both ends', () {
    final result = filterDeliveries(deliveries,
        from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 14));
    expect(result.map((d) => d.date),
        [DateTime(2026, 8, 1), DateTime(2026, 8, 14)]);
  });

  test('milk type filter', () {
    expect(filterDeliveries(deliveries, milkType: MilkType.buffalo),
        hasLength(1));
  });

  test('status filter', () {
    expect(
        filterDeliveries(deliveries, status: DeliveryStatus.skipped),
        hasLength(1));
  });

  test('filters combine', () {
    final result = filterDeliveries(
      deliveries,
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
      status: DeliveryStatus.delivered,
    );
    expect(result, hasLength(2));
  });

  test('amount is quantity times rate', () {
    expect(d(DateTime(2026, 8, 1), qty: 1.5).amount, 90);
  });
}
