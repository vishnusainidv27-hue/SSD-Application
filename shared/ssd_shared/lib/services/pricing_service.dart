import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/price_model.dart';
import '../models/subscription_model.dart';

/// Thrown by [PricingService.setNewRate] when the request is invalid.
class PricingException implements Exception {
  PricingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Date-effective pricing & billing calculation logic.
/// Runs on-device inside the Admin app (no Cloud Functions – see Requirements §2.4).
/// Built in Phase 3 (price lookup) and Phase 7 (full bill generation).
///
/// TODO (Phase 7): generateBill(customerId, periodFrom, periodTo) -> BillModel
/// by summing each delivered day at the rate effective that day (use [rateFor]
/// against one fetched price list rather than querying per day).
class PricingService {
  PricingService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  static const String _priceList = 'priceList';
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

  /// Deterministic id so the same milk type + start date can never be
  /// duplicated.
  static String _idFor(MilkType type, DateTime from) =>
      '${type.name}_${from.year}'
      '${from.month.toString().padLeft(2, '0')}'
      '${from.day.toString().padLeft(2, '0')}';

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';
}
