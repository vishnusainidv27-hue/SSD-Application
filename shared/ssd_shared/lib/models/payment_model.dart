import 'package:cloud_firestore/cloud_firestore.dart';

import 'price_model.dart';

enum PaymentMode { cash, upi, bank }

/// A payment recorded against a bill (Firestore collection: `payments`).
/// Built in Phase 7 – Billing Engine. Requirements §4.6, §5.4.
class PaymentModel {
  final String id;
  final String customerId;
  final String billId;
  final double amount;
  final PaymentMode mode;
  final DateTime date;
  final String recordedBy;

  PaymentModel({
    required this.id,
    required this.customerId,
    required this.billId,
    required this.amount,
    required this.mode,
    required DateTime date,
    required this.recordedBy,
  }) : date = PriceModel.dateOnly(date);

  factory PaymentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final date = data['date'] as Timestamp?;
    return PaymentModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      billId: data['billId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      mode: PaymentMode.values.firstWhere(
        (m) => m.name == data['mode'],
        orElse: () => PaymentMode.cash,
      ),
      date: date == null ? DateTime.now() : PriceModel.dayFromTimestamp(date),
      recordedBy: data['recordedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'billId': billId,
        'amount': amount,
        'mode': mode.name,
        'date': PriceModel.dayToTimestamp(date),
        'recordedBy': recordedBy,
      };
}
