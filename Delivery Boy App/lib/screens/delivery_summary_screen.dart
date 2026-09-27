import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// End-of-day summary (completed / missed / litres by milk type) plus a short
/// history of previous days (Requirements §6.4). Each day is fetched with its
/// own two-equality-filter query (deliveryBoyId + date) rather than one date
/// range query, so no composite Firestore index is needed.
class DeliverySummaryScreen extends StatefulWidget {
  const DeliverySummaryScreen({
    super.key,
    required this.deliveryBoyId,
    required this.firestoreService,
  });

  final String deliveryBoyId;
  final FirestoreService firestoreService;

  @override
  State<DeliverySummaryScreen> createState() => _DeliverySummaryScreenState();
}

final DateFormat _dateFormat = DateFormat('EEE, dd-MMM-yyyy');

class _DaySummary {
  _DaySummary(this.date, this.deliveries);
  final DateTime date;
  final List<DeliveryModel> deliveries;

  int get completed =>
      deliveries.where((d) => d.status == DeliveryStatus.delivered).length;
  int get missed =>
      deliveries.where((d) => d.status == DeliveryStatus.notDelivered).length;
  int get skipped =>
      deliveries.where((d) => d.status == DeliveryStatus.skipped).length;

  Map<MilkType, double> litresByType() {
    final map = <MilkType, double>{};
    for (final d in deliveries) {
      if (d.status != DeliveryStatus.delivered) continue;
      map[d.milkType] = (map[d.milkType] ?? 0) + d.quantityLitres;
    }
    return map;
  }
}

class _DeliverySummaryScreenState extends State<DeliverySummaryScreen> {
  static const int _historyDays = 7;

  late Future<List<_DaySummary>> _summaries = _load();

  Future<List<_DaySummary>> _load() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final results = <_DaySummary>[];
    for (var i = 0; i < _historyDays; i++) {
      final date = today.subtract(Duration(days: i));
      final deliveries =
          await widget.firestoreService.getDeliveriesForDate(widget.deliveryBoyId, date);
      results.add(_DaySummary(date, deliveries));
    }
    return results;
  }

  String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

  Widget _dayCard(_DaySummary s, {required bool isToday}) {
    final theme = Theme.of(context);
    final litres = s.litresByType();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isToday ? 'Today' : _dateFormat.format(s.date),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (s.deliveries.isEmpty)
              const Text('No deliveries that day.')
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('Completed', '${s.completed}'),
                  _stat('Missed', '${s.missed}'),
                  _stat('Skipped', '${s.skipped}'),
                ],
              ),
              if (litres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  litres.entries
                      .map((e) => '${_milkLabel(e.key)}: ${e.value.toStringAsFixed(1)} L')
                      .join(' · '),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery summary'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _summaries = _load()),
          ),
        ],
      ),
      body: FutureBuilder<List<_DaySummary>>(
        future: _summaries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load your summary. Check your '
                    'connection and try again.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final days = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (var i = 0; i < days.length; i++)
                _dayCard(days[i], isToday: i == 0),
            ],
          );
        },
      ),
    );
  }
}
