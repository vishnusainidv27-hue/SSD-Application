import 'package:cloud_firestore/cloud_firestore.dart';

import 'price_model.dart';
import 'subscription_model.dart';

/// What an exception does to a day's delivery.
enum ExceptionType { skip, quantityChange }

/// Whether it covers just [DeliveryExceptionModel.date] or that date onward
/// (customer requests in Phase 5; Admin-created exceptions are `single`).
enum ExceptionScope { single, onward }

enum ExceptionStatus { pending, approved, rejected }

/// A date-specific change to a customer's normal delivery plan (Firestore
/// collection: `deliveryExceptions`). Admin-created exceptions (Phase 3) are
/// saved as `approved`; customer requests (Phase 5) start as `pending` and go
/// through the approval queue. Requirements §4.2.4, §4.7, §5.5.
///
/// A skip with a null [milkType] skips every milk type that day. If a day has
/// both a skip-all and a quantity change, the skip wins.
class DeliveryExceptionModel {
  final String id;
  final String customerId;
  final DateTime date;
  final ExceptionType type;
  final MilkType? milkType; // null = all milk types (skips only)
  final double? requestedQty; // litres, quantityChange only
  final ExceptionScope appliesFrom;
  final ExceptionStatus status;
  final String? approvedBy;
  final String? note;
  final DateTime? createdAt;

  DeliveryExceptionModel({
    required this.customerId,
    required DateTime date,
    required this.type,
    MilkType? milkType,
    this.requestedQty,
    this.appliesFrom = ExceptionScope.single,
    this.status = ExceptionStatus.approved,
    this.approvedBy,
    this.note,
    this.createdAt,
  })  : date = PriceModel.dateOnly(date),
        milkType = type == ExceptionType.skip ? null : milkType,
        id = idFor(customerId, date,
            type == ExceptionType.skip ? null : milkType, type);

  /// Deterministic id: one exception per customer + date + milk type + kind,
  /// so re-saving overwrites instead of duplicating.
  static String idFor(
      String customerId, DateTime date, MilkType? milkType, ExceptionType type) {
    final d = '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    final kind = type == ExceptionType.skip ? 'skip' : 'qty';
    return '${customerId}_${d}_${kind}_${milkType?.name ?? 'all'}';
  }

  factory DeliveryExceptionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final date = data['date'] as Timestamp?;
    final milk = data['milkType'] as String?;
    return DeliveryExceptionModel(
      customerId: data['customerId'] as String? ?? '',
      date: date == null ? DateTime.now() : PriceModel.dayFromTimestamp(date),
      type: ExceptionType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ExceptionType.skip,
      ),
      milkType: milk == null
          ? null
          : MilkType.values.firstWhere((t) => t.name == milk,
              orElse: () => MilkType.cow),
      requestedQty: (data['requestedQty'] as num?)?.toDouble(),
      appliesFrom: ExceptionScope.values.firstWhere(
        (s) => s.name == data['appliesFrom'],
        orElse: () => ExceptionScope.single,
      ),
      status: ExceptionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ExceptionStatus.pending,
      ),
      approvedBy: data['approvedBy'] as String?,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestore representation. `createdAt` is set by the service.
  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'date': PriceModel.dayToTimestamp(date),
        'type': type.name,
        'milkType': milkType?.name,
        'requestedQty': requestedQty,
        'appliesFrom': appliesFrom.name,
        'status': status.name,
        'approvedBy': approvedBy,
        'note': note,
      };
}
