import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill_model.dart';
import '../models/delivery_model.dart';
import '../models/price_model.dart';
import '../models/subscription_model.dart';

/// Thrown by [PricingService.setNewRate] or [PricingService.generateBill]
/// when the request is invalid.
class PricingException implements Exception {
  PricingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Date-effective pricing & billing calculation logic.
/// Runs on-device inside the Admin app (no Cloud Functions – see Requirements §2.4).
/// Built in Phase 3 (price lookup) and Phase 7 (full bill generation).
class PricingService {
  PricingService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static const String _priceList = 'priceList';
  static const String _deliveries = 'deliveries';
  static const String _bills = 'bills';
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  /// Live list of every price record (all milk types), newest first.
  Stream<List<PriceModel>> watchPrices() {
    return _db.collection(_priceList).snapshots().map((snap) {
      final prices = [
        for (final doc in snap.docs) PriceModel.fromFirestore(doc),
      ];
      prices.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
      return prices;
    });
  }

  /// All price records for one milk type, oldest first. Filtered by milk type
  /// only and sorted here, so no composite Firestore index is needed.
  Future<List<PriceModel>> pricesFor(MilkType milkType) async {
    final snap = await _db
        .collection(_priceList)
        .where('milkType', isEqualTo: milkType.name)
        .get();
    final prices = [for (final doc in snap.docs) PriceModel.fromFirestore(doc)];
    prices.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    return prices;
  }

  /// The rate per litre that was in effect for [milkType] on [date], or null
  /// if no price had started by then.
  Future<double?> rateEffectiveOn(MilkType milkType, DateTime date) async {
    return rateFor(await pricesFor(milkType), date)?.ratePerLitre;
  }

  /// Pure lookup over an already-fetched price list: the record covering
  /// [date], or null. Use this when pricing many dates (e.g. a bill) so the
  /// list is fetched once.
  static PriceModel? rateFor(List<PriceModel> prices, DateTime date) {
    for (final price in prices) {
      if (price.coversDate(date)) return price;
    }
    return null;
  }

  /// Adds a new rate for [milkType] starting [effectiveFrom], and closes the
  /// milk type's currently open record with an `effectiveTo` of the day before
  /// (Requirements §4.5). Existing records are never otherwise edited.
  ///
  /// [effectiveFrom] must be later than the latest record's start (otherwise
  /// it would rewrite history). Throws [PricingException] if not, or if
  /// [ratePerLitre] isn't positive.
  Future<void> setNewRate({
    required MilkType milkType,
    required double ratePerLitre,
    required DateTime effectiveFrom,
    required String changedBy,
    String changedByName = '',
  }) async {
    if (!(ratePerLitre > 0)) {
      throw PricingException('Enter a rate above 0.');
    }
    final from = PriceModel.dateOnly(effectiveFrom);
    final existing = await pricesFor(milkType);
    final open = existing.where((p) => p.effectiveTo == null).toList();
    final latest = existing.isEmpty ? null : existing.last;
    if (latest != null && !from.isAfter(latest.effectiveFrom)) {
      throw PricingException(
          'The new rate must start after the current rate started on '
          '${_format(latest.effectiveFrom)}. Past price records are never '
          'edited.');
    }

    final batch = _db.batch();
    final dayBefore = DateTime(from.year, from.month, from.day - 1);
    for (final record in open) {
      batch.update(_db.collection(_priceList).doc(record.id), {
        'effectiveTo': PriceModel.dayToTimestamp(dayBefore),
      });
    }
    batch.set(_db.collection(_priceList).doc(_idFor(milkType, from)), {
      ...PriceModel(
        id: '',
        milkType: milkType,
        ratePerLitre: ratePerLitre,
        effectiveFrom: from,
        changedBy: changedBy,
        changedByName: changedByName,
      ).toMap(),
      'changedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Generates (or refreshes) [customerId]'s bill for [periodFrom]–[periodTo]
  /// (Requirements §4.6): sums every `delivered`-status delivery in that
  /// range at the rate already stored on it (Phase 6 stamps each delivery
  /// with the rate effective that day, per the worked example in
  /// Requirements §9), and carries forward the previous period's unpaid
  /// balance as `previousDue`.
  ///
  /// Uses a deterministic id per customer + period, so calling this again for
  /// the same period (e.g. after a late delivery mark) recomputes the totals
  /// in place rather than creating a duplicate bill — but preserves whatever
  /// has already been paid against it (`amountPaid`), so re-generating never
  /// erases a recorded payment.
  Future<BillModel> generateBill({
    required String customerId,
    required DateTime periodFrom,
    required DateTime periodTo,
  }) async {
    final from = PriceModel.dateOnly(periodFrom);
    final to = PriceModel.dateOnly(periodTo);
    if (to.isBefore(from)) {
      throw PricingException('The billing period\'s end date must be on or '
          'after its start date.');
    }

    final deliverySnap = await _db
        .collection(_deliveries)
        .where('customerId', isEqualTo: customerId)
        .get();
    final totalAmount = [
      for (final doc in deliverySnap.docs) DeliveryModel.fromFirestore(doc),
    ]
        .where((d) =>
            d.status == DeliveryStatus.delivered &&
            !d.date.isBefore(from) &&
            !d.date.isAfter(to))
        .fold<double>(0, (sum, d) => sum + d.amount);

    final billSnap = await _db
        .collection(_bills)
        .where('customerId', isEqualTo: customerId)
        .get();
    final bills = [for (final doc in billSnap.docs) BillModel.fromFirestore(doc)];
    final priorBills = bills.where((b) => b.periodTo.isBefore(from)).toList()
      ..sort((a, b) => b.periodTo.compareTo(a.periodTo));
    final previousDue = priorBills.isEmpty ? 0.0 : priorBills.first.netPayable;

    final id = _billIdFor(customerId, from, to);
    // Re-generating an existing bill must never erase a payment already
    // recorded against it.
    final existing = bills.where((b) => b.id == id).toList();
    final amountPaid = existing.isEmpty ? 0.0 : existing.single.amountPaid;

    final bill = BillModel(
      id: id,
      customerId: customerId,
      periodFrom: from,
      periodTo: to,
      totalAmount: totalAmount,
      previousDue: previousDue,
      amountPaid: amountPaid,
      netPayable: totalAmount + previousDue - amountPaid,
    );
    await _db.collection(_bills).doc(id).set({
      ...bill.toMap(),
      'generatedAt': FieldValue.serverTimestamp(),
    });
    return bill;
  }

  static String _billIdFor(String customerId, DateTime from, DateTime to) =>
      '${customerId}_${_ymd(from)}_${_ymd(to)}';

  static String _ymd(DateTime d) => '${d.year}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  /// Deterministic id so the same milk type + start date can never be
  /// duplicated.
  static String _idFor(MilkType type, DateTime from) =>
      '${type.name}_${from.year}'
      '${from.month.toString().padLeft(2, '0')}'
      '${from.day.toString().padLeft(2, '0')}';

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';
}
