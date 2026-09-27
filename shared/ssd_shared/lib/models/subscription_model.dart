import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a milk subscription (Firestore collection: `subscriptions`).
/// Created at customer registration in Phase 2; frequency/date-effective
/// handling is extended in Phase 3.
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

  factory SubscriptionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SubscriptionModel(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      milkType: MilkType.values.firstWhere(
        (t) => t.name == data['milkType'],
        orElse: () => MilkType.cow,
      ),
      quantityLitres: (data['quantityLitres'] as num?)?.toDouble() ?? 0,
      frequency: data['frequency'] as String? ?? 'daily',
      startDate:
          (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'milkType': milkType.name,
        'quantityLitres': quantityLitres,
        'frequency': frequency,
        'startDate': Timestamp.fromDate(startDate),
        'active': active,
      };
}
