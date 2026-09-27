import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_model.dart';

/// Represents a date-effective price record (Firestore collection: `priceList`).
/// Built in Phase 3 – Pricing Engine. See Requirements §4.5.
///
/// Records are append-only: a price change adds a new record and closes the
/// previous one by setting its [effectiveTo] to the day before the new one
/// starts. Dates are calendar dates (no time of day) and are stored as UTC
/// midnight so they read back identically in any timezone.
class PriceModel {
  final String id;
  final MilkType milkType;
  final double ratePerLitre;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo; // null = still current
  final String changedBy; // uid of the Admin who made the change
  final String changedByName;
  final DateTime? changedAt;

  PriceModel({
    required this.id,
    required this.milkType,
    required this.ratePerLitre,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    this.changedBy = '',
    this.changedByName = '',
    this.changedAt,
  })  : effectiveFrom = dateOnly(effectiveFrom),
        effectiveTo = effectiveTo == null ? null : dateOnly(effectiveTo);

  /// Strips the time of day.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Reads a stored UTC-midnight timestamp back as a calendar date.
  static DateTime dayFromTimestamp(Timestamp t) {
    final utc = t.toDate().toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Stores a calendar date as UTC midnight.
  static Timestamp dayToTimestamp(DateTime d) =>
      Timestamp.fromDate(DateTime.utc(d.year, d.month, d.day));

  /// Whether this record's rate applies on [date] (inclusive on both ends).
  bool coversDate(DateTime date) {
    final day = dateOnly(date);
    return !day.isBefore(effectiveFrom) &&
        (effectiveTo == null || !day.isAfter(effectiveTo!));
  }

  factory PriceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final from = data['effectiveFrom'] as Timestamp?;
    final to = data['effectiveTo'] as Timestamp?;
    return PriceModel(
      id: doc.id,
      milkType: MilkType.values.firstWhere(
        (t) => t.name == data['milkType'],
        orElse: () => MilkType.cow,
      ),
      ratePerLitre: (data['ratePerLitre'] as num?)?.toDouble() ?? 0,
      effectiveFrom: from == null ? DateTime.now() : dayFromTimestamp(from),
      effectiveTo: to == null ? null : dayFromTimestamp(to),
      changedBy: data['changedBy'] as String? ?? '',
      changedByName: data['changedByName'] as String? ?? '',
      changedAt: (data['changedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestore representation. `changedAt` is set by
  /// [PricingService.setNewRate] (server timestamp), not here.
  Map<String, dynamic> toMap() => {
        'milkType': milkType.name,
        'ratePerLitre': ratePerLitre,
        'effectiveFrom': dayToTimestamp(effectiveFrom),
        'effectiveTo': effectiveTo == null ? null : dayToTimestamp(effectiveTo!),
        'changedBy': changedBy,
        'changedByName': changedByName,
      };
}
