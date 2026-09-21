import 'package:ssd_shared/ssd_shared.dart';

enum CustomerStatusFilter { all, active, inactive }

/// Applies the Customer List search box and filter chips (Requirements §4.3).
///
/// [query] is a case-insensitive substring match on name, mobile, society,
/// block or flat number. [society] is an exact (case-insensitive) match.
/// [milkType] keeps customers subscribed to that milk type.
List<CustomerModel> filterCustomers(
  List<CustomerModel> customers, {
  String query = '',
  String? society,
  MilkType? milkType,
  CustomerStatusFilter status = CustomerStatusFilter.all,
}) {
  final q = query.trim().toLowerCase();
  final soc = society?.trim().toLowerCase();
  return [
    for (final c in customers)
      if ((q.isEmpty ||
              [c.name, c.mobile, c.societyName, c.blockName, c.flatNumber]
                  .any((field) => field.toLowerCase().contains(q))) &&
          (soc == null || c.societyName.trim().toLowerCase() == soc) &&
          (milkType == null || c.milkTypes.contains(milkType)) &&
          (status == CustomerStatusFilter.all ||
              c.active == (status == CustomerStatusFilter.active)))
        c,
  ];
}
