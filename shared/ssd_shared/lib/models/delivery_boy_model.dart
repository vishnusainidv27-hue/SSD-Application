import 'package:cloud_firestore/cloud_firestore.dart';

/// A delivery boy, read from the `users` collection (doc id = their Auth
/// uid, same document `AuthService.createUserAccount` writes for role
/// `deliveryBoy`). There is no separate `deliveryBoys` collection yet — this
/// is just a typed view over the fields Phase 6 needs (name + active status,
/// for the "assign to customer" dropdown and the daily list).
class DeliveryBoyModel {
  final String id;
  final String name;
  final String mobile;
  final bool active;

  DeliveryBoyModel({
    required this.id,
    required this.name,
    required this.mobile,
    this.active = true,
  });

  factory DeliveryBoyModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DeliveryBoyModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      active: data['active'] as bool? ?? true,
    );
  }
}
