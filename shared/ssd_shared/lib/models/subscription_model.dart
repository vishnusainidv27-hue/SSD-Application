/// Represents a milk subscription (Firestore collection: `subscriptions`).
/// Built in Phase 3 – Pricing & Subscription setup.
enum MilkType { cow, buffalo }

class SubscriptionModel {
  final String id;
  final String customerId;
  final MilkType milkType;
  final double quantityLitres; // e.g. 0.5, 1.0, 1.5, 2.0
  final String frequency; // daily / alternate / custom
  final DateTime startDate;
  final bool active;

  SubscriptionModel({
    required this.id,
    required this.customerId,
    required this.milkType,
    required this.quantityLitres,
    required this.frequency,
    required this.startDate,
    this.active = true,
  });
}
