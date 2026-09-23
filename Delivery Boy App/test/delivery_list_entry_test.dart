import 'package:delivery_boy_app/utils/delivery_list_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  CustomerModel customer(
    String id,
    String name, {
    String society = 'Green Valley',
    String block = 'A',
    String flat = '101',
  }) =>
      CustomerModel(
        id: id,
        name: name,
        mobile: '9999999999',
        societyName: society,
        blockName: block,
        floor: '1',
        flatNumber: flat,
        landmark: '',
        finalAddress: '',
      );

  DeliveryModel delivery(String customerId) => DeliveryModel(
        customerId: customerId,
        date: DateTime(2026, 9, 25),
        milkType: MilkType.cow,
        quantityLitres: 1,
        rateApplied: 60,
        status: DeliveryStatus.pending,
        deliveryBoyId: 'boy1',
      );

  DeliveryListEntry entry(CustomerModel c) =>
      DeliveryListEntry(delivery: delivery(c.id), customer: c);

  group('filterDeliveryEntries', () {
    final entries = [
      entry(customer('1', 'Asha Rao', society: 'Lake View')),
      entry(customer('2', 'Ravi Kumar', society: 'Green Valley')),
    ];

    test('empty query returns everyone', () {
      expect(filterDeliveryEntries(entries), hasLength(2));
    });

    test('matches by customer name', () {
      expect(filterDeliveryEntries(entries, query: 'ravi'), hasLength(1));
    });

    test('matches by society', () {
      expect(filterDeliveryEntries(entries, query: 'lake'), hasLength(1));
    });
  });

  group('groupBySocietyAndBlock', () {
    test('groups and sorts society then block alphabetically', () {
      final entries = [
        entry(customer('1', 'Zara', society: 'Sunrise', block: 'B')),
        entry(customer('2', 'Amit', society: 'Sunrise', block: 'A')),
        entry(customer('3', 'Neha', society: 'Green Valley', block: 'A')),
      ];
      final grouped = groupBySocietyAndBlock(entries);
      expect(grouped.keys.toList(), ['Green Valley', 'Sunrise']);
      expect(grouped['Sunrise']!.keys.toList(), ['A', 'B']);
    });

    test('sorts entries within a block by flat number', () {
      final entries = [
        entry(customer('1', 'A', flat: '302')),
        entry(customer('2', 'B', flat: '101')),
      ];
      final grouped = groupBySocietyAndBlock(entries);
      final flats = [
        for (final e in grouped['Green Valley']!['A']!) e.customer.flatNumber,
      ];
      expect(flats, ['101', '302']);
    });

    test('customers with no society/block get a fallback bucket', () {
      final entries = [entry(customer('1', 'A', society: '', block: ''))];
      final grouped = groupBySocietyAndBlock(entries);
      expect(grouped.keys.single, '(No society)');
      expect(grouped.values.single.keys.single, '(No block)');
    });
  });
}
