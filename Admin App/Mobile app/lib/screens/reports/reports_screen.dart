import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'collection_report_screen.dart';
import 'consumption_report_screen.dart';
import 'customer_activity_report_screen.dart';
import 'delivery_boy_performance_report_screen.dart';
import 'delivery_report_screen.dart';
import 'outstanding_dues_report_screen.dart';

/// Hub for every Admin report (Requirements §4.9).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.firestoreService});

  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, WidgetBuilder)>[
      (
        Icons.local_shipping_outlined,
        'Delivery report',
        (_) => DeliveryReportScreen(firestoreService: firestoreService),
      ),
      (
        Icons.payments_outlined,
        'Collection / payment report',
        (_) => CollectionReportScreen(firestoreService: firestoreService),
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Outstanding dues report',
        (_) => OutstandingDuesReportScreen(firestoreService: firestoreService),
      ),
      (
        Icons.local_drink_outlined,
        'Milk consumption / demand report',
        (_) => ConsumptionReportScreen(firestoreService: firestoreService),
      ),
      (
        Icons.people_outline,
        'Customer activity report',
        (_) => CustomerActivityReportScreen(firestoreService: firestoreService),
      ),
      (
        Icons.two_wheeler_outlined,
        'Delivery boy performance report',
        (_) => DeliveryBoyPerformanceReportScreen(firestoreService: firestoreService),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) {
          final (icon, title, builder) = entries[i];
          return Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: builder)),
            ),
          );
        },
      ),
    );
  }
}
