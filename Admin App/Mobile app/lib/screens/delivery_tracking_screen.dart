import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Admin's day-wise, society-wise, delivery-boy-wise view of today's (or any
/// day's) deliveries, with a live totals dashboard (Requirements §4.4).
///
/// There is no server-side cron on the Spark plan (Requirements §2.4), so
/// nothing creates a day's `deliveries` rows automatically at midnight — this
/// screen generates them itself, once, the first time Admin opens it for a
/// given day (and lets Admin re-run it with Refresh). It's safe to re-run:
/// [DeliveryPlanningService] never overwrites a row that already exists.
class DeliveryTrackingScreen extends StatefulWidget {
  const DeliveryTrackingScreen({
    super.key,
    required this.firestoreService,
    required this.planningService,
  });

  final FirestoreService firestoreService;
  final DeliveryPlanningService planningService;

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

final DateFormat _dateFormat = DateFormat('EEE, dd-MMM-yyyy');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

String _statusLabel(DeliveryStatus s) => switch (s) {
      DeliveryStatus.delivered => 'Delivered',
      DeliveryStatus.notDelivered => 'Not delivered',
      DeliveryStatus.skipped => 'Skipped',
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

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _generating = false;
  String? _error;

  // Filters
  String? _society;
  String? _deliveryBoyId;
  MilkType? _milkType;
  DeliveryStatus? _status;

  Stream<List<DeliveryModel>> get _deliveries =>
      widget.firestoreService.watchAllDeliveriesForDate(_date);

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await widget.planningService.generateDeliveriesForDate(_date);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not generate today\'s list. Check your connection and '
            'tap Refresh.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked == null) return;
    setState(() => _date = DateUtils.dateOnly(picked));
    _generate();
  }

  Widget _totalsCard(List<DeliveryModel> deliveries) {
    final planned = deliveries.fold<double>(
        0,
        (sum, d) =>
            sum + (d.status == DeliveryStatus.skipped ? 0 : d.quantityLitres));
    final delivered = deliveries.fold<double>(
        0,
        (sum, d) =>
            sum + (d.status == DeliveryStatus.delivered ? d.quantityLitres : 0));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('Planned', '${planned.toStringAsFixed(1)} L'),
            _stat('Delivered', '${delivered.toStringAsFixed(1)} L'),
            _stat('Entries', '${deliveries.length}'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _filters(List<String> societies, List<DeliveryBoyModel> boys) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final s in DeliveryStatus.values) ...[
            FilterChip(
              label: Text(_statusLabel(s)),
              selected: _status == s,
              onSelected: (on) => setState(() => _status = on ? s : null),
            ),
            const SizedBox(width: 8),
          ],
          for (final t in MilkType.values) ...[
            FilterChip(
              label: Text(_milkLabel(t)),
              selected: _milkType == t,
              onSelected: (on) => setState(() => _milkType = on ? t : null),
            ),
            const SizedBox(width: 8),
          ],
          if (boys.isNotEmpty)
            PopupMenuButton<String?>(
              tooltip: 'Filter by delivery boy',
              onSelected: (v) => setState(() => _deliveryBoyId = v),
              itemBuilder: (_) => [
                const PopupMenuItem<String?>(
                    value: null, child: Text('All delivery boys')),
                for (final b in boys)
                  PopupMenuItem<String?>(value: b.id, child: Text(b.name)),
              ],
              child: Chip(
                avatar: const Icon(Icons.two_wheeler_outlined, size: 18),
                label: Text(
                    boys.where((b) => b.id == _deliveryBoyId).firstOrNull?.name ??
                        'Delivery boy'),
              ),
            ),
          if (societies.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              tooltip: 'Filter by society',
              onSelected: (v) => setState(() => _society = v),
              itemBuilder: (_) => [
                const PopupMenuItem<String?>(
                    value: null, child: Text('All societies')),
                for (final s in societies)
                  PopupMenuItem<String?>(value: s, child: Text(s)),
              ],
              child: Chip(
                avatar: const Icon(Icons.apartment_outlined, size: 18),
                label: Text(_society ?? 'Society'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery tracking'),
        actions: [
          IconButton(
            tooltip: 'Refresh (generate any missing entries)',
            icon: _generating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _generating ? null : _generate,
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
                child: Text('Could not load deliveries. Check your '
                    'connection and Firestore rules.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          return FutureBuilder<Map<String, CustomerModel>>(
            future: _customerLookup(all),
            builder: (context, custSnap) {
              final customers = custSnap.data ?? const {};
              final societies = {
                for (final c in customers.values)
                  if (c.societyName.trim().isNotEmpty) c.societyName.trim(),
              }.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              return StreamBuilder<List<DeliveryBoyModel>>(
                stream: widget.firestoreService.watchDeliveryBoys(),
                builder: (context, boySnap) {
                  final boys = boySnap.data ?? const <DeliveryBoyModel>[];
                  final shown = [
                    for (final d in all)
                      if ((_status == null || d.status == _status) &&
                          (_milkType == null || d.milkType == _milkType) &&
                          (_deliveryBoyId == null ||
                              d.deliveryBoyId == _deliveryBoyId) &&
                          (_society == null ||
                              customers[d.customerId]?.societyName.trim() ==
                                  _society))
                        d,
                  ];

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event),
                          label: Text(_dateFormat.format(_date)),
                        ),
                      ),
                      _totalsCard(all),
                      const SizedBox(height: 8),
                      _filters(societies, boys),
                      const SizedBox(height: 4),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(_error!,
                              style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      Expanded(
                        child: shown.isEmpty
                            ? Center(
                                child: Text(all.isEmpty
                                    ? 'No deliveries for this day yet. Make '
                                        'sure customers have an assigned '
                                        'delivery boy.'
                                    : 'No deliveries match these filters.'),
                              )
                            : ListView.separated(
                                itemCount: shown.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final d = shown[i];
                                  final customer = customers[d.customerId];
                                  final color = _statusColor(context, d.status);
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          color.withValues(alpha: 0.15),
                                      child: Icon(Icons.local_drink_outlined,
                                          color: color),
                                    ),
                                    title: Text(customer?.name ?? d.customerId),
                                    subtitle: Text(
                                      '${customer?.societyName ?? ''} · '
                                      '${_milkLabel(d.milkType)} · '
                                      '${d.quantityLitres} L'
                                      '${d.remark == null || d.remark!.isEmpty ? '' : '\n${d.remark}'}',
                                    ),
                                    isThreeLine:
                                        d.remark != null && d.remark!.isNotEmpty,
                                    trailing: Text(_statusLabel(d.status),
                                        style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w600)),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, CustomerModel>> _customerLookup(
      List<DeliveryModel> deliveries) async {
    final ids = {for (final d in deliveries) d.customerId};
    final entries = await Future.wait([
      for (final id in ids) widget.firestoreService.getCustomer(id),
    ]);
    return {
      for (final c in entries)
        if (c != null) c.id: c,
    };
  }
}
