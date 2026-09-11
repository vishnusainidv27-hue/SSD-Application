/// Represents a date-effective price record (Firestore collection: `priceList`).
/// Built in Phase 3 – Pricing Engine. See Requirements §4.5.
class PriceModel {
  final String id;
  final String milkType;
  final double ratePerLitre;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo; // null = still current

  PriceModel({
    required this.id,
    required this.milkType,
    required this.ratePerLitre,
    required this.effectiveFrom,
    this.effectiveTo,
  });
}
