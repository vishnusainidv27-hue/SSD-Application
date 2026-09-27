import 'package:cloud_firestore/cloud_firestore.dart';

import 'price_model.dart';
import 'subscription_model.dart';

/// Represents one day's delivery record (Firestore collection: `deliveries`).
/// One document per customer + date + milk type. `fromFirestore`/`toMap`
/// landed in Phase 4 so the Customer App's history/bill screens could already
/// read them; Phase 6 (Delivery Boy daily workflow) is what actually creates
/// and marks them — see `DeliveryPlanningService.generateDeliveriesForDate`
/// and `FirestoreService.markDelivery`.
enum DeliveryStatus { pending, delivered, notDelivered, skipped }

class DeliveryModel {
  final String id;
  final String customerId;
  final DateTime date;
  final MilkType milkType;
  final double quantityLitres;
  final double rateApplied;
  final DeliveryStatus status;
  final String? remark;
  final String? deliveryBoyId;

  /// When the delivery boy actually marked this entry (delivered/not
  /// delivered) — null while still `pending`/`skipped`.
  final DateTime? markedAt;

  DeliveryModel({
    required this.customerId,
    required DateTime date,
    required this.milkType,
    required this.quantityLitres,
    required this.rateApplied,
    required this.status,
    this.remark,
    this.deliveryBoyId,
    this.markedAt,
  })  : date = PriceModel.dateOnly(date),
        id = idFor(customerId, date, milkType);

  double get amount => quantityLitres * rateApplied;

  /// Deterministic id so a delivery boy re-marking the same customer + date +
  /// milk type overwrites rather than duplicates it.
  static String idFor(String customerId, DateTime date, MilkType milkType) {
    final day = PriceModel.dateOnly(date);
    final d = '${day.year}${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
    return '${customerId}_${d}_${milkType.name}';
  }

  factory DeliveryModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final date = data['date'] as Timestamp?;
    return DeliveryModel(
      customerId: data['customerId'] as String? ?? '',
      date: date == null ? DateTime.now() : PriceModel.dayFromTimestamp(date),
      milkType: MilkType.values.firstWhere(
        (t) => t.name == data['milkType'],
        orElse: () => MilkType.cow,
      ),
      quantityLitres: (data['quantityLitres'] as num?)?.toDouble() ?? 0,
      rateApplied: (data['rateApplied'] as num?)?.toDouble() ?? 0,
      status: DeliveryStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => DeliveryStatus.pending,
      ),
      remark: data['remark'] as String?,
      deliveryBoyId: data['deliveryBoyId'] as String?,
      markedAt: (data['markedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestore representation. Pass [markStatus] when actually marking a
  /// delivery so `markedAt` is set to the server time; omit it (as
  /// [DeliveryPlanningService] does when first generating the day's
  /// placeholder rows) to leave `markedAt` untouched.
  Map<String, dynamic> toMap({bool markStatus = false}) => {
        'customerId': customerId,
        'date': PriceModel.dayToTimestamp(date),
        'milkType': milkType.name,
        'quantityLitres': quantityLitres,
        'rateApplied': rateApplied,
        'status': status.name,
        'remark': remark,
        'deliveryBoyId': deliveryBoyId,
        if (markStatus) 'markedAt': FieldValue.serverTimestamp(),
      };
}
