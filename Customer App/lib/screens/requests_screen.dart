import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Customer's "Skip a day" / "Change quantity" request flow, plus the status
/// and history of everything they've asked for so far (Requirements §5.5).
/// A request always needs Admin's approval before it takes effect — the old
/// plan stays in force until then (see [plannedDeliveriesForDate]).
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.customerId,
    required this.firestoreService,
  });

  final String customerId;
  final FirestoreService firestoreService;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

final DateFormat _dateFormat = DateFormat('EEE, dd-MMM-yyyy');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';
String _qtyLabel(double l) => l < 1 ? '${(l * 1000).round()} ml' : '$l L';

String _statusLabel(ExceptionStatus s) => switch (s) {
      ExceptionStatus.pending => 'Pending admin approval',
      ExceptionStatus.approved => 'Approved',
      ExceptionStatus.rejected => 'Rejected',
    };

Color _statusColor(BuildContext context, ExceptionStatus s) {
  final scheme = Theme.of(context).colorScheme;
  return switch (s) {
    ExceptionStatus.pending => scheme.primary,
    ExceptionStatus.approved => scheme.tertiary,
    ExceptionStatus.rejected => scheme.error,
  };
}

String _describe(DeliveryExceptionModel e) {
  final scope =
      e.appliesFrom == ExceptionScope.onward ? ' (from this date onward)' : '';
  return e.type == ExceptionType.skip
      ? 'Skip delivery'
      : '${_milkLabel(e.milkType!)}: ${_qtyLabel(e.requestedQty ?? 0)}$scope';
}

class _RequestsScreenState extends State<RequestsScreen> {
  late final Stream<List<DeliveryExceptionModel>> _requests =
      widget.firestoreService.watchExceptions(widget.customerId);

  Future<void> _openForm() async {
    final subs = await widget.firestoreService.getSubscriptions(widget.customerId);
    if (!mounted) return;
    if (subs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No milk subscription on file — contact Admin.')));
      return;
    }
    final request = await showDialog<DeliveryExceptionModel>(
      context: context,
      builder: (_) => _RequestFormDialog(
        customerId: widget.customerId,
        milkTypes: [for (final s in subs) s.milkType],
      ),
    );
    if (request == null || !mounted) return;
    try {
      await widget.firestoreService.submitRequest(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request sent — waiting for Admin approval.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not send your request. Check your connection.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change / skip delivery')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: StreamBuilder<List<DeliveryExceptionModel>>(
        stream: _requests,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load your requests. Check your '
                    'connection and try again.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = [...snapshot.data!]
            ..sort((a, b) => b.date.compareTo(a.date));
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No requests yet. Tap "New request" to skip a day or '
                  'change your quantity.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = requests[i];
              final color = _statusColor(context, e.status);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    e.type == ExceptionType.skip
                        ? Icons.block
                        : Icons.local_drink_outlined,
                    color: color,
                  ),
                ),
                title: Text(_dateFormat.format(e.date)),
                subtitle: Text(
                  '${_describe(e)}\n${_statusLabel(e.status)}'
                  '${e.status == ExceptionStatus.rejected && e.note != null && e.note!.isNotEmpty ? ' — ${e.note}' : ''}',
                ),
                isThreeLine: true,
                trailing: Text(_statusLabel(e.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              );
            },
          );
        },
      ),
    );
  }
}

enum _RequestKind { skip, changeQuantity }

class _RequestFormDialog extends StatefulWidget {
  const _RequestFormDialog({required this.customerId, required this.milkTypes});

  final String customerId;
  final List<MilkType> milkTypes;

  @override
  State<_RequestFormDialog> createState() => _RequestFormDialogState();
}

class _RequestFormDialogState extends State<_RequestFormDialog> {
  static const List<double> _presets = [0.5, 1.0, 1.5, 2.0];
  static const double _custom = -1; // dropdown sentinel

  final _formKey = GlobalKey<FormState>();
  final _customController = TextEditingController();

  DateTime? _date;
  _RequestKind _kind = _RequestKind.skip;
  late MilkType _milkType = widget.milkTypes.first;
  ExceptionScope _scope = ExceptionScope.single;
  double _quantityChoice = 1.0;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final tomorrow =
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? tomorrow,
      firstDate: tomorrow,
      lastDate: tomorrow.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (_date == null) {
      setState(() {}); // trigger the "pick a date" validator text below
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final request = _kind == _RequestKind.skip
        ? DeliveryExceptionModel(
            customerId: widget.customerId,
            date: _date!,
            type: ExceptionType.skip,
            status: ExceptionStatus.pending,
          )
        : DeliveryExceptionModel(
            customerId: widget.customerId,
            date: _date!,
            type: ExceptionType.quantityChange,
            milkType: _milkType,
            requestedQty: _quantityChoice == _custom
                ? double.parse(_customController.text.trim())
                : _quantityChoice,
            appliesFrom: _scope,
            status: ExceptionStatus.pending,
          );
    Navigator.of(context).pop(request);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New request'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(_date == null
                    ? 'Pick an upcoming date'
                    : _dateFormat.format(_date!)),
              ),
              if (_date == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Choose a date to continue.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
              const SizedBox(height: 16),
              SegmentedButton<_RequestKind>(
                segments: const [
                  ButtonSegment(
                      value: _RequestKind.skip,
                      label: Text('Skip'),
                      icon: Icon(Icons.block)),
                  ButtonSegment(
                      value: _RequestKind.changeQuantity,
                      label: Text('Change quantity'),
                      icon: Icon(Icons.local_drink_outlined)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              if (_kind == _RequestKind.changeQuantity) ...[
                const SizedBox(height: 16),
                if (widget.milkTypes.length > 1)
                  DropdownButtonFormField<MilkType>(
                    initialValue: _milkType,
                    decoration: const InputDecoration(
                      labelText: 'Milk type',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final t in widget.milkTypes)
                        DropdownMenuItem(value: t, child: Text(_milkLabel(t))),
                    ],
                    onChanged: (v) => setState(() => _milkType = v ?? _milkType),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<double>(
                  initialValue: _quantityChoice,
                  decoration: const InputDecoration(
                    labelText: 'New quantity',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final q in _presets)
                      DropdownMenuItem(value: q, child: Text(_qtyLabel(q))),
                    const DropdownMenuItem(value: _custom, child: Text('Custom…')),
                  ],
                  onChanged: (v) => setState(() => _quantityChoice = v ?? 1.0),
                ),
                if (_quantityChoice == _custom) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Custom quantity (litres)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final q = double.tryParse(v?.trim() ?? '');
                      return (q == null || q <= 0)
                          ? 'Enter a quantity above 0'
                          : null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text('Apply this change:',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<ExceptionScope>(
                  segments: const [
                    ButtonSegment(
                        value: ExceptionScope.single,
                        label: Text('This date only')),
                    ButtonSegment(
                        value: ExceptionScope.onward,
                        label: Text('From this date onward')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) => setState(() => _scope = s.first),
                ),
                if (_scope == ExceptionScope.onward)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Applies from this date until you change it again.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send request')),
      ],
    );
  }
}
