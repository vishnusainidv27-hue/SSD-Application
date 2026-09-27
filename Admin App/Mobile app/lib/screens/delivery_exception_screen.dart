import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';
import 'package:table_calendar/table_calendar.dart';

/// Per-customer delivery calendar (Requirements §4.2.4): Admin multi-selects
/// upcoming dates and marks them "no delivery" or "different quantity". Saved
/// to `deliveryExceptions` as already-approved exceptions.
class DeliveryExceptionScreen extends StatefulWidget {
  const DeliveryExceptionScreen({
    super.key,
    required this.customer,
    required this.authService,
    required this.firestoreService,
  });

  final CustomerModel customer;
  final AuthService authService;
  final FirestoreService firestoreService;

  @override
  State<DeliveryExceptionScreen> createState() =>
      _DeliveryExceptionScreenState();
}

final DateFormat _dateFormat = DateFormat('EEE, dd-MMM-yyyy');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

String _qtyLabel(double litres) =>
    litres < 1 ? '${(litres * 1000).round()} ml' : '${litres.toString()} L';

class _DeliveryExceptionScreenState extends State<DeliveryExceptionScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late final Stream<List<DeliveryExceptionModel>> _exceptions =
      widget.firestoreService.watchExceptions(widget.customer.id);

  final Set<DateTime> _selected = {};
  DateTime _focused = DateTime.now();
  List<DeliveryExceptionModel> _all = const [];
  List<SubscriptionModel> _subscriptions = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    try {
      final subs =
          await widget.firestoreService.getSubscriptions(widget.customer.id);
      if (mounted) setState(() => _subscriptions = subs);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load the customer\'s subscription, so quantity '
            'changes are unavailable. Skipping still works.');
      }
    }
  }

  // table_calendar hands out UTC dates; keep everything as local calendar dates.
  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DeliveryExceptionModel> _forDay(DateTime day) => [
        for (final e in _all)
          if (e.date == _day(day)) e,
      ];

  Future<void> _save(List<DeliveryExceptionModel> exceptions, String what) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.firestoreService.saveExceptions(exceptions);
      if (!mounted) return;
      final n = exceptions.length;
      setState(() {
        _saving = false;
        _selected.clear();
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('$what saved for $n date${n == 1 ? '' : 's'}.')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Check your connection and try again.';
      });
    }
  }

  Future<void> _skipSelected() {
    final uid = widget.authService.currentUserId;
    return _save([
      for (final d in _selected)
        DeliveryExceptionModel(
          customerId: widget.customer.id,
          date: d,
          type: ExceptionType.skip,
          approvedBy: uid,
        ),
    ], 'No-delivery');
  }

  Future<void> _changeQuantity() async {
    final result = await showDialog<({MilkType type, double qty})>(
      context: context,
      builder: (_) => _QuantityDialog(
        milkTypes: [for (final s in _subscriptions) s.milkType],
      ),
    );
    if (result == null || !mounted) return;
    final uid = widget.authService.currentUserId;
    await _save([
      for (final d in _selected)
        DeliveryExceptionModel(
          customerId: widget.customer.id,
          date: d,
          type: ExceptionType.quantityChange,
          milkType: result.type,
          requestedQty: result.qty,
          approvedBy: uid,
        ),
    ], 'Quantity change');
  }

  Future<void> _delete(DeliveryExceptionModel e) async {
    try {
      await widget.firestoreService.deleteException(e.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not remove it.')));
    }
  }

  String _describe(DeliveryExceptionModel e) => e.type == ExceptionType.skip
      ? 'No delivery'
      : '${_milkLabel(e.milkType!)}: ${_qtyLabel(e.requestedQty ?? 0)}';

  /// A customer request (Phase 5) can land in this same list before Admin has
  /// acted on it — label it clearly so it's never mistaken for something
  /// already in effect.
  String? _statusSuffix(DeliveryExceptionModel e) => switch (e.status) {
        ExceptionStatus.pending => ' — pending customer request, not yet '
            'in effect (see Approval queue)',
        ExceptionStatus.rejected => ' — rejected'
            '${e.note == null || e.note!.isEmpty ? '' : ': ${e.note}'}',
        ExceptionStatus.approved => null,
      };

  Widget _marker(DateTime day) {
    final items = _forDay(day);
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Only an approved exception is actually in effect; a pending/rejected
    // one (from a customer request) gets a neutral dot so it's never read as
    // "this is what will happen."
    final inEffect = [
      for (final e in items)
        if (e.status == ExceptionStatus.approved) e,
    ];
    final Color color;
    if (inEffect.any((e) => e.type == ExceptionType.skip)) {
      color = theme.colorScheme.error;
    } else if (inEffect.isNotEmpty) {
      color = theme.colorScheme.tertiary;
    } else {
      color = theme.colorScheme.outline;
    }
    return Positioned(
      bottom: 4,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAct = _selected.isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.customer.name} — calendar')),
      body: StreamBuilder<List<DeliveryExceptionModel>>(
        stream: _exceptions,
        builder: (context, snapshot) {
          _all = snapshot.data ?? const [];
          final upcoming = [
            for (final e in _all)
              if (!e.date.isBefore(_today)) e,
          ];
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              TableCalendar<DeliveryExceptionModel>(
                firstDay: _today,
                lastDay: DateTime(_today.year + 1, _today.month, _today.day),
                focusedDay: _focused.isBefore(_today) ? _today : _focused,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                selectedDayPredicate: (d) => _selected.contains(_day(d)),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _focused = focused;
                    final d = _day(selected);
                    if (!_selected.remove(d)) _selected.add(d);
                  });
                },
                onPageChanged: (focused) => _focused = focused,
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, _) => _marker(day),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _selected.isEmpty
                      ? 'Tap dates to select them. Red dot = no delivery, '
                          'other dot = quantity change, grey dot = pending '
                          'customer request.'
                      : '${_selected.length} date${_selected.length == 1 ? '' : 's'} selected',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canAct ? _skipSelected : null,
                        icon: const Icon(Icons.block),
                        label: const Text('No delivery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: canAct && _subscriptions.isNotEmpty
                            ? _changeQuantity
                            : null,
                        icon: const Icon(Icons.local_drink_outlined),
                        label: const Text('Change quantity'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Upcoming changes',
                    style: theme.textTheme.titleMedium),
              ),
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Could not load changes.'),
                )
              else if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('None. This customer gets their normal '
                      'delivery every day.'),
                )
              else
                for (final e in upcoming)
                  ListTile(
                    leading: Icon(
                      e.type == ExceptionType.skip
                          ? Icons.block
                          : Icons.local_drink_outlined,
                      color: e.type == ExceptionType.skip
                          ? theme.colorScheme.error
                          : theme.colorScheme.tertiary,
                    ),
                    title: Text(_dateFormat.format(e.date)),
                    subtitle:
                        Text('${_describe(e)}${_statusSuffix(e) ?? ''}'),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(e),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.milkTypes});

  final List<MilkType> milkTypes;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  static const List<double> _presets = [0.5, 1.0, 1.5, 2.0];
  static const double _custom = -1; // dropdown sentinel

  final _formKey = GlobalKey<FormState>();
  final _customController = TextEditingController();
  late MilkType _type = widget.milkTypes.first;
  double _choice = 1.0;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final qty = _choice == _custom
        ? double.parse(_customController.text.trim())
        : _choice;
    Navigator.of(context).pop((type: _type, qty: qty));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change quantity'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.milkTypes.length > 1) ...[
                DropdownButtonFormField<MilkType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Milk type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in widget.milkTypes)
                      DropdownMenuItem(value: t, child: Text(_milkLabel(t))),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 16),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text('${_milkLabel(_type)} milk'),
                ),
              DropdownButtonFormField<double>(
                initialValue: _choice,
                decoration: const InputDecoration(
                  labelText: 'Quantity for the selected dates',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final q in _presets)
                    DropdownMenuItem(value: q, child: Text(_qtyLabel(q))),
                  const DropdownMenuItem(value: _custom, child: Text('Custom…')),
                ],
                onChanged: (v) => setState(() => _choice = v ?? 1.0),
              ),
              if (_choice == _custom) ...[
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
                        ? 'Enter a quantity above 0 (use "No delivery" to skip)'
                        : null;
                  },
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
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
