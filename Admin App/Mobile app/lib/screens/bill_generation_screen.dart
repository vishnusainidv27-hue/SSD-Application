import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Admin generates and views a customer's bill for a period, records
/// payments against it, and sees the day-wise breakup (Requirements §4.6).
class BillGenerationScreen extends StatefulWidget {
  const BillGenerationScreen({
    super.key,
    required this.customer,
    required this.authService,
    required this.firestoreService,
    required this.pricingService,
  });

  final CustomerModel customer;
  final AuthService authService;
  final FirestoreService firestoreService;
  final PricingService pricingService;

  @override
  State<BillGenerationScreen> createState() => _BillGenerationScreenState();
}

final DateFormat _monthFormat = DateFormat('MMMM yyyy');
final DateFormat _dayFormat = DateFormat('EEE dd-MMM');
final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
final NumberFormat _amountFormat = NumberFormat('#,##0.00');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';
String _modeLabel(PaymentMode m) => switch (m) {
      PaymentMode.cash => 'Cash',
      PaymentMode.upi => 'UPI',
      PaymentMode.bank => 'Bank transfer',
    };

class _BillGenerationScreenState extends State<BillGenerationScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 0);

  BillModel? _bill;
  List<DeliveryModel> _lineItems = const [];
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _bill = null;
    });
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final bill = await widget.pricingService.generateBill(
        customerId: widget.customer.id,
        periodFrom: _month,
        periodTo: _monthEnd,
      );
      final deliveries =
          await widget.firestoreService.watchDeliveries(widget.customer.id).first;
      if (!mounted) return;
      setState(() {
        _bill = bill;
        _lineItems = [
          for (final d in deliveries)
            if (d.status == DeliveryStatus.delivered &&
                !d.date.isBefore(_month) &&
                !d.date.isAfter(_monthEnd))
              d,
        ]..sort((a, b) => a.date.compareTo(b.date));
        _generating = false;
      });
    } on PricingException catch (e) {
      setState(() {
        _generating = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Could not generate the bill. Check your connection and '
            'try again.';
      });
    }
  }

  Future<void> _recordPayment() async {
    final bill = _bill;
    if (bill == null) return;
    final result = await showDialog<({double amount, PaymentMode mode})>(
      context: context,
      builder: (_) => _RecordPaymentDialog(maxAmount: bill.netPayable),
    );
    if (result == null) return;
    try {
      await widget.firestoreService.recordPayment(
        bill: bill,
        amount: result.amount,
        mode: result.mode,
        date: DateTime.now(),
        recordedBy: widget.authService.currentUserId ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payment recorded.')));
      await _generate(); // refresh totals
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record the payment.')));
    }
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
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = _bill;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} — bill'),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: _generating ? null : () => _shiftMonth(-1),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: _generating ? null : () => _shiftMonth(1),
          ),
        ],
      ),
      body: _generating && bill == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_monthFormat.format(_month),
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (bill != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _summaryRow('Total litres',
                              '${_lineItems.fold<double>(0, (s, d) => s + d.quantityLitres).toStringAsFixed(2)} L'),
                          _summaryRow('This month\'s amount',
                              '₹${_amountFormat.format(bill.totalAmount)}'),
                          const Divider(),
                          _summaryRow('Previous dues',
                              '₹${_amountFormat.format(bill.previousDue)}'),
                          _summaryRow('Paid so far',
                              '₹${_amountFormat.format(bill.amountPaid)}'),
                          _summaryRow('Net payable',
                              '₹${_amountFormat.format(bill.netPayable)}',
                              emphasize: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generating ? null : _generate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: bill.netPayable <= 0 || _generating
                              ? null
                              : _recordPayment,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Record payment'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Payment history', style: theme.textTheme.titleMedium),
                  StreamBuilder<List<PaymentModel>>(
                    stream: widget.firestoreService.watchPayments(widget.customer.id),
                    builder: (context, snapshot) {
                      final payments = snapshot.data ?? const <PaymentModel>[];
                      if (payments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No payments recorded yet.'),
                        );
                      }
                      return Column(
                        children: [
                          for (final p in payments)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.receipt_outlined),
                              title: Text('₹${_amountFormat.format(p.amount)} '
                                  '· ${_modeLabel(p.mode)}'),
                              subtitle: Text(_dateFormat.format(p.date)),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Day-wise breakup', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_lineItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No delivered days in this month yet.',
                          textAlign: TextAlign.center),
                    )
                  else
                    for (final d in _lineItems)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_dayFormat.format(d.date)),
                        subtitle: Text(
                            '${_milkLabel(d.milkType)} · ${d.quantityLitres} L '
                            '@ ₹${_amountFormat.format(d.rateApplied)}/L'),
                        trailing: Text('₹${_amountFormat.format(d.amount)}'),
                      ),
                ],
              ],
            ),
    );
  }
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({required this.maxAmount});

  final double maxAmount;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController =
      TextEditingController(text: widget.maxAmount.toStringAsFixed(2));
  PaymentMode _mode = PaymentMode.cash;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      amount: double.parse(_amountController.text.trim()),
      mode: _mode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final amount = double.tryParse(v?.trim() ?? '');
                if (amount == null || amount <= 0) return 'Enter an amount above 0';
                if (amount > widget.maxAmount + 0.01) {
                  return 'Cannot exceed the net payable '
                      '(₹${widget.maxAmount.toStringAsFixed(2)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentMode>(
              initialValue: _mode,
              decoration: const InputDecoration(
                labelText: 'Mode',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in PaymentMode.values)
                  DropdownMenuItem(value: m, child: Text(_modeLabel(m))),
              ],
              onChanged: (v) => setState(() => _mode = v ?? _mode),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
