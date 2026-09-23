import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../../utils/csv_export.dart';

/// Total litres delivered per day/society/milk type in a date range — used
/// to plan next-day procurement (Requirements §4.9).
class ConsumptionReportScreen extends StatefulWidget {
  const ConsumptionReportScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  State<ConsumptionReportScreen> createState() => _ConsumptionReportScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

class _DayTotal {
  _DayTotal(this.date);
  final DateTime date;
  final Map<MilkType, double> byType = {};

  double get total => byType.values.fold(0, (s, v) => s + v);
}

class _ConsumptionReportScreenState extends State<ConsumptionReportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 6)),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  late Future<List<_DayTotal>> _days = _load();
  String? _society;

  Future<List<_DayTotal>> _load() async {
    final deliveries =
        await widget.firestoreService.getAllDeliveriesInRange(_range.start, _range.end);
    final customers = await widget.firestoreService.getAllCustomers();
    final customerById = {for (final c in customers) c.id: c};

    final delivered = deliveries.where((d) => d.status == DeliveryStatus.delivered).where((d) {
      if (_society == null) return true;
      return customerById[d.customerId]?.societyName == _society;
    });

    final byDate = <DateTime, _DayTotal>{};
    for (final d in delivered) {
      final day = byDate.putIfAbsent(d.date, () => _DayTotal(d.date));
      day.byType[d.milkType] = (day.byType[d.milkType] ?? 0) + d.quantityLitres;
    }
    return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
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
      _days = _load();
    });
  }

  Future<List<String>> _societies() async {
    final customers = await widget.firestoreService.getAllCustomers();
    return {for (final c in customers) c.societyName}.where((s) => s.trim().isNotEmpty).toList()
      ..sort();
  }

  Future<void> _export(List<_DayTotal> days) => exportCsv(
        context,
        filename: 'consumption_report.csv',
        headers: const ['Date', 'Cow (L)', 'Buffalo (L)', 'Total (L)'],
        rows: [
          for (final d in days)
            [
              _dateFormat.format(d.date),
              (d.byType[MilkType.cow] ?? 0).toStringAsFixed(2),
              (d.byType[MilkType.buffalo] ?? 0).toStringAsFixed(2),
              d.total.toStringAsFixed(2),
            ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consumption / demand')),
      body: FutureBuilder<List<_DayTotal>>(
        future: _days,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this report.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = snapshot.data!;
          final grandTotal = days.fold<double>(0, (s, d) => s + d.total);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                            '${_dateFormat.format(_range.start)} – ${_dateFormat.format(_range.end)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FutureBuilder<List<String>>(
                      future: _societies(),
                      builder: (context, s) {
                        final societies = s.data ?? const <String>[];
                        if (societies.isEmpty) return const SizedBox.shrink();
                        return PopupMenuButton<String?>(
                          onSelected: (v) => setState(() {
                            _society = v;
                            _days = _load();
                          }),
                          itemBuilder: (_) => [
                            const PopupMenuItem<String?>(value: null, child: Text('All societies')),
                            for (final soc in societies)
                              PopupMenuItem<String?>(value: soc, child: Text(soc)),
                          ],
                          child: Chip(label: Text(_society ?? 'Society')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Total: ${grandTotal.toStringAsFixed(2)} L',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
              Expanded(
                child: days.isEmpty
                    ? const Center(child: Text('No delivered milk in this range.'))
                    : ListView.separated(
                        itemCount: days.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = days[i];
                          return ListTile(
                            title: Text(_dateFormat.format(d.date)),
                            subtitle: Text([
                              for (final t in MilkType.values)
                                if ((d.byType[t] ?? 0) > 0)
                                  '${_milkLabel(t)}: ${d.byType[t]!.toStringAsFixed(2)} L',
                            ].join(' · ')),
                            trailing: Text('${d.total.toStringAsFixed(2)} L'),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: days.isEmpty ? null : () => _export(days),
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
