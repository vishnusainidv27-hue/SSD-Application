import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/delivery_model.dart';
import '../models/price_model.dart';
import '../utils/delivery_planner.dart';
import 'firestore_service.dart';
import 'pricing_service.dart';

/// Turns each active, delivery-boy-assigned customer's subscription (plus any
/// approved exception) into that day's `deliveries` rows, so the Delivery Boy
/// App has a worklist and Admin's tracking dashboard has something to query.
/// Runs client-side inside the Admin app (Requirements §2.4 — no Cloud
/// Functions), triggered by Admin opening the Delivery Tracking screen (or
/// tapping Refresh) rather than a midnight cron, since Spark has none.
///
/// Idempotent: a customer + date + milk type that already has a `deliveries`
/// doc (already generated today, or already marked by the delivery boy) is
/// left untouched — this never overwrites a real mark back to pending.
class DeliveryPlanningService {
  DeliveryPlanningService({
    required this.firestoreService,
    required this.pricingService,
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final FirestoreService firestoreService;
  final PricingService pricingService;
  final FirebaseFirestore? _firestoreOverride;

  static const String _deliveries = 'deliveries';
  static const int _batchSize = 400; // stay under Firestore's 500-op limit

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  /// Generates [date]'s `deliveries` rows for every active customer who has
  /// an assigned delivery boy. Returns how many new rows were created.
  Future<int> generateDeliveriesForDate(DateTime date) async {
    final day = PriceModel.dateOnly(date);
    final customers = await firestoreService.getAllCustomers();
    final priceCache = <String, List<PriceModel>>{};

    final toCreate = <DeliveryModel>[];
    for (final customer in customers) {
      if (!customer.active || customer.assignedDeliveryBoyId == null) continue;
      final subscriptions = await firestoreService.getSubscriptions(customer.id);
      if (subscriptions.isEmpty) continue;
      final exceptions = await firestoreService.watchExceptions(customer.id).first;
      final plan = plannedDeliveriesForDate(
        subscriptions: subscriptions,
        exceptions: exceptions,
        date: day,
      );
      for (final item in plan) {
        final id = DeliveryModel.idFor(customer.id, day, item.milkType);
        final exists = await _db.collection(_deliveries).doc(id).get();
        if (exists.exists) continue; // already generated or already marked

        final prices = priceCache[item.milkType.name] ??=
            await pricingService.pricesFor(item.milkType);
        final rate = PricingService.rateFor(prices, day)?.ratePerLitre ?? 0;

        toCreate.add(DeliveryModel(
          customerId: customer.id,
          date: day,
          milkType: item.milkType,
          quantityLitres: item.skipped ? 0 : item.quantityLitres,
          rateApplied: rate,
          status: item.skipped ? DeliveryStatus.skipped : DeliveryStatus.pending,
          deliveryBoyId: customer.assignedDeliveryBoyId,
        ));
      }
    }

    for (var i = 0; i < toCreate.length; i += _batchSize) {
      final batch = _db.batch();
      for (final d in toCreate.skip(i).take(_batchSize)) {
        batch.set(_db.collection(_deliveries).doc(d.id), d.toMap());
      }
      await batch.commit();
    }
    return toCreate.length;
  }
}
