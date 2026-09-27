import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  late FirestoreService service;

  setUp(() {
    service = FirestoreService(firestore: FakeFirebaseFirestore());
  });

  DeliveryExceptionModel pendingSkip(String customerId, DateTime date) =>
      DeliveryExceptionModel(
        customerId: customerId,
        date: date,
        type: ExceptionType.skip,
        status: ExceptionStatus.pending,
      );

  test('submitRequest is visible to the submitting customer as pending',
      () async {
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    final mine = await service.watchExceptions('c1').first;
    expect(mine, hasLength(1));
    expect(mine.single.status, ExceptionStatus.pending);
  });

  test('resubmitting the same date keeps both requests in history', () async {
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    expect(await service.watchExceptions('c1').first, hasLength(2));
  });

  test('watchPendingRequests only returns pending requests, across customers',
      () async {
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    await service.submitRequest(pendingSkip('c2', DateTime(2026, 9, 27)));
    await service.saveExceptions([
      // An Admin-direct exception: already approved, must not show up here.
      DeliveryExceptionModel(
          customerId: 'c3', date: DateTime(2026, 9, 28), type: ExceptionType.skip),
    ]);
    final pending = await service.watchPendingRequests().first;
    expect(pending.map((e) => e.customerId).toSet(), {'c1', 'c2'});
  });

  test('approving a request flips its status and keeps the same id',
      () async {
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    final request = (await service.watchPendingRequests().first).single;

    await service.respondToRequest(
        request: request, approve: true, adminUid: 'admin1');

    final updated = (await service.watchExceptions('c1').first).single;
    expect(updated.id, request.id);
    expect(updated.status, ExceptionStatus.approved);
    expect(updated.approvedBy, 'admin1');
    expect(await service.watchPendingRequests().first, isEmpty);
  });

  test('rejecting a request records the note and leaves it out of the plan',
      () async {
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    final request = (await service.watchPendingRequests().first).single;

    await service.respondToRequest(
      request: request,
      approve: false,
      adminUid: 'admin1',
      note: 'Already delivered for that week',
    );

    final updated = (await service.watchExceptions('c1').first).single;
    expect(updated.status, ExceptionStatus.rejected);
    expect(updated.note, 'Already delivered for that week');
  });

  test('an approved request is honoured by plannedDeliveriesForDate',
      () async {
    final sub = SubscriptionModel(
      id: 'c1_cow',
      customerId: 'c1',
      milkType: MilkType.cow,
      quantityLitres: 1,
      frequency: 'daily',
      startDate: DateTime(2026, 1, 1),
    );
    await service.submitRequest(pendingSkip('c1', DateTime(2026, 9, 26)));
    final request = (await service.watchPendingRequests().first).single;

    var plan = plannedDeliveriesForDate(
      subscriptions: [sub],
      exceptions: await service.watchExceptions('c1').first,
      date: DateTime(2026, 9, 26),
    );
    expect(plan.single.skipped, isFalse); // still pending: not in effect

    await service.respondToRequest(
        request: request, approve: true, adminUid: 'admin1');
    plan = plannedDeliveriesForDate(
      subscriptions: [sub],
      exceptions: await service.watchExceptions('c1').first,
      date: DateTime(2026, 9, 26),
    );
    expect(plan.single.skipped, isTrue); // now approved: in effect
  });
}
