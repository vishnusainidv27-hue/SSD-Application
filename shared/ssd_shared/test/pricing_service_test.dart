import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PricingService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = PricingService(firestore: db);
  });

  Future<void> setRate(MilkType t, double rate, DateTime from) =>
      service.setNewRate(
          milkType: t, ratePerLitre: rate, effectiveFrom: from, changedBy: 'u1');

  test('first rate is open-ended', () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    final prices = await service.pricesFor(MilkType.cow);
    expect(prices, hasLength(1));
    expect(prices.single.effectiveTo, isNull);
    expect(prices.single.ratePerLitre, 62);
  });

  test('new rate closes the previous one the day before', () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    await setRate(MilkType.cow, 65, DateTime(2026, 8, 15));
    final prices = await service.pricesFor(MilkType.cow);
    expect(prices, hasLength(2));
    expect(prices[0].effectiveTo, DateTime(2026, 8, 14));
    expect(prices[1].effectiveFrom, DateTime(2026, 8, 15));
    expect(prices[1].effectiveTo, isNull);
  });

  test('closing across a month boundary uses the real previous day', () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    await setRate(MilkType.cow, 65, DateTime(2026, 9, 1));
    final prices = await service.pricesFor(MilkType.cow);
    expect(prices[0].effectiveTo, DateTime(2026, 8, 31));
  });

  test('worked example from Requirements §9 prices each day correctly',
      () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    await setRate(MilkType.cow, 65, DateTime(2026, 8, 15));
    expect(await service.rateEffectiveOn(MilkType.cow, DateTime(2026, 8, 14)), 62);
    expect(await service.rateEffectiveOn(MilkType.cow, DateTime(2026, 8, 15)), 65);
    expect(await service.rateEffectiveOn(MilkType.cow, DateTime(2026, 8, 31)), 65);
    expect(await service.rateEffectiveOn(MilkType.cow, DateTime(2026, 7, 1)), 62);

    var total = 0.0;
    for (var d = 1; d <= 31; d++) {
      if (d == 20) continue; // customer skipped
      total +=
          (await service.rateEffectiveOn(MilkType.cow, DateTime(2026, 8, d)))!;
    }
    // 14 days at 62 + 16 days at 65 (17 days from the 15th, minus the skip).
    expect(total, 14 * 62 + 16 * 65);
  });

  test('no rate before the first record started', () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    expect(await service.rateEffectiveOn(MilkType.cow, DateTime(2026, 6, 30)),
        isNull);
  });

  test('milk types are priced independently', () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    await setRate(MilkType.buffalo, 78, DateTime(2026, 7, 1));
    await setRate(MilkType.cow, 65, DateTime(2026, 8, 15));
    expect(
        await service.rateEffectiveOn(MilkType.buffalo, DateTime(2026, 9, 1)),
        78);
    expect((await service.pricesFor(MilkType.buffalo)).single.effectiveTo,
        isNull);
  });

  test('rejects a start date that would rewrite history', () async {
    await setRate(MilkType.cow, 65, DateTime(2026, 8, 15));
    await expectLater(setRate(MilkType.cow, 60, DateTime(2026, 8, 15)),
        throwsA(isA<PricingException>()));
    await expectLater(setRate(MilkType.cow, 60, DateTime(2026, 8, 1)),
        throwsA(isA<PricingException>()));
    expect(await service.pricesFor(MilkType.cow), hasLength(1));
  });

  test('rejects a non-positive rate', () async {
    await expectLater(setRate(MilkType.cow, 0, DateTime(2026, 8, 1)),
        throwsA(isA<PricingException>()));
  });

  test('stored dates are timezone-independent UTC midnight', () async {
    await setRate(MilkType.cow, 62, DateTime(2026, 7, 1));
    final doc = (await db.collection('priceList').get()).docs.single;
    final ts = doc['effectiveFrom'] as Timestamp;
    expect(ts.toDate().toUtc(), DateTime.utc(2026, 7, 1));
  });
}
