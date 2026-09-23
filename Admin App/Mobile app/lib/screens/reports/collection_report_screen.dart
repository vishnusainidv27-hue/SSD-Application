import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../../utils/csv_export.dart';

/// Every payment recorded in a date range, with society/mode/customer
/// filters and CSV export (Requirements §4.9).
class CollectionReportScreen extends StatefulWidget {
  const CollectionReportScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  State<CollectionReportScreen> createState() => _CollectionReportScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
final NumberFormat _amountFormat = NumberFormat('#,##0.00');
String _modeLabel(PaymentMode m) => switch (m) {
      PaymentMode.cash => 'Cash',
      PaymentMode.upi => 'UPI',
      PaymentMode.bank => 'Bank transfer',
    };

class _Row {
  _Row(this.payment, this.customer);
  final PaymentModel payment;
  final CustomerModel? customer;
}

class _CollectionReportScreenState extends State<CollectionReportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 30)),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  late Future<List<_Row>> _rows = _load();

  String? _society;
  PaymentMode? _mode;

  Future<List<_Row>> _load() async {
    final payments =
        await widget.firestoreService.getAllPaymentsInRange(_range.start, _range.end);
    final customers = await widget.firestoreService.getAllCustomers();
    final customerById = {for (final c in customers) c.id: c};
    return [
      for (final p in payments..sort((a, b) => b.date.compareTo(a.date)))
        _Row(p, customerById[p.customerId]),
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
        filename: 'collection_report.csv',
        headers: const ['Date', 'Customer', 'Society', 'Amount', 'Mode'],
        rows: [
          for (final r in rows)
            [
              _dateFormat.format(r.payment.date),
              r.customer?.name ?? r.payment.customerId,
              r.customer?.societyName ?? '',
              r.payment.amount.toStringAsFixed(2),
              _modeLabel(r.payment.mode),
            ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection / payments')),
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
          final shown = [
            for (final r in all)
              if ((_society == null || r.customer?.societyName == _society) &&
                  (_mode == null || r.payment.mode == _mode))
                r,
          ];
          final total = shown.fold<double>(0, (s, r) => s + r.payment.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                      '${_dateFormat.format(_range.start)} – ${_dateFormat.format(_range.end)}'),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final m in PaymentMode.values) ...[
                      FilterChip(
                        label: Text(_modeLabel(m)),
                        selected: _mode == m,
                        onSelected: (on) => setState(() => _mode = on ? m : null),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${shown.length} payment${shown.length == 1 ? '' : 's'}'),
                    Text('Total: ₹${_amountFormat.format(total)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('No payments in this range.'))
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = shown[i];
                          return ListTile(
                            title: Text(r.customer?.name ?? r.payment.customerId),
                            subtitle: Text('${_dateFormat.format(r.payment.date)} · '
                                '${r.customer?.societyName ?? ''} · '
                                '${_modeLabel(r.payment.mode)}'),
                            trailing: Text('₹${_amountFormat.format(r.payment.amount)}'),
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
