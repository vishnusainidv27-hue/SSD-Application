/// Represents a customer document (Firestore collection: `customers`).
/// Built in Phase 2 – Admin Customer Onboarding.
class CustomerModel {
  final String id;
  final String name;
  final String mobile;
  final String societyName;
  final String blockName;
  final String floor;
  final String flatNumber;
  final String landmark;
  final String finalAddress;
  final double? latitude;
  final double? longitude;
  final String? assignedDeliveryBoyId;
  final bool active;

  CustomerModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.societyName,
    required this.blockName,
    required this.floor,
    required this.flatNumber,
    required this.landmark,
    required this.finalAddress,
    this.latitude,
    this.longitude,
    this.assignedDeliveryBoyId,
    this.active = true,
  });

  // TODO (Phase 2): fromFirestore / toMap conversion methods.
}
