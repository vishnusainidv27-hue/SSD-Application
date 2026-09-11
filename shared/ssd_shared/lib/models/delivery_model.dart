/// Represents one day's delivery record (Firestore collection: `deliveries`).
/// Built in Phase 6 – Delivery Boy daily workflow.
enum DeliveryStatus { pending, delivered, notDelivered, skipped }

class DeliveryModel {
  final String id;
  final String customerId;
  final DateTime date;
  final String milkType;
  final double quantityLitres;
  final double rateApplied;
  final DeliveryStatus status;
  final String? remark;
  final String? deliveryBoyId;

  DeliveryModel({
    required this.id,
    required this.customerId,
    required this.date,
    required this.milkType,
    required this.quantityLitres,
    required this.rateApplied,
    required this.status,
    this.remark,
    this.deliveryBoyId,
  });
}
