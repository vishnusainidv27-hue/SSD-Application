import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_model.dart';

/// Represents a customer document (Firestore collection: `customers`).
/// Built in Phase 2 – Admin Customer Onboarding.
///
/// The document id is the customer's Firebase Auth uid, so it maps 1:1 onto
/// the `users/{uid}` profile created by `AuthService.createUserAccount`.
class CustomerModel {
  final String id;
  final String name;
  final String mobile;
  final String alternateMobile;
  final String societyName;
  final String blockName;
  final String floor;
  final String flatNumber;
  final String landmark;
  final String finalAddress;
  final double? latitude;
  final double? longitude;
  final String? assignedDeliveryBoyId;

  /// Milk types this customer has a subscription for. Denormalised from the
  /// `subscriptions` collection so the customer list can filter by milk type
  /// without reading every subscription.
  final List<MilkType> milkTypes;
  final bool active;
  final DateTime? createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.mobile,
    this.alternateMobile = '',
    required this.societyName,
    required this.blockName,
    required this.floor,
    required this.flatNumber,
    required this.landmark,
    required this.finalAddress,
    this.latitude,
    this.longitude,
    this.assignedDeliveryBoyId,
    this.milkTypes = const [],
    this.active = true,
    this.createdAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  /// Builds the readable "Final Address" from the structured fields, e.g.
  /// "Flat 402, Floor 4, Block C, Green Valley Society, Near City Hospital".
  /// Blank fields are skipped.
  static String buildFinalAddress({
    required String societyName,
    required String blockName,
    required String floor,
    required String flatNumber,
    required String landmark,
  }) {
    String? part(String prefix, String value) {
      final v = value.trim();
      return v.isEmpty ? null : '$prefix$v';
    }

    return [
      part('Flat ', flatNumber),
      part('Floor ', floor),
      part('Block ', blockName),
      part('', societyName),
      part('', landmark),
    ].whereType<String>().join(', ');
  }

  factory CustomerModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CustomerModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      mobile: data['mobile'] as String? ?? '',
      alternateMobile: data['alternateMobile'] as String? ?? '',
      societyName: data['societyName'] as String? ?? '',
      blockName: data['blockName'] as String? ?? '',
      floor: data['floor'] as String? ?? '',
      flatNumber: data['flatNumber'] as String? ?? '',
      landmark: data['landmark'] as String? ?? '',
      finalAddress: data['finalAddress'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      assignedDeliveryBoyId: data['assignedDeliveryBoyId'] as String?,
      milkTypes: [
        for (final name in (data['milkTypes'] as List<dynamic>? ?? const []))
          for (final type in MilkType.values)
            if (type.name == name) type,
      ],
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Firestore representation. `createdAt` is deliberately omitted so updates
  /// never overwrite it; [FirestoreService.createCustomer] sets it on create.
  Map<String, dynamic> toMap() => {
        'name': name,
        'mobile': mobile,
        'alternateMobile': alternateMobile,
        'societyName': societyName,
        'blockName': blockName,
        'floor': floor,
        'flatNumber': flatNumber,
        'landmark': landmark,
        'finalAddress': finalAddress,
        'latitude': latitude,
        'longitude': longitude,
        'assignedDeliveryBoyId': assignedDeliveryBoyId,
        'milkTypes': [for (final t in milkTypes) t.name],
        'active': active,
      };
}
