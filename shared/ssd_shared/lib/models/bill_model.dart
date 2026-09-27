import 'package:cloud_firestore/cloud_firestore.dart';

import 'price_model.dart';

/// Represents a generated bill (Firestore collection: `bills`).
/// `fromFirestore`/`toMap` land in Phase 4 so the Customer App's bill view can
/// already read a generated bill's payment status; full generation
/// (`PricingService.generateBill`) is built in Phase 7 – Billing Engine.
class BillModel {
  final String id;
  final String customerId;
  final DateTime periodFrom;
  final DateTime periodTo;
  final double totalAmount;
  final double previousDue;
  final double amountPaid;
  final double netPayable;
  final DateTime? generatedAt;

  BillModel({
    required this.id,
    required this.customerId,
    required DateTime periodFrom,
    required DateTime periodTo,
    required this.totalAmount,
    required this.previousDue,
    required this.amountPaid,
    required this.netPayable,
    this.generatedAt,
  })  : periodFrom = PriceModel.dateOnly(periodFrom),
        periodTo = PriceModel.dateOnly(periodTo);

  factory BillModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final from = data['periodFrom'] as Timestamp?;
    final to = data['periodTo'] as Timestamp?;
    return BillModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      periodFrom: from == null ? DateTime.now() : PriceModel.dayFromTimestamp(from),
      periodTo: to == null ? DateTime.now() : PriceModel.dayFromTimestamp(to),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      previousDue: (data['previousDue'] as num?)?.toDouble() ?? 0,
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0,
      netPayable: (data['netPayable'] as num?)?.toDouble() ?? 0,
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'periodFrom': PriceModel.dayToTimestamp(periodFrom),
        'periodTo': PriceModel.dayToTimestamp(periodTo),
        'totalAmount': totalAmount,
        'previousDue': previousDue,
        'amountPaid': amountPaid,
        'netPayable': netPayable,
      };
}
