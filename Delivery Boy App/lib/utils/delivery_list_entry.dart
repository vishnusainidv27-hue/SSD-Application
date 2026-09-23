import 'package:ssd_shared/ssd_shared.dart';

/// One row of the daily delivery list: a `deliveries` record joined with the
/// customer it's for (name, address, map pin) — the delivery boy needs both
/// together, and there's no server-side join in Firestore.
class DeliveryListEntry {
  const DeliveryListEntry({required this.delivery, required this.customer});

  final DeliveryModel delivery;
  final CustomerModel customer;
}

/// Search by customer name or society (Requirements §6.2: "Search/filter the
/// day's list by society or customer name").
List<DeliveryListEntry> filterDeliveryEntries(
  List<DeliveryListEntry> entries, {
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries;
  return [
    for (final e in entries)
      if (e.customer.name.toLowerCase().contains(q) ||
          e.customer.societyName.toLowerCase().contains(q))
        e,
  ];
}

/// Groups entries by society, then by block within each society (Requirements
/// §6.2: "grouped by Society → Block, so the route is easy to follow
/// physically"), sorted alphabetically at both levels and by flat number
/// within a block.
Map<String, Map<String, List<DeliveryListEntry>>> groupBySocietyAndBlock(
  List<DeliveryListEntry> entries,
) {
  final result = <String, Map<String, List<DeliveryListEntry>>>{};
  for (final e in entries) {
    final society =
        e.customer.societyName.trim().isEmpty ? '(No society)' : e.customer.societyName.trim();
    final block = e.customer.blockName.trim().isEmpty ? '(No block)' : e.customer.blockName.trim();
    result.putIfAbsent(society, () => {}).putIfAbsent(block, () => []).add(e);
  }
  for (final blocks in result.values) {
    for (final list in blocks.values) {
      list.sort((a, b) => a.customer.flatNumber
          .toLowerCase()
          .compareTo(b.customer.flatNumber.toLowerCase()));
    }
  }
  return Map.fromEntries(
    result.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
  ).map((society, blocks) => MapEntry(
        society,
        Map.fromEntries(
          blocks.entries.toList()
            ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
        ),
      ));
}
