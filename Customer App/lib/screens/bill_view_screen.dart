import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Month-wise bill: day-wise breakup of delivered milk with the rate applied
/// each day (reflecting Phase 3's date-effective pricing), a running total,
/// and — once Admin has generated a bill for the month (Phase 7) — previous
/// dues and payments too (Requirements §5.4).
///
/// Until Phase 6 writes real `deliveries`, this always shows "no deliveries
/// yet" for the current month; the layout and totals are correct and tested
/// so nothing else is needed once real data exists.
class BillViewScreen extends StatefulWidget {
  const BillViewScreen({
    super.key,
    required this.customerId,
    required this.firestoreService,
  });

  final String customerId;
  final FirestoreService firestoreService;

  @override
  State<BillViewScreen> createState() => _BillViewScreenState();
}

final NumberFormat _amountFormat = NumberFormat('#,##0.00');
final DateFormat _dayFormat = DateFormat('EEE dd');
final DateFormat _monthFormat = DateFormat('MMMM yyyy');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

class _BillViewScreenState extends State<BillViewScreen> {
  late final Stream<List<DeliveryModel>> _deliveries =
      widget.firestoreService.watchDeliveries(widget.customerId);
  late final Stream<List<BillModel>> _bills =
      widget.firestoreService.watchBills(widget.customerId);

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 0);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  /// The Admin-generated bill covering this month, if there is one — its
  /// period doesn't have to align exactly to the calendar month.
  BillModel? _billFor(List<BillModel> bills) {
    for (final b in bills) {
      if (!b.periodTo.isBefore(_month) && !b.periodFrom.isAfter(_monthEnd)) {
        return b;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill'),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(-1),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
      body: StreamBuilder<List<DeliveryModel>>(
        stream: _deliveries,
        builder: (context, deliverySnap) {
          return StreamBuilder<List<BillModel>>(
            stream: _bills,
            builder: (context, billSnap) {
              if (deliverySnap.hasError || billSnap.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Could not load your bill. Check your '
                        'connection and try again.'),
                  ),
                );
              }
              if (!deliverySnap.hasData || !billSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final delivered = [
                for (final d in deliverySnap.data!)
                  if (d.status == DeliveryStatus.delivered &&
                      !d.date.isBefore(_month) &&
                      !d.date.isAfter(_monthEnd))
                    d,
              ]..sort((a, b) => a.date.compareTo(b.date));
              final totalLitres = delivered.fold<double>(
                  0, (sum, d) => sum + d.quantityLitres);
              final totalAmount =
                  delivered.fold<double>(0, (sum, d) => sum + d.amount);
              final bill = _billFor(billSnap.data!);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_monthFormat.format(_month),
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _summaryRow(
                              'Total delivered', '${totalLitres.toStringAsFixed(2)} L'),
                          _summaryRow('This month\'s amount',
                              '₹${_amountFormat.format(totalAmount)}'),
                          if (bill != null) ...[
                            const Divider(),
                            _summaryRow('Previous dues',
                                '₹${_amountFormat.format(bill.previousDue)}'),
                            _summaryRow('Paid so far',
                                '₹${_amountFormat.format(bill.amountPaid)}'),
                            _summaryRow(
                              'Net payable',
                              '₹${_amountFormat.format(bill.netPayable)}',
                              emphasize: true,
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'Not billed by Admin yet — this is the running '
                              'total for the month so far.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Day-wise breakup', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (delivered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        deliverySnap.data!.isEmpty
                            ? 'No deliveries recorded yet.'
                            : 'No deliveries were recorded in this month.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (final d in delivered)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_dayFormat.format(d.date)),
                        subtitle: Text(
                            '${_milkLabel(d.milkType)} · ${d.quantityLitres} L '
                            '@ ₹${_amountFormat.format(d.rateApplied)}/L'),
                        trailing: Text('₹${_amountFormat.format(d.amount)}'),
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    final theme = Theme.of(context);
    final style = emphasize
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
