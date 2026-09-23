import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService firestoreService;
  late PricingService pricingService;
  late DeliveryPlanningService planningService;

  final today = DateTime(2026, 9, 25);

  setUp(() {
    db = FakeFirebaseFirestore();
    firestoreService = FirestoreService(firestore: db);
    pricingService = PricingService(firestore: db);
    planningService = DeliveryPlanningService(
      firestoreService: firestoreService,
      pricingService: pricingService,
      firestore: db,
    );
  });

  CustomerModel customer(
    String id, {
    bool active = true,
    String? boyId = 'boy1',
    List<MilkType> milk = const [MilkType.cow],
  }) =>
      CustomerModel(
        id: id,
        name: 'Customer $id',
        mobile: '9999999999',
        societyName: 'Green Valley',
        blockName: 'A',
        floor: '1',
        flatNumber: '101',
        landmark: '',
        finalAddress: '',
        milkTypes: milk,
        active: active,
        assignedDeliveryBoyId: boyId,
      );

  SubscriptionModel sub(String customerId, MilkType type, {double qty = 1}) =>
      SubscriptionModel(
        id: '${customerId}_${type.name}',
        customerId: customerId,
        milkType: type,
        quantityLitres: qty,
        frequency: 'daily',
        startDate: DateTime(2026, 1, 1),
      );

  Future<void> setup({
    required CustomerModel c,
    required List<SubscriptionModel> subs,
  }) async {
    await db.collection('customers').doc(c.id).set(c.toMap());
    for (final s in subs) {
      await db.collection('subscriptions').doc(s.id).set(s.toMap());
    }
  }

  test('generates a pending delivery per subscribed milk type, at today\'s rate',
      () async {
    await pricingService.setNewRate(
        milkType: MilkType.cow,
        ratePerLitre: 62,
        effectiveFrom: DateTime(2026, 1, 1),
        changedBy: 'admin1');
    await setup(
      c: customer('c1', milk: [MilkType.cow]),
      subs: [sub('c1', MilkType.cow, qty: 1.5)],
    );

    final created = await planningService.generateDeliveriesForDate(today);
    expect(created, 1);

    final deliveries = await firestoreService.watchDeliveries('c1').first;
    expect(deliveries, hasLength(1));
    expect(deliveries.single.status, DeliveryStatus.pending);
    expect(deliveries.single.quantityLitres, 1.5);
    expect(deliveries.single.rateApplied, 62);
    expect(deliveries.single.deliveryBoyId, 'boy1');
  });

  test('an approved skip generates a skipped row with zero quantity',
      () async {
    await setup(
      c: customer('c1'),
      subs: [sub('c1', MilkType.cow)],
    );
    await firestoreService.saveExceptions([
      DeliveryExceptionModel(
          customerId: 'c1', date: today, type: ExceptionType.skip),
    ]);

    await planningService.generateDeliveriesForDate(today);
    final delivery = (await firestoreService.watchDeliveries('c1').first).single;
    expect(delivery.status, DeliveryStatus.skipped);
    expect(delivery.quantityLitres, 0);
  });

  test('skips customers with no assigned delivery boy', () async {
    await setup(
      c: customer('c1', boyId: null),
      subs: [sub('c1', MilkType.cow)],
    );
    final created = await planningService.generateDeliveriesForDate(today);
    expect(created, 0);
  });

  test('skips inactive customers', () async {
    await setup(
      c: customer('c1', active: false),
      subs: [sub('c1', MilkType.cow)],
    );
    final created = await planningService.generateDeliveriesForDate(today);
    expect(created, 0);
  });

  test('is idempotent: running twice does not duplicate or overwrite marks',
      () async {
    await setup(
      c: customer('c1'),
      subs: [sub('c1', MilkType.cow)],
    );
    await planningService.generateDeliveriesForDate(today);
    final generated = (await firestoreService.watchDeliveries('c1').first).single;

    await firestoreService.markDelivery(DeliveryModel(
      customerId: 'c1',
      date: today,
      milkType: MilkType.cow,
      quantityLitres: generated.quantityLitres,
      rateApplied: generated.rateApplied,
      status: DeliveryStatus.delivered,
      deliveryBoyId: 'boy1',
    ));

    final createdSecondRun = await planningService.generateDeliveriesForDate(today);
    expect(createdSecondRun, 0);
    final after = (await firestoreService.watchDeliveries('c1').first).single;
    expect(after.status, DeliveryStatus.delivered); // not reverted to pending
  });

  test('generates one row per milk type for a "Both" customer', () async {
    await setup(
      c: customer('c1', milk: [MilkType.cow, MilkType.buffalo]),
      subs: [sub('c1', MilkType.cow), sub('c1', MilkType.buffalo, qty: 0.5)],
    );
    final created = await planningService.generateDeliveriesForDate(today);
    expect(created, 2);
  });
}
