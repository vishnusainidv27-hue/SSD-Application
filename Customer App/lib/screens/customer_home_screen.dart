import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'bill_view_screen.dart';
import 'delivery_history_screen.dart';
import 'requests_screen.dart';

/// Dashboard for a signed-in Customer (Requirements §5.2): a greeting header,
/// today's/tomorrow's scheduled delivery (computed from the subscription plus
/// any in-effect exception — Phase 3/5), current outstanding amount (from the
/// latest Admin-generated bill, once one exists), and quick links to
/// history/bill/requests. See `docs/DESIGN_SYSTEM.md` for the layout pattern.
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
          NotificationCentre(userId: customerId, firestoreService: firestoreService),
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
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _WelcomeHeader(customerId: customerId, firestoreService: firestoreService),
            const SectionHeader('Your delivery', icon: Icons.local_shipping_outlined),
            _UpcomingDeliveryCard(
              customerId: customerId,
              firestoreService: firestoreService,
            ),
            const SectionHeader('Billing', icon: Icons.account_balance_wallet_outlined),
            _OutstandingCard(
              customerId: customerId,
              firestoreService: firestoreService,
            ),
            const SectionHeader('Quick actions', icon: Icons.bolt_outlined),
            FilledButton.icon(
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Change quantity / skip a day'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RequestsScreen(
                    customerId: customerId,
                    firestoreService: firestoreService,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(width: AppSpacing.sm),
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

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.customerId, required this.firestoreService});

  final String customerId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<CustomerModel?>(
      future: firestoreService.getCustomer(customerId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name;
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          color: AppTheme.brandNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: Text(
                    (name == null || name.trim().isEmpty)
                        ? '🥛'
                        : name.trim()[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (name == null || name.trim().isEmpty)
                            ? 'Welcome back'
                            : 'Welcome back, ${name.trim().split(' ').first}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Here\'s what\'s happening with your milk.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        padding: const EdgeInsets.all(AppSpacing.md),
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
                    _dayRow(theme, 'Today', Icons.today_outlined, todayPlan),
                    const Divider(),
                    _dayRow(theme, 'Tomorrow', Icons.event_outlined, tomorrowPlan),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _dayRow(
      ThemeData theme, String label, IconData icon, List<PlannedDelivery> plan) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.brandNavy),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              _planLine(theme, plan),
            ],
          ),
        ),
      ],
    );
  }

  Widget _planLine(ThemeData theme, List<PlannedDelivery> plan) {
    if (plan.isEmpty) {
      return const Text('Nothing scheduled.');
    }
    if (plan.every((p) => p.skipped)) {
      return Text('No delivery (skipped)',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error));
    }
    return Text(
      [
        for (final p in plan)
          if (!p.skipped) '${_milkLabel(p.milkType)}: ${_qtyLabel(p.quantityLitres)}',
      ].join(' · '),
      style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.brandGreen),
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
        padding: const EdgeInsets.all(AppSpacing.md),
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
            final owesMoney = latest.netPayable > 0;
            return Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (owesMoney ? theme.colorScheme.error : AppTheme.brandGreen)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    owesMoney ? Icons.priority_high : Icons.check,
                    color: owesMoney ? theme.colorScheme.error : AppTheme.brandGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding', style: theme.textTheme.labelLarge),
                      Text('₹${amountFormat.format(latest.netPayable)}',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text('as of ${dateFormat.format(latest.periodTo)}',
                    style: theme.textTheme.bodySmall),
              ],
            );
          },
        ),
      ),
    );
  }
}
