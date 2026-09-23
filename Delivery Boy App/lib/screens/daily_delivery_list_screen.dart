import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/delivery_list_entry.dart';
import 'delivery_summary_screen.dart';
import 'not_delivered_dialog.dart';

/// Today's assigned deliveries, grouped by Society → Block (Requirements
/// §6.2). One tap marks an entry Delivered; Not Delivered requires a reason.
/// Marks sync to Admin's tracking dashboard immediately (both read the same
/// live `deliveries` collection) and, per Requirements §6.5, queue locally
/// and sync automatically if there's no signal (Firestore's built-in offline
/// persistence, enabled in main.dart).
class DailyDeliveryListScreen extends StatefulWidget {
  const DailyDeliveryListScreen({
    super.key,
    required this.deliveryBoyId,
    required this.firestoreService,
    required this.onSignOut,
  });

  final String deliveryBoyId;
  final FirestoreService firestoreService;
  final VoidCallback onSignOut;

  @override
  State<DailyDeliveryListScreen> createState() =>
      _DailyDeliveryListScreenState();
}

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

String _statusLabel(DeliveryStatus s) => switch (s) {
      DeliveryStatus.delivered => 'Delivered',
      DeliveryStatus.notDelivered => 'Not delivered',
      DeliveryStatus.skipped => 'Skipped by customer',
      DeliveryStatus.pending => 'Pending',
    };

Color _statusColor(BuildContext context, DeliveryStatus s) {
  final scheme = Theme.of(context).colorScheme;
  return switch (s) {
    DeliveryStatus.delivered => scheme.tertiary,
    DeliveryStatus.notDelivered => scheme.error,
    DeliveryStatus.skipped => scheme.outline,
    DeliveryStatus.pending => scheme.primary,
  };
}

class _DailyDeliveryListScreenState extends State<DailyDeliveryListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _busyId(String id) => _busy.contains(id);
  final Set<String> _busy = {};

  late final Stream<List<DeliveryModel>> _deliveries = widget.firestoreService
      .watchDeliveriesForDate(widget.deliveryBoyId, DateTime.now());

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<DeliveryListEntry>> _joinCustomers(
      List<DeliveryModel> deliveries) async {
    final customers = await Future.wait([
      for (final d in deliveries) widget.firestoreService.getCustomer(d.customerId),
    ]);
    return [
      for (var i = 0; i < deliveries.length; i++)
        if (customers[i] != null)
          DeliveryListEntry(delivery: deliveries[i], customer: customers[i]!),
    ];
  }

  Future<void> _navigate(CustomerModel customer) async {
    if (!customer.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No map location saved for this customer.')));
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query='
        '${customer.latitude},${customer.longitude}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open Maps.')));
    }
  }

  Future<void> _markDelivered(DeliveryListEntry e) async {
    setState(() => _busy.add(e.delivery.id));
    try {
      await widget.firestoreService.markDelivery(DeliveryModel(
        customerId: e.delivery.customerId,
        date: e.delivery.date,
        milkType: e.delivery.milkType,
        quantityLitres: e.delivery.quantityLitres,
        rateApplied: e.delivery.rateApplied,
        status: DeliveryStatus.delivered,
        deliveryBoyId: widget.deliveryBoyId,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(e.delivery.id));
    }
  }

  Future<void> _markNotDelivered(DeliveryListEntry e) async {
    final remark = await showDialog<String>(
      context: context,
      builder: (_) => const NotDeliveredDialog(),
    );
    if (remark == null) return; // cancelled
    setState(() => _busy.add(e.delivery.id));
    try {
      await widget.firestoreService.markDelivery(DeliveryModel(
        customerId: e.delivery.customerId,
        date: e.delivery.date,
        milkType: e.delivery.milkType,
        quantityLitres: e.delivery.quantityLitres,
        rateApplied: e.delivery.rateApplied,
        status: DeliveryStatus.notDelivered,
        remark: remark,
        deliveryBoyId: widget.deliveryBoyId,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(e.delivery.id));
    }
  }

  Widget _tile(DeliveryListEntry e) {
    final theme = Theme.of(context);
    final c = e.customer;
    final color = _statusColor(context, e.delivery.status);
    final actionable = e.delivery.status == DeliveryStatus.pending ||
        e.delivery.status == DeliveryStatus.delivered ||
        e.delivery.status == DeliveryStatus.notDelivered;
    final busy = _busyId(e.delivery.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: theme.textTheme.titleMedium),
                      Text(
                        'Flat ${c.flatNumber}, Floor ${c.floor}'
                        '${c.landmark.isEmpty ? '' : ' · ${c.landmark}'}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${_milkLabel(e.delivery.milkType)} · '
                        '${e.delivery.quantityLitres} L',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Navigate',
                  icon: const Icon(Icons.directions_outlined),
                  onPressed: () => _navigate(c),
                ),
              ],
            ),
            if (e.delivery.remark != null && e.delivery.remark!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(e.delivery.remark!, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            if (!actionable)
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(_statusLabel(e.delivery.status)),
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              )
            else if (e.delivery.status != DeliveryStatus.pending)
              Row(
                children: [
                  Chip(
                    label: Text(_statusLabel(e.delivery.status)),
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: busy ? null : () => _markDelivered(e),
                    child: const Text('Change to Delivered'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => _markNotDelivered(e),
                      child: const Text('Not delivered'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : () => _markDelivered(e),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Delivered'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s deliveries'),
        actions: [
          IconButton(
            tooltip: 'Summary',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => DeliverySummaryScreen(
                deliveryBoyId: widget.deliveryBoyId,
                firestoreService: widget.firestoreService,
              ),
            )),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: StreamBuilder<List<DeliveryModel>>(
        stream: _deliveries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load your list. Check your connection.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<List<DeliveryListEntry>>(
            future: _joinCustomers(snapshot.data!),
            builder: (context, joinSnap) {
              if (!joinSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = joinSnap.data!;
              final shown = filterDeliveryEntries(all, query: _query);
              final grouped = groupBySocietyAndBlock(shown);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search society or customer name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: all.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No deliveries assigned for today. Ask Admin '
                                'to check your assigned customers, or that '
                                "today's list has been generated.",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : shown.isEmpty
                            ? const Center(child: Text('No matches.'))
                            : ListView(
                                children: [
                                  for (final society in grouped.keys) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 4),
                                      child: Text(society,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                    ),
                                    for (final block
                                        in grouped[society]!.keys) ...[
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 4, 16, 0),
                                        child: Text('Block $block',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge),
                                      ),
                                      for (final e in grouped[society]![block]!)
                                        _tile(e),
                                    ],
                                  ],
                                  const SizedBox(height: 12),
                                ],
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
