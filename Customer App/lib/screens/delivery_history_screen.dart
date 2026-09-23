import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../utils/delivery_filter.dart';

/// Calendar/list view of every delivered date, with date range, milk type and
/// status filters (Requirements §5.3). Stays empty until Phase 6 (Delivery Boy
/// App) starts writing `deliveries` records — filters and layout are built and
/// tested now so there's nothing left to do once real data exists.
class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({
    super.key,
    required this.customerId,
    required this.firestoreService,
  });

  final String customerId;
  final FirestoreService firestoreService;

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

final DateFormat _dateFormat = DateFormat('EEE, dd-MMM-yyyy');
final NumberFormat _amountFormat = NumberFormat('#,##0.00');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

String _statusLabel(DeliveryStatus s) => switch (s) {
      DeliveryStatus.delivered => 'Delivered',
      DeliveryStatus.notDelivered => 'Not delivered',
      DeliveryStatus.skipped => 'Skipped by me',
      DeliveryStatus.pending => 'Upcoming',
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

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  late final Stream<List<DeliveryModel>> _deliveries =
      widget.firestoreService.watchDeliveries(widget.customerId);

  DateTimeRange? _range;
  MilkType? _milkType;
  DeliveryStatus? _status;

  Future<void> _pickRange() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          FilterChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_range == null
                ? 'Date range'
                : '${DateFormat('dd-MMM').format(_range!.start)} – '
                    '${DateFormat('dd-MMM').format(_range!.end)}'),
            selected: _range != null,
            onSelected: (_) => _pickRange(),
            onDeleted: _range == null ? null : () => setState(() => _range = null),
          ),
          const SizedBox(width: 8),
          for (final t in MilkType.values) ...[
            FilterChip(
              label: Text(_milkLabel(t)),
              selected: _milkType == t,
              onSelected: (on) => setState(() => _milkType = on ? t : null),
            ),
            const SizedBox(width: 8),
          ],
          for (final s in DeliveryStatus.values) ...[
            FilterChip(
              label: Text(_statusLabel(s)),
              selected: _status == s,
              onSelected: (on) => setState(() => _status = on ? s : null),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _tile(DeliveryModel d) {
    final color = _statusColor(context, d.status);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.local_drink_outlined, color: color),
      ),
      title: Text(_dateFormat.format(d.date)),
      subtitle: Text('${_milkLabel(d.milkType)} · ${d.quantityLitres} L · '
          '${_statusLabel(d.status)}'
          '${d.remark == null || d.remark!.isEmpty ? '' : '\n${d.remark}'}'),
      isThreeLine: d.remark != null && d.remark!.isNotEmpty,
      trailing: d.status == DeliveryStatus.delivered
          ? Text('₹${_amountFormat.format(d.amount)}')
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery history')),
      body: StreamBuilder<List<DeliveryModel>>(
        stream: _deliveries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load your deliveries. Check your '
                    'connection and try again.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final shown = filterDeliveries(
            all,
            from: _range?.start,
            to: _range?.end,
            milkType: _milkType,
            status: _status,
          );
          return Column(
            children: [
              const SizedBox(height: 8),
              _filters(),
              const SizedBox(height: 4),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            all.isEmpty
                                ? 'No deliveries recorded yet.'
                                : 'No deliveries match these filters.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _tile(shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
