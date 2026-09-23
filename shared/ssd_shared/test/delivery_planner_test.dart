import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  SubscriptionModel sub(
    MilkType type, {
    double qty = 1.0,
    DateTime? start,
    bool active = true,
  }) =>
      SubscriptionModel(
        id: 'c1_${type.name}',
        customerId: 'c1',
        milkType: type,
        quantityLitres: qty,
        frequency: 'daily',
        startDate: start ?? DateTime(2026, 1, 1),
        active: active,
      );

  final today = DateTime(2026, 9, 25);

  test('with no exceptions, delivers the subscribed quantity for each type',
      () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow, qty: 1), sub(MilkType.buffalo, qty: 0.5)],
      exceptions: const [],
      date: today,
    );
    expect(result, hasLength(2));
    expect(result.every((d) => !d.skipped), isTrue);
    expect(result.firstWhere((d) => d.milkType == MilkType.cow).quantityLitres, 1);
    expect(
        result.firstWhere((d) => d.milkType == MilkType.buffalo).quantityLitres,
        0.5);
  });

  test('a skip exception skips every subscribed milk type that day', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow), sub(MilkType.buffalo)],
      exceptions: [
        DeliveryExceptionModel(
            customerId: 'c1', date: today, type: ExceptionType.skip),
      ],
      date: today,
    );
    expect(result.every((d) => d.skipped), isTrue);
  });

  test('a skip on a different date does not affect this one', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow)],
      exceptions: [
        DeliveryExceptionModel(
            customerId: 'c1',
            date: today.add(const Duration(days: 1)),
            type: ExceptionType.skip),
      ],
      date: today,
    );
    expect(result.single.skipped, isFalse);
  });

  test('a quantity-change exception overrides just that milk type', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow, qty: 1), sub(MilkType.buffalo, qty: 1)],
      exceptions: [
        DeliveryExceptionModel(
          customerId: 'c1',
          date: today,
          type: ExceptionType.quantityChange,
          milkType: MilkType.cow,
          requestedQty: 2,
        ),
      ],
      date: today,
    );
    expect(result.firstWhere((d) => d.milkType == MilkType.cow).quantityLitres, 2);
    expect(
        result.firstWhere((d) => d.milkType == MilkType.buffalo).quantityLitres,
        1);
  });

  test('an inactive subscription is not delivered', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow, active: false)],
      exceptions: const [],
      date: today,
    );
    expect(result, isEmpty);
  });

  test('a subscription is not delivered before its start date', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow, start: DateTime(2026, 10, 1))],
      exceptions: const [],
      date: today,
    );
    expect(result, isEmpty);
  });
}
