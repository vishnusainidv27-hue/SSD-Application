/// Represents a generated bill (Firestore collection: `bills`).
/// Built in Phase 7 – Billing Engine & Reports.
class BillModel {
  final String id;
  final String customerId;
  final DateTime periodFrom;
  final DateTime periodTo;
  final double totalAmount;
  final double previousDue;
  final double amountPaid;
  final double netPayable;

  BillModel({
    required this.id,
    required this.customerId,
    required this.periodFrom,
    required this.periodTo,
    required this.totalAmount,
    required this.previousDue,
    required this.amountPaid,
    required this.netPayable,
  });
}
