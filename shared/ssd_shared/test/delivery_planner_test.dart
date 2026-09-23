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

  test('an approved skip exception skips every subscribed milk type that day',
      () {
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

  test('a pending or rejected exception is ignored', () {
    for (final status in [ExceptionStatus.pending, ExceptionStatus.rejected]) {
      final result = plannedDeliveriesForDate(
        subscriptions: [sub(MilkType.cow)],
        exceptions: [
          DeliveryExceptionModel(
            customerId: 'c1',
            date: today,
            type: ExceptionType.skip,
            status: status,
          ),
        ],
        date: today,
      );
      expect(result.single.skipped, isFalse, reason: 'status: $status');
    }
  });

  test('a single-scope skip on a different date does not affect this one', () {
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

  test(
      'an onward quantity change applies on and after its date, until a later '
      'one supersedes it', () {
    final exceptions = [
      DeliveryExceptionModel(
        customerId: 'c1',
        date: DateTime(2026, 9, 20),
        type: ExceptionType.quantityChange,
        milkType: MilkType.cow,
        requestedQty: 2,
        appliesFrom: ExceptionScope.onward,
      ),
      DeliveryExceptionModel(
        customerId: 'c1',
        date: DateTime(2026, 10, 1),
        type: ExceptionType.quantityChange,
        milkType: MilkType.cow,
        requestedQty: 3,
        appliesFrom: ExceptionScope.onward,
      ),
    ];
    double qtyOn(DateTime d) => plannedDeliveriesForDate(
          subscriptions: [sub(MilkType.cow, qty: 1)],
          exceptions: exceptions,
          date: d,
        ).single.quantityLitres;

    expect(qtyOn(DateTime(2026, 9, 19)), 1); // before either
    expect(qtyOn(DateTime(2026, 9, 20)), 2); // first onward starts
    expect(qtyOn(DateTime(2026, 9, 30)), 2); // still the first
    expect(qtyOn(DateTime(2026, 10, 1)), 3); // second supersedes it
    expect(qtyOn(DateTime(2026, 12, 25)), 3); // still the second, far later
  });

  test('a skip is always single-scope even if onward is requested', () {
    final e = DeliveryExceptionModel(
      customerId: 'c1',
      date: DateTime(2026, 9, 20),
      type: ExceptionType.skip,
      appliesFrom: ExceptionScope.onward,
    );
    expect(e.appliesFrom, ExceptionScope.single);

    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow)],
      exceptions: [e],
      date: DateTime(2026, 9, 25), // after the skip's date
    );
    expect(result.single.skipped, isFalse);
  });

  test(
      'a same-day skip wins over a same-day quantity change for that type '
      '(both single-scope)', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow, qty: 1)],
      exceptions: [
        DeliveryExceptionModel(
          customerId: 'c1',
          date: today,
          type: ExceptionType.quantityChange,
          milkType: MilkType.cow,
          requestedQty: 2,
        ),
        DeliveryExceptionModel(
            customerId: 'c1', date: today, type: ExceptionType.skip),
      ],
      date: today,
    );
    expect(result.single.skipped, isTrue);
  });

  test('an onward skip beats an earlier onward quantity change', () {
    final result = plannedDeliveriesForDate(
      subscriptions: [sub(MilkType.cow, qty: 1)],
      exceptions: [
        DeliveryExceptionModel(
          customerId: 'c1',
          date: DateTime(2026, 9, 1),
          type: ExceptionType.quantityChange,
          milkType: MilkType.cow,
          requestedQty: 2,
          appliesFrom: ExceptionScope.onward,
        ),
        DeliveryExceptionModel(
          customerId: 'c1',
          date: DateTime(2026, 9, 20),
          type: ExceptionType.skip,
          appliesFrom: ExceptionScope.onward, // forced back to single
        ),
      ],
      date: today, // 25 Sep: after the skip's date, before nothing supersedes
    );
    // The skip is forced to single-scope, so by 25 Sep it no longer applies —
    // only the 1 Sep onward quantity change (2 L) is still in effect.
    expect(result.single.skipped, isFalse);
    expect(result.single.quantityLitres, 2);
  });
}
