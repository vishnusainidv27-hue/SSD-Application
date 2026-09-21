import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Admin's price list (Requirements §4.5): the current rate per milk type, a
/// way to set a new rate from a given date (the previous rate is closed the
/// day before, never overwritten), and the full price history for audit.
class PriceListScreen extends StatefulWidget {
  const PriceListScreen({
    super.key,
    required this.authService,
    required this.pricingService,
  });

  final AuthService authService;
  final PricingService pricingService;

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
final NumberFormat _rateFormat = NumberFormat('#,##0.00');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow milk' : 'Buffalo milk';

class _PriceListScreenState extends State<PriceListScreen> {
  late final Stream<List<PriceModel>> _prices =
      widget.pricingService.watchPrices();

  Future<void> _setNewRate(MilkType type, PriceModel? current) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SetRateDialog(
        milkType: type,
        current: current,
        authService: widget.authService,
        pricingService: widget.pricingService,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text('${_milkLabel(type)} rate updated.')));
    }
  }

  Widget _currentCard(MilkType type, List<PriceModel> prices) {
    final theme = Theme.of(context);
    // Latest record for this type: the open one, or none yet.
    final mine = prices.where((p) => p.milkType == type).toList();
    final current = mine.isEmpty ? null : mine.first; // newest first
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_milkLabel(type), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (current == null)
                    const Text('No rate set yet')
                  else ...[
                    Text(
                      '₹${_rateFormat.format(current.ratePerLitre)} / litre',
                      style: theme.textTheme.headlineSmall,
                    ),
                    Text('since ${_dateFormat.format(current.effectiveFrom)}'),
                  ],
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => _setNewRate(type, current),
              child: Text(current == null ? 'Set rate' : 'New rate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _history(List<PriceModel> prices) {
    if (prices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No price history yet.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Milk')),
          DataColumn(label: Text('Rate / L'), numeric: true),
          DataColumn(label: Text('Effective from')),
          DataColumn(label: Text('Effective to')),
          DataColumn(label: Text('Changed by')),
          DataColumn(label: Text('Changed on')),
        ],
        rows: [
          for (final p in prices)
            DataRow(cells: [
              DataCell(Text(_milkLabel(p.milkType))),
              DataCell(Text('₹${_rateFormat.format(p.ratePerLitre)}')),
              DataCell(Text(_dateFormat.format(p.effectiveFrom))),
              DataCell(Text(p.effectiveTo == null
                  ? 'Current'
                  : _dateFormat.format(p.effectiveTo!))),
              DataCell(Text(p.changedByName.isEmpty ? '—' : p.changedByName)),
              DataCell(Text(p.changedAt == null
                  ? '—'
                  : _dateFormat.format(p.changedAt!))),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prices')),
      body: StreamBuilder<List<PriceModel>>(
        stream: _prices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load prices. Check your connection.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prices = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final type in MilkType.values) _currentCard(type, prices),
              const SizedBox(height: 16),
              Text('Price history',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _history(prices),
            ],
          );
        },
      ),
    );
  }
}

class _SetRateDialog extends StatefulWidget {
  const _SetRateDialog({
    required this.milkType,
    required this.current,
    required this.authService,
    required this.pricingService,
  });

  final MilkType milkType;
  final PriceModel? current;
  final AuthService authService;
  final PricingService pricingService;

  @override
  State<_SetRateDialog> createState() => _SetRateDialogState();
}

class _SetRateDialogState extends State<_SetRateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  DateTime _from = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = widget.current == null
        ? DateTime(today.year - 1)
        : widget.current!.effectiveFrom.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _from.isBefore(first) ? first : _from,
      firstDate: first,
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.pricingService.setNewRate(
        milkType: widget.milkType,
        ratePerLitre: double.parse(_rateController.text.trim()),
        effectiveFrom: _from,
        changedBy: widget.authService.currentUserId ?? '',
        changedByName: await widget.authService.currentUserName(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PricingException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not save the rate. Check your connection and try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final backdated = _from.isBefore(today);
    final current = widget.current;

    return AlertDialog(
      title: Text('New ${_milkLabel(widget.milkType).toLowerCase()} rate'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (current != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Current: ₹${_rateFormat.format(current.ratePerLitre)} / L '
                    'since ${_dateFormat.format(current.effectiveFrom)}. It will '
                    'end the day before the new rate starts.',
                  ),
                ),
              TextFormField(
                controller: _rateController,
                enabled: !_saving,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Rate per litre (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final rate = double.tryParse(v?.trim() ?? '');
                  return (rate == null || rate <= 0)
                      ? 'Enter a rate above 0'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.event),
                label: Text('Effective from ${_dateFormat.format(_from)}'),
              ),
              if (backdated) ...[
                const SizedBox(height: 8),
                Text(
                  'This date is in the past, so it will apply to those days '
                  'when a bill is generated.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
