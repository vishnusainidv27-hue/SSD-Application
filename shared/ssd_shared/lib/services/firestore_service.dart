import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../models/delivery_boy_model.dart';
import '../models/delivery_exception_model.dart';
import '../models/delivery_model.dart';
import '../models/price_model.dart';
import '../models/subscription_model.dart';

/// Generic Firestore read/write helpers shared by all apps.
/// Extended in every phase as new collections are introduced.
///
/// Phase 2 adds customer + subscription CRUD (Admin only — enforced by the
/// Firestore rules).
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static const String _customers = 'customers';
  static const String _subscriptions = 'subscriptions';
  static const String _users = 'users';
  static const String _exceptions = 'deliveryExceptions';
  static const String _deliveries = 'deliveries';
  static const String _bills = 'bills';
  static const String _notifications = 'notifications';
  static const String _deliveryBoyRole = 'deliveryBoy';

  final FirebaseFirestore? _firestoreOverride;

  // Resolved lazily so constructing the service never requires Firebase to be
  // initialised yet.
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------- customers

  /// Live list of all customers, ordered by name. Search/filters are applied
  /// client-side (the customer base is hundreds, not millions, and Firestore
  /// has no substring search).
  Stream<List<CustomerModel>> watchCustomers() {
    return _db.collection(_customers).orderBy('name').snapshots().map(
          (snap) => [for (final doc in snap.docs) CustomerModel.fromFirestore(doc)],
        );
  }

  Future<CustomerModel?> getCustomer(String id) async {
    final doc = await _db.collection(_customers).doc(id).get();
    return doc.exists ? CustomerModel.fromFirestore(doc) : null;
  }

  /// One-shot read of every customer — used by [DeliveryPlanningService],
  /// which needs the whole list rather than a live view.
  Future<List<CustomerModel>> getAllCustomers() async {
    final snap = await _db.collection(_customers).get();
    return [for (final doc in snap.docs) CustomerModel.fromFirestore(doc)];
  }

  /// Subscriptions for one customer (one doc per milk type).
  Future<List<SubscriptionModel>> getSubscriptions(String customerId) async {
    final snap = await _db
        .collection(_subscriptions)
        .where('customerId', isEqualTo: customerId)
        .get();
    return [for (final doc in snap.docs) SubscriptionModel.fromFirestore(doc)];
  }

  /// Live version of [getSubscriptions], for the Customer App's own dashboard
  /// (so a plan change Admin makes shows up without a manual refresh).
  Stream<List<SubscriptionModel>> watchSubscriptions(String customerId) {
    return _db
        .collection(_subscriptions)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) =>
            [for (final doc in snap.docs) SubscriptionModel.fromFirestore(doc)]);
  }

  /// Writes the customer profile (id = the customer's Auth uid, from
  /// `AuthService.createUserAccount`) and its subscriptions in one batch.
  Future<void> createCustomer(
    CustomerModel customer,
    List<SubscriptionModel> subscriptions,
  ) {
    final batch = _db.batch();
    batch.set(_db.collection(_customers).doc(customer.id), {
      ...customer.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final sub in subscriptions) {
      batch.set(_subscriptionRef(customer.id, sub.milkType), sub.toMap());
    }
    return batch.commit();
  }

  /// Updates the customer profile and syncs subscriptions: types in
  /// [subscriptions] are written, previously-saved types not in it are removed.
  /// The name is also mirrored to `users/{id}` so both docs stay consistent.
  Future<void> updateCustomer(
    CustomerModel customer,
    List<SubscriptionModel> subscriptions,
  ) async {
    final keep = {for (final s in subscriptions) s.milkType};
    final batch = _db.batch();
    batch.update(_db.collection(_customers).doc(customer.id), customer.toMap());
    batch.update(
        _db.collection(_users).doc(customer.id), {'name': customer.name});
    for (final sub in subscriptions) {
      batch.set(_subscriptionRef(customer.id, sub.milkType), sub.toMap());
    }
    for (final type in MilkType.values.where((t) => !keep.contains(t))) {
      batch.delete(_subscriptionRef(customer.id, type));
    }
    await batch.commit();
  }

  /// Deactivates / reactivates a customer. Writes both `customers/{id}` and
  /// `users/{id}` — the latter is what actually blocks login (client-side in
  /// AuthService and server-side in the Firestore rules' isActiveUser()).
  Future<void> setCustomerActive(String id, bool active) {
    final batch = _db.batch();
    batch.update(_db.collection(_customers).doc(id), {'active': active});
    batch.update(_db.collection(_users).doc(id), {'active': active});
    return batch.commit();
  }

  // ------------------------------------------------------ delivery exceptions

  /// Live list of one customer's delivery exceptions, soonest first. Filtered
  /// by customer only and sorted here, so no composite index is needed.
  Stream<List<DeliveryExceptionModel>> watchExceptions(String customerId) {
    return _db
        .collection(_exceptions)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
      final list = [
        for (final doc in snap.docs) DeliveryExceptionModel.fromFirestore(doc),
      ];
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  /// Saves exceptions in one batch. Ids are deterministic, so saving the same
  /// customer + date + milk type + kind again overwrites the earlier one.
  Future<void> saveExceptions(List<DeliveryExceptionModel> exceptions) {
    final batch = _db.batch();
    for (final e in exceptions) {
      batch.set(_db.collection(_exceptions).doc(e.id), {
        ...e.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  Future<void> deleteException(String id) =>
      _db.collection(_exceptions).doc(id).delete();

  /// Customer-submitted change/skip request (Requirements §5.5): always
  /// starts `pending`, under an auto-generated id so a resubmission (e.g.
  /// after a rejection) keeps its own row in the customer's history instead
  /// of overwriting the earlier one. Only Admin can move it to
  /// approved/rejected — see [respondToRequest].
  Future<void> submitRequest(DeliveryExceptionModel request) {
    assert(request.status == ExceptionStatus.pending);
    return _db.collection(_exceptions).add({
      ...request.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live queue of every customer's pending requests, oldest first — Admin's
  /// Approval Queue (Requirements §4.7).
  Stream<List<DeliveryExceptionModel>> watchPendingRequests() {
    return _db
        .collection(_exceptions)
        .where('status', isEqualTo: ExceptionStatus.pending.name)
        .snapshots()
        .map((snap) {
      final list = [
        for (final doc in snap.docs) DeliveryExceptionModel.fromFirestore(doc),
      ];
      list.sort((a, b) {
        final aCreated = a.createdAt;
        final bCreated = b.createdAt;
        if (aCreated == null || bCreated == null) return 0;
        return aCreated.compareTo(bCreated);
      });
      return list;
    });
  }

  /// Admin approves or rejects a pending request, and drops a notification
  /// for the customer either way (Requirements §4.7: "notify the customer").
  /// Once approved, [plannedDeliveriesForDate] picks it up automatically —
  /// nothing else needs to change, since exceptions are already the
  /// date-effective source of truth the dashboard/history read live.
  ///
  /// The notification is written now so Phase 8's notification centre has
  /// data to show as soon as it's built; there is no in-app place to read it
  /// yet.
  Future<void> respondToRequest({
    required DeliveryExceptionModel request,
    required bool approve,
    required String adminUid,
    String? note,
  }) {
    assert(request.status == ExceptionStatus.pending);
    final batch = _db.batch();
    batch.update(_db.collection(_exceptions).doc(request.id), {
      'status':
          (approve ? ExceptionStatus.approved : ExceptionStatus.rejected).name,
      'approvedBy': adminUid,
      'note': note,
    });
    final what = request.type == ExceptionType.skip
        ? 'your request to skip delivery on ${_ymd(request.date)}'
        : 'your quantity-change request for ${_ymd(request.date)}';
    batch.set(_db.collection(_notifications).doc(), {
      'targetUserRef': request.customerId,
      'type': approve ? 'requestApproved' : 'requestRejected',
      'message': approve
          ? 'Admin approved $what.'
          : 'Admin rejected $what.${note == null || note.isEmpty ? '' : ' Note: $note'}',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  static String _ymd(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------- deliveries

  /// Live list of one customer's delivery records, soonest first. Filtered by
  /// customer only (matches the Firestore rule) and sorted here; date-range,
  /// milk-type and status filters are applied client-side by the caller (see
  /// `filterDeliveries` in the Customer App), same pattern as the customer
  /// list's search/filters.
  Stream<List<DeliveryModel>> watchDeliveries(String customerId) {
    return _db
        .collection(_deliveries)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
      final list = [
        for (final doc in snap.docs) DeliveryModel.fromFirestore(doc),
      ];
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    });
  }

  // ------------------------------------------------------------------ bills

  /// Live list of one customer's generated bills, newest first.
  Stream<List<BillModel>> watchBills(String customerId) {
    return _db
        .collection(_bills)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) {
      final list = [for (final doc in snap.docs) BillModel.fromFirestore(doc)];
      list.sort((a, b) => b.periodTo.compareTo(a.periodTo));
      return list;
    });
  }

  // ----------------------------------------------------------- delivery boys

  /// Live list of delivery boy accounts (`users` where `role == 'deliveryBoy'`),
  /// ordered by name. There's no separate `deliveryBoys` collection yet —
  /// see [DeliveryBoyModel].
  Stream<List<DeliveryBoyModel>> watchDeliveryBoys() {
    return _db
        .collection(_users)
        .where('role', isEqualTo: _deliveryBoyRole)
        .snapshots()
        .map((snap) {
      final list = [
        for (final doc in snap.docs) DeliveryBoyModel.fromFirestore(doc),
      ];
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  // ------------------------------------------------ delivery boy daily list

  /// Live list of [deliveryBoyId]'s `deliveries` rows for one [date] — the
  /// Delivery Boy App's daily worklist. Both fields are exact matches, so
  /// this needs no composite index.
  Stream<List<DeliveryModel>> watchDeliveriesForDate(
      String deliveryBoyId, DateTime date) {
    return _deliveriesForDateQuery(deliveryBoyId, date)
        .snapshots()
        .map((snap) =>
            [for (final doc in snap.docs) DeliveryModel.fromFirestore(doc)]);
  }

  /// One-shot version of [watchDeliveriesForDate], for the delivery boy's
  /// end-of-day summary and short history — those look at several past days
  /// at once, where a live listener per day isn't worth keeping open.
  Future<List<DeliveryModel>> getDeliveriesForDate(
      String deliveryBoyId, DateTime date) async {
    final snap = await _deliveriesForDateQuery(deliveryBoyId, date).get();
    return [for (final doc in snap.docs) DeliveryModel.fromFirestore(doc)];
  }

  Query<Map<String, dynamic>> _deliveriesForDateQuery(
          String deliveryBoyId, DateTime date) =>
      _db
          .collection(_deliveries)
          .where('deliveryBoyId', isEqualTo: deliveryBoyId)
          .where('date',
              isEqualTo: PriceModel.dayToTimestamp(PriceModel.dateOnly(date)));

  /// Live list of every customer's `deliveries` rows for one [date] — Admin's
  /// tracking dashboard (Requirements §4.4); society/boy/milk-type/status
  /// filters are applied client-side, same pattern as the customer list.
  Stream<List<DeliveryModel>> watchAllDeliveriesForDate(DateTime date) {
    return _db
        .collection(_deliveries)
        .where('date', isEqualTo: PriceModel.dayToTimestamp(PriceModel.dateOnly(date)))
        .snapshots()
        .map((snap) =>
            [for (final doc in snap.docs) DeliveryModel.fromFirestore(doc)]);
  }

  /// Delivery boy marks one entry delivered/not-delivered (with an optional
  /// remark — the mandatory "not delivered" reason is folded into it by the
  /// caller). Sets `markedAt` to the server time.
  Future<void> markDelivery(DeliveryModel delivery) {
    assert(delivery.status == DeliveryStatus.delivered ||
        delivery.status == DeliveryStatus.notDelivered);
    return _db
        .collection(_deliveries)
        .doc(delivery.id)
        .set(delivery.toMap(markStatus: true));
  }

  /// Deterministic id (`<customerId>_<milkType>`) so re-saving a subscription
  /// overwrites rather than duplicates it.
  DocumentReference<Map<String, dynamic>> _subscriptionRef(
          String customerId, MilkType type) =>
      _db.collection(_subscriptions).doc('${customerId}_${type.name}');
}
