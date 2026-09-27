import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_shared/ssd_shared.dart';

void main() {
  late FirestoreService service;

  setUp(() {
    service = FirestoreService(firestore: FakeFirebaseFirestore());
  });

  test('notify writes an unread notification visible to that user', () async {
    await service.notify(
        targetUserRef: 'u1', type: 'billGenerated', message: 'Your bill is ready.');
    final mine = await service.watchNotifications('u1').first;
    expect(mine, hasLength(1));
    expect(mine.single.read, isFalse);
    expect(mine.single.message, 'Your bill is ready.');
  });

  test('watchNotifications only returns the target user\'s own notifications',
      () async {
    await service.notify(targetUserRef: 'u1', type: 't', message: 'for u1');
    await service.notify(targetUserRef: 'u2', type: 't', message: 'for u2');
    expect(await service.watchNotifications('u1').first, hasLength(1));
    expect(await service.watchNotifications('u2').first, hasLength(1));
  });

  test('notifyMany writes one notification per recipient', () async {
    await service.notifyMany(
        targetUserRefs: ['u1', 'u2', 'u3'], type: 'priceChanged', message: 'New rate.');
    expect(await service.watchNotifications('u1').first, hasLength(1));
    expect(await service.watchNotifications('u2').first, hasLength(1));
    expect(await service.watchNotifications('u3').first, hasLength(1));
  });

  test('markNotificationRead flips read to true', () async {
    await service.notify(targetUserRef: 'u1', type: 't', message: 'm');
    final n = (await service.watchNotifications('u1').first).single;
    await service.markNotificationRead(n.id);
    final updated = (await service.watchNotifications('u1').first).single;
    expect(updated.read, isTrue);
  });

  test('respondToRequest still writes a notification for the customer',
      () async {
    await service.submitRequest(DeliveryExceptionModel(
      customerId: 'c1',
      date: DateTime(2026, 9, 26),
      type: ExceptionType.skip,
      status: ExceptionStatus.pending,
    ));
    final request = (await service.watchPendingRequests().first).single;
    await service.respondToRequest(request: request, approve: true, adminUid: 'admin1');
    final notifications = await service.watchNotifications('c1').first;
    expect(notifications, hasLength(1));
    expect(notifications.single.type, 'requestApproved');
  });
}
