import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../../utils/csv_export.dart';

/// New joins, paused/deactivated customers, and pending change requests
/// (Requirements §4.9), each exportable to CSV.
class CustomerActivityReportScreen extends StatefulWidget {
  const CustomerActivityReportScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  State<CustomerActivityReportScreen> createState() =>
      _CustomerActivityReportScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

class _Data {
  _Data(this.newJoins, this.paused, this.pendingRequests, this.customerById);
  final List<CustomerModel> newJoins;
  final List<CustomerModel> paused;
  final List<DeliveryExceptionModel> pendingRequests;
  final Map<String, CustomerModel> customerById;
}

class _CustomerActivityReportScreenState
    extends State<CustomerActivityReportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 30)),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  late Future<_Data> _data = _load();

  Future<_Data> _load() async {
    final customers = await widget.firestoreService.getAllCustomers();
    final newJoins = [
      for (final c in customers)
        if (c.createdAt != null &&
            !DateUtils.dateOnly(c.createdAt!).isBefore(_range.start) &&
            !DateUtils.dateOnly(c.createdAt!).isAfter(_range.end))
          c,
    ]..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    final paused = customers.where((c) => !c.active).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final pending = await widget.firestoreService.watchPendingRequests().first;
    return _Data(newJoins, paused, pending, {for (final c in customers) c.id: c});
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
      _data = _load();
    });
  }

  Future<void> _export(_Data data) => exportCsv(
        context,
        filename: 'customer_activity.csv',
        headers: const ['Section', 'Customer', 'Society', 'Detail'],
        rows: [
          for (final c in data.newJoins)
            ['New join', c.name, c.societyName, _dateFormat.format(c.createdAt!)],
          for (final c in data.paused) ['Paused/deactivated', c.name, c.societyName, ''],
          for (final e in data.pendingRequests)
            [
              'Pending request',
              data.customerById[e.customerId]?.name ?? e.customerId,
              data.customerById[e.customerId]?.societyName ?? '',
              _dateFormat.format(e.date),
            ],
        ],
      );

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('None.'),
          )
        else
          ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer activity')),
      body: FutureBuilder<_Data>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this report.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                      'New joins: ${_dateFormat.format(_range.start)} – ${_dateFormat.format(_range.end)}'),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _section('New joins', [
                      for (final c in data.newJoins)
                        ListTile(
                          title: Text(c.name),
                          subtitle: Text(c.societyName),
                          trailing: Text(_dateFormat.format(c.createdAt!)),
                        ),
                    ]),
                    _section('Paused / deactivated', [
                      for (final c in data.paused)
                        ListTile(title: Text(c.name), subtitle: Text(c.societyName)),
                    ]),
                    _section('Pending change requests', [
                      for (final e in data.pendingRequests)
                        ListTile(
                          title: Text(data.customerById[e.customerId]?.name ?? e.customerId),
                          subtitle: Text(e.type == ExceptionType.skip
                              ? 'Skip · ${_dateFormat.format(e.date)}'
                              : 'Quantity change · ${_dateFormat.format(e.date)}'),
                        ),
                    ]),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _export(data),
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
