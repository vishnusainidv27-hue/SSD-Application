import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../../utils/csv_export.dart';

/// Every customer whose latest bill still has money owed, with society,
/// amount-range and overdue-days filters and CSV export (Requirements §4.9).
class OutstandingDuesReportScreen extends StatefulWidget {
  const OutstandingDuesReportScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  State<OutstandingDuesReportScreen> createState() =>
      _OutstandingDuesReportScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
final NumberFormat _amountFormat = NumberFormat('#,##0.00');

class _Row {
  _Row(this.customer, this.bill);
  final CustomerModel customer;
  final BillModel bill;
  int get overdueDays => DateUtils.dateOnly(DateTime.now()).difference(bill.periodTo).inDays;
}

class _OutstandingDuesReportScreenState
    extends State<OutstandingDuesReportScreen> {
  late final Future<List<_Row>> _rows = _load();
  String? _society;
  double? _minAmount;
  int? _minOverdueDays;

  Future<List<_Row>> _load() async {
    final bills = await widget.firestoreService.getAllBills();
    final customers = await widget.firestoreService.getAllCustomers();
    final customerById = {for (final c in customers) c.id: c};

    // Latest bill per customer.
    final latestByCustomer = <String, BillModel>{};
    for (final b in bills) {
      final current = latestByCustomer[b.customerId];
      if (current == null || b.periodTo.isAfter(current.periodTo)) {
        latestByCustomer[b.customerId] = b;
      }
    }
    return [
      for (final entry in latestByCustomer.entries)
        if (entry.value.netPayable > 0 && customerById[entry.key] != null)
          _Row(customerById[entry.key]!, entry.value),
    ]..sort((a, b) => b.bill.netPayable.compareTo(a.bill.netPayable));
  }

  Future<void> _export(List<_Row> rows) => exportCsv(
        context,
        filename: 'outstanding_dues.csv',
        headers: const ['Customer', 'Society', 'Bill period', 'Net payable', 'Overdue days'],
        rows: [
          for (final r in rows)
            [
              r.customer.name,
              r.customer.societyName,
              '${_dateFormat.format(r.bill.periodFrom)} to ${_dateFormat.format(r.bill.periodTo)}',
              r.bill.netPayable.toStringAsFixed(2),
              '${r.overdueDays}',
            ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outstanding dues')),
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
          final societies = {for (final r in all) r.customer.societyName}
              .where((s) => s.trim().isNotEmpty)
              .toList()
            ..sort();
          final shown = [
            for (final r in all)
              if ((_society == null || r.customer.societyName == _society) &&
                  (_minAmount == null || r.bill.netPayable >= _minAmount!) &&
                  (_minOverdueDays == null || r.overdueDays >= _minOverdueDays!))
                r,
          ];
          final total = shown.fold<double>(0, (s, r) => s + r.bill.netPayable);

          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
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
                    const SizedBox(width: 8),
                    for (final threshold in [500, 1000, 2000]) ...[
                      FilterChip(
                        label: Text('₹$threshold+'),
                        selected: _minAmount == threshold.toDouble(),
                        onSelected: (on) =>
                            setState(() => _minAmount = on ? threshold.toDouble() : null),
                      ),
                      const SizedBox(width: 8),
                    ],
                    for (final days in [7, 30]) ...[
                      FilterChip(
                        label: Text('$days+ days overdue'),
                        selected: _minOverdueDays == days,
                        onSelected: (on) => setState(() => _minOverdueDays = on ? days : null),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${shown.length} customer${shown.length == 1 ? '' : 's'}'),
                    Text('Total: ₹${_amountFormat.format(total)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(child: Text('Nothing outstanding.'))
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = shown[i];
                          return ListTile(
                            title: Text(r.customer.name),
                            subtitle: Text('${r.customer.societyName} · '
                                '${_dateFormat.format(r.bill.periodTo)} · '
                                '${r.overdueDays} days overdue'),
                            trailing: Text('₹${_amountFormat.format(r.bill.netPayable)}'),
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
