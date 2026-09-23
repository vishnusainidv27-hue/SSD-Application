import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService firestoreService;
  late PricingService pricingService;

  setUp(() {
    db = FakeFirebaseFirestore();
    firestoreService = FirestoreService(firestore: db);
    pricingService = PricingService(firestore: db);
  });

  Future<void> deliver(DateTime date, double qty, double rate) =>
      firestoreService.markDelivery(DeliveryModel(
        customerId: 'c1',
        date: date,
        milkType: MilkType.cow,
        quantityLitres: qty,
        rateApplied: rate,
        status: DeliveryStatus.delivered,
        deliveryBoyId: 'boy1',
      ));

  group('generateBill', () {
    test('Requirements §9 worked example: mixed rates, one skip, correct total',
        () async {
      for (var d = 1; d <= 14; d++) {
        await deliver(DateTime(2026, 8, d), 1, 62);
      }
      for (var d = 15; d <= 31; d++) {
        if (d == 20) continue; // customer skipped — no delivered row at all
        await deliver(DateTime(2026, 8, d), 1, 65);
      }

      final bill = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );

      expect(bill.totalAmount, 14 * 62 + 16 * 65); // 1,908 per the fixed §9
      expect(bill.previousDue, 0);
      expect(bill.netPayable, bill.totalAmount);
    });

    test('only counts delivered-status rows in the period', () async {
      await deliver(DateTime(2026, 8, 5), 1, 60);
      await firestoreService.markDelivery(DeliveryModel(
        customerId: 'c1',
        date: DateTime(2026, 8, 6),
        milkType: MilkType.cow,
        quantityLitres: 1,
        rateApplied: 60,
        status: DeliveryStatus.notDelivered,
        remark: 'Gate locked',
        deliveryBoyId: 'boy1',
      ));
      await deliver(DateTime(2026, 9, 1), 1, 60); // outside the period

      final bill = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      expect(bill.totalAmount, 60);
    });

    test('carries the previous bill\'s net payable forward as previousDue',
        () async {
      await deliver(DateTime(2026, 7, 15), 1, 60);
      await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 7, 1),
        periodTo: DateTime(2026, 7, 31),
      );

      await deliver(DateTime(2026, 8, 10), 1, 65);
      final august = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      expect(august.previousDue, 60);
      expect(august.totalAmount, 65);
      expect(august.netPayable, 125);
    });

    test('regenerating the same period preserves amountPaid already recorded',
        () async {
      await deliver(DateTime(2026, 8, 5), 1, 60);
      final first = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      await firestoreService.recordPayment(
        bill: first,
        amount: 20,
        mode: PaymentMode.cash,
        date: DateTime(2026, 8, 20),
        recordedBy: 'admin1',
      );

      // A late delivery mark arrives, and Admin regenerates the same period.
      await deliver(DateTime(2026, 8, 6), 1, 60);
      final regenerated = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      expect(regenerated.id, first.id);
      expect(regenerated.totalAmount, 120); // now includes the late mark
      expect(regenerated.amountPaid, 20); // payment preserved
      expect(regenerated.netPayable, 100);
    });

    test('rejects an end date before the start date', () async {
      await expectLater(
        pricingService.generateBill(
          customerId: 'c1',
          periodFrom: DateTime(2026, 8, 31),
          periodTo: DateTime(2026, 8, 1),
        ),
        throwsA(isA<PricingException>()),
      );
    });
  });

  group('recordPayment', () {
    test('a partial payment reduces netPayable and is visible in history',
        () async {
      await deliver(DateTime(2026, 8, 5), 1, 100);
      final bill = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      expect(bill.netPayable, 100);

      await firestoreService.recordPayment(
        bill: bill,
        amount: 40,
        mode: PaymentMode.upi,
        date: DateTime(2026, 8, 15),
        recordedBy: 'admin1',
      );

      final doc = await db.collection('bills').doc(bill.id).get();
      final updated = BillModel.fromFirestore(doc);
      expect(updated.amountPaid, 40);
      expect(updated.netPayable, 60);

      final payments = await firestoreService.watchPayments('c1').first;
      expect(payments, hasLength(1));
      expect(payments.single.amount, 40);
      expect(payments.single.mode, PaymentMode.upi);
    });

    test('multiple payments accumulate correctly', () async {
      await deliver(DateTime(2026, 8, 5), 1, 100);
      final bill = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      await firestoreService.recordPayment(
          bill: bill,
          amount: 30,
          mode: PaymentMode.cash,
          date: DateTime(2026, 8, 10),
          recordedBy: 'admin1');
      await firestoreService.recordPayment(
          bill: bill,
          amount: 70,
          mode: PaymentMode.bank,
          date: DateTime(2026, 8, 25),
          recordedBy: 'admin1');

      final doc = await db.collection('bills').doc(bill.id).get();
      final updated = BillModel.fromFirestore(doc);
      expect(updated.amountPaid, 100);
      expect(updated.netPayable, 0);
      expect(await firestoreService.watchPayments('c1').first, hasLength(2));
    });
  });

  group('range reports', () {
    test('getAllDeliveriesInRange only returns dates within range, any customer',
        () async {
      await deliver(DateTime(2026, 8, 1), 1, 60);
      await firestoreService.markDelivery(DeliveryModel(
        customerId: 'c2',
        date: DateTime(2026, 8, 15),
        milkType: MilkType.buffalo,
        quantityLitres: 1,
        rateApplied: 78,
        status: DeliveryStatus.delivered,
        deliveryBoyId: 'boy2',
      ));
      await deliver(DateTime(2026, 9, 1), 1, 65); // outside range

      final result = await firestoreService.getAllDeliveriesInRange(
          DateTime(2026, 8, 1), DateTime(2026, 8, 31));
      expect(result.map((d) => d.customerId).toSet(), {'c1', 'c2'});
    });

    test('getAllPaymentsInRange only returns dates within range', () async {
      await deliver(DateTime(2026, 8, 5), 1, 100);
      final bill = await pricingService.generateBill(
        customerId: 'c1',
        periodFrom: DateTime(2026, 8, 1),
        periodTo: DateTime(2026, 8, 31),
      );
      await firestoreService.recordPayment(
          bill: bill,
          amount: 100,
          mode: PaymentMode.cash,
          date: DateTime(2026, 8, 20),
          recordedBy: 'admin1');
      await firestoreService.recordPayment(
          bill: bill,
          amount: 50,
          mode: PaymentMode.cash,
          date: DateTime(2026, 9, 5),
          recordedBy: 'admin1');

      final result = await firestoreService.getAllPaymentsInRange(
          DateTime(2026, 8, 1), DateTime(2026, 8, 31));
      expect(result, hasLength(1));
      expect(result.single.amount, 100);
    });
  });
}
