import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  late FirestoreService service;

  setUp(() {
    service = FirestoreService(firestore: FakeFirebaseFirestore());
  });

  DeliveryExceptionModel skip(String customer, DateTime d) =>
      DeliveryExceptionModel(
          customerId: customer, date: d, type: ExceptionType.skip);

  test('a skip always applies to all milk types', () {
    final e = DeliveryExceptionModel(
      customerId: 'c1',
      date: DateTime(2026, 9, 25),
      type: ExceptionType.skip,
      milkType: MilkType.cow,
    );
    expect(e.milkType, isNull);
    expect(e.id, 'c1_20260925_skip_all');
  });

  test('quantity changes are per milk type and keep the quantity', () {
    final e = DeliveryExceptionModel(
      customerId: 'c1',
      date: DateTime(2026, 9, 25),
      type: ExceptionType.quantityChange,
      milkType: MilkType.buffalo,
      requestedQty: 1.5,
    );
    expect(e.id, 'c1_20260925_qty_buffalo');
    expect(e.milkType, MilkType.buffalo);
  });

  test('save then watch returns the customer\'s exceptions, soonest first',
      () async {
    await service.saveExceptions([
      skip('c1', DateTime(2026, 9, 28)),
      skip('c1', DateTime(2026, 9, 26)),
      skip('c2', DateTime(2026, 9, 27)),
    ]);
    final list = await service.watchExceptions('c1').first;
    expect([for (final e in list) e.date.day], [26, 28]);
    expect(list.every((e) => e.status == ExceptionStatus.approved), isTrue);
  });

  test('saving the same date again overwrites instead of duplicating',
      () async {
    await service.saveExceptions([skip('c1', DateTime(2026, 9, 26))]);
    await service.saveExceptions([skip('c1', DateTime(2026, 9, 26))]);
    expect(await service.watchExceptions('c1').first, hasLength(1));
  });

  test('delete removes an exception', () async {
    final e = skip('c1', DateTime(2026, 9, 26));
    await service.saveExceptions([e]);
    await service.deleteException(e.id);
    expect(await service.watchExceptions('c1').first, isEmpty);
  });

  test('round-trips through Firestore', () async {
    await service.saveExceptions([
      DeliveryExceptionModel(
        customerId: 'c1',
        date: DateTime(2026, 10, 2),
        type: ExceptionType.quantityChange,
        milkType: MilkType.cow,
        requestedQty: 2,
        approvedBy: 'admin1',
      ),
    ]);
    final e = (await service.watchExceptions('c1').first).single;
    expect(e.date, DateTime(2026, 10, 2));
    expect(e.type, ExceptionType.quantityChange);
    expect(e.milkType, MilkType.cow);
    expect(e.requestedQty, 2);
    expect(e.approvedBy, 'admin1');
  });
}
