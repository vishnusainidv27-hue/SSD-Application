import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'bill_view_screen.dart';
import 'delivery_history_screen.dart';

/// Dashboard for a signed-in Customer (Requirements §5.2): today's/tomorrow's
/// scheduled delivery (computed from the subscription plus any Admin-set
/// exception — Phase 3), current outstanding amount (from the latest
/// Admin-generated bill, once one exists), and quick links to history/bill.
///
/// "Change quantity" / "Skip a day" aren't here yet — that's Phase 5's request
/// flow, once there's an approval queue for Admin to act on.
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({
    super.key,
    required this.customerId,
    required this.firestoreService,
    required this.onSignOut,
  });

  final String customerId;
  final FirestoreService firestoreService;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSD Farm'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {}, // streams keep this live; pull just settles it
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _UpcomingDeliveryCard(
              customerId: customerId,
              firestoreService: firestoreService,
            ),
            const SizedBox(height: 16),
            _OutstandingCard(
              customerId: customerId,
              firestoreService: firestoreService,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DeliveryHistoryScreen(
                          customerId: customerId,
                          firestoreService: firestoreService,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View bill'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BillViewScreen(
                          customerId: customerId,
                          firestoreService: firestoreService,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow milk' : 'Buffalo milk';
String _qtyLabel(double l) => l < 1 ? '${(l * 1000).round()} ml' : '$l L';

class _UpcomingDeliveryCard extends StatelessWidget {
  const _UpcomingDeliveryCard({
    required this.customerId,
    required this.firestoreService,
  });

  final String customerId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<SubscriptionModel>>(
          stream: firestoreService.watchSubscriptions(customerId),
          builder: (context, subSnap) {
            return StreamBuilder<List<DeliveryExceptionModel>>(
              stream: firestoreService.watchExceptions(customerId),
              builder: (context, excSnap) {
                if (subSnap.hasError || excSnap.hasError) {
                  return const Text('Could not load your delivery plan.');
                }
                if (!subSnap.hasData || !excSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final subs = subSnap.data!;
                final exceptions = excSnap.data!;
                if (subs.isEmpty) {
                  return const Text('No milk subscription set up yet. '
                      'Contact Admin to get started.');
                }
                final todayPlan = plannedDeliveriesForDate(
                    subscriptions: subs, exceptions: exceptions, date: today);
                final tomorrowPlan = plannedDeliveriesForDate(
                    subscriptions: subs,
                    exceptions: exceptions,
                    date: tomorrow);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    _planLine(theme, todayPlan),
                    const SizedBox(height: 12),
                    Text('Tomorrow', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    _planLine(theme, tomorrowPlan),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _planLine(ThemeData theme, List<PlannedDelivery> plan) {
    if (plan.isEmpty) {
      return const Text('Nothing scheduled.');
    }
    if (plan.every((p) => p.skipped)) {
      return Text('No delivery (skipped)', style: theme.textTheme.bodyMedium);
    }
    return Text(
      [
        for (final p in plan)
          if (!p.skipped) '${_milkLabel(p.milkType)}: ${_qtyLabel(p.quantityLitres)}',
      ].join(' · '),
      style: theme.textTheme.titleMedium,
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({
    required this.customerId,
    required this.firestoreService,
  });

  final String customerId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountFormat = NumberFormat('#,##0.00');
    final dateFormat = DateFormat('dd-MMM-yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<BillModel>>(
          stream: firestoreService.watchBills(customerId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Could not load your bill status.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bills = snapshot.data!;
            if (bills.isEmpty) {
              return const Text('No bills yet.');
            }
            final latest = bills.first; // watchBills sorts newest first
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outstanding', style: theme.textTheme.labelLarge),
                    Text('₹${amountFormat.format(latest.netPayable)}',
                        style: theme.textTheme.headlineSmall),
                  ],
                ),
                Text('as of ${dateFormat.format(latest.periodTo)}'),
              ],
            );
          },
        ),
      ),
    );
  }
}
