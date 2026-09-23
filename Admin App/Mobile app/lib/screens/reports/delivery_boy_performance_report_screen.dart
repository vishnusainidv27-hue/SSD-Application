import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../../utils/csv_export.dart';

/// Per delivery boy, in a date range: assigned vs completed deliveries and
/// completion percentage (Requirements §4.8, §4.9).
class DeliveryBoyPerformanceReportScreen extends StatefulWidget {
  const DeliveryBoyPerformanceReportScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  State<DeliveryBoyPerformanceReportScreen> createState() =>
      _DeliveryBoyPerformanceReportScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

class _BoyStats {
  _BoyStats(this.boy);
  final DeliveryBoyModel boy;
  int assigned = 0; // pending + delivered + notDelivered (excludes skipped)
  int completed = 0; // delivered
  int missed = 0; // notDelivered

  double get completionPercent => assigned == 0 ? 0 : (completed / assigned) * 100;
}

class _DeliveryBoyPerformanceReportScreenState
    extends State<DeliveryBoyPerformanceReportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 6)),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  late Future<List<_BoyStats>> _stats = _load();

  Future<List<_BoyStats>> _load() async {
    final deliveries =
        await widget.firestoreService.getAllDeliveriesInRange(_range.start, _range.end);
    final boys = await widget.firestoreService.watchDeliveryBoys().first;
    final statsByBoy = {for (final b in boys) b.id: _BoyStats(b)};

    for (final d in deliveries) {
      if (d.status == DeliveryStatus.skipped) continue;
      final stats = statsByBoy[d.deliveryBoyId];
      if (stats == null) continue; // unassigned or deactivated boy
      stats.assigned++;
      if (d.status == DeliveryStatus.delivered) stats.completed++;
      if (d.status == DeliveryStatus.notDelivered) stats.missed++;
    }
    return statsByBoy.values.toList()
      ..sort((a, b) => a.boy.name.toLowerCase().compareTo(b.boy.name.toLowerCase()));
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
      _stats = _load();
    });
  }

  Future<void> _export(List<_BoyStats> stats) => exportCsv(
        context,
        filename: 'delivery_boy_performance.csv',
        headers: const ['Delivery boy', 'Assigned', 'Completed', 'Missed', 'Completion %'],
        rows: [
          for (final s in stats)
            [
              s.boy.name,
              '${s.assigned}',
              '${s.completed}',
              '${s.missed}',
              s.completionPercent.toStringAsFixed(1),
            ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery boy performance')),
      body: FutureBuilder<List<_BoyStats>>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this report.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
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
              Expanded(
                child: stats.isEmpty
                    ? const Center(child: Text('No delivery boys yet.'))
                    : ListView.separated(
                        itemCount: stats.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = stats[i];
                          return ListTile(
                            title: Text(s.boy.name),
                            subtitle: Text(
                                '${s.assigned} assigned · ${s.completed} completed · ${s.missed} missed'),
                            trailing: Text('${s.completionPercent.toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.titleMedium),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: stats.isEmpty ? null : () => _export(stats),
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
