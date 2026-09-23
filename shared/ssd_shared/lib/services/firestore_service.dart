import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/customer_model.dart';
import '../models/delivery_exception_model.dart';
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

  /// Subscriptions for one customer (one doc per milk type).
  Future<List<SubscriptionModel>> getSubscriptions(String customerId) async {
    final snap = await _db
        .collection(_subscriptions)
        .where('customerId', isEqualTo: customerId)
        .get();
    return [for (final doc in snap.docs) SubscriptionModel.fromFirestore(doc)];
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

  /// Deterministic id (`<customerId>_<milkType>`) so re-saving a subscription
  /// overwrites rather than duplicates it.
  DocumentReference<Map<String, dynamic>> _subscriptionRef(
          String customerId, MilkType type) =>
      _db.collection(_subscriptions).doc('${customerId}_${type.name}');
}
