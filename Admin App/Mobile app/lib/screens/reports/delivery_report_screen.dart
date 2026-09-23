import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../../utils/csv_export.dart';

/// Every delivery in a date range, with society / delivery boy / customer /
/// milk-type / status filters and a global search box, plus CSV export
/// (Requirements §4.9).
class DeliveryReportScreen extends StatefulWidget {
  const DeliveryReportScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  State<DeliveryReportScreen> createState() => _DeliveryReportScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';
String _statusLabel(DeliveryStatus s) => switch (s) {
      DeliveryStatus.delivered => 'Delivered',
      DeliveryStatus.notDelivered => 'Not delivered',
      DeliveryStatus.skipped => 'Skipped',
      DeliveryStatus.pending => 'Pending',
    };

class _Row {
  _Row(this.delivery, this.customer);
  final DeliveryModel delivery;
  final CustomerModel? customer;
}

class _DeliveryReportScreenState extends State<DeliveryReportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 30)),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  late Future<List<_Row>> _rows = _load();

  String _query = '';
  String? _society;
  MilkType? _milkType;
  DeliveryStatus? _status;

  Future<List<_Row>> _load() async {
    final deliveries =
        await widget.firestoreService.getAllDeliveriesInRange(_range.start, _range.end);
    final customers = await widget.firestoreService.getAllCustomers();
    final customerById = {for (final c in customers) c.id: c};
    return [
      for (final d in deliveries..sort((a, b) => a.date.compareTo(b.date)))
        _Row(d, customerById[d.customerId]),
    ];
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_range.start.year - 2),
      lastDate: DateTime(_range.end.year + 1),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _rows = _load();
    });
  }

  Future<void> _export(List<_Row> rows) => exportCsv(
        context,
        filename: 'delivery_report.csv',
        headers: const ['Date', 'Customer', 'Society', 'Milk type', 'Quantity (L)', 'Status'],
        rows: [
          for (final r in rows)
            [
              _dateFormat.format(r.delivery.date),
              r.customer?.name ?? r.delivery.customerId,
              r.customer?.societyName ?? '',
              _milkLabel(r.delivery.milkType),
              '${r.delivery.quantityLitres}',
              _statusLabel(r.delivery.status),
            ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery report')),
      body: FutureBuilder<List<_Row>>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this report.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final societies = {for (final r in all) r.customer?.societyName ?? ''}
              .where((s) => s.isNotEmpty)
              .toList()
            ..sort();
          final q = _query.trim().toLowerCase();
          final shown = [
            for (final r in all)
              if ((_society == null || r.customer?.societyName == _society) &&
                  (_milkType == null || r.delivery.milkType == _milkType) &&
                  (_status == null || r.delivery.status == _status) &&
                  (q.isEmpty ||
                      (r.customer?.name.toLowerCase().contains(q) ?? false) ||
                      (r.customer?.societyName.toLowerCase().contains(q) ?? false)))
                r,
          ];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search customer or society',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                          '${_dateFormat.format(_range.start)} – ${_dateFormat.format(_range.end)}'),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
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
                    if (societies.isNotEmpty)
                      PopupMenuButton<String?>(
                        onSelected: (v) => setState(() => _society = v),
                        itemBuilder: (_) => [
                          const PopupMenuItem<String?>(value: null, child: Text('All societies')),
                          for (final s in societies)
                            PopupMenuItem<String?>(value: s, child: Text(s)),
                        ],
                        child: Chip(label: Text(_society ?? 'Society')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${shown.length} of ${all.length} deliveries'),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('No deliveries match.'))
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = shown[i];
                          return ListTile(
                            title: Text(r.customer?.name ?? r.delivery.customerId),
                            subtitle: Text('${_dateFormat.format(r.delivery.date)} · '
                                '${r.customer?.societyName ?? ''} · '
                                '${_milkLabel(r.delivery.milkType)} · '
                                '${r.delivery.quantityLitres} L'),
                            trailing: Text(_statusLabel(r.delivery.status)),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: shown.isEmpty ? null : () => _export(shown),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export CSV'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
