import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Central inbox of every customer's pending change/skip request
/// (Requirements §4.7). Approve or reject with an optional note; approving
/// takes effect immediately since the dashboard/history already read
/// exceptions live — there's no separate "apply to the delivery plan" step.
class ApprovalQueueScreen extends StatefulWidget {
  const ApprovalQueueScreen({
    super.key,
    required this.authService,
    required this.firestoreService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

final DateFormat _dateFormat = DateFormat('EEE, dd-MMM-yyyy');

String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';
String _qtyLabel(double l) => l < 1 ? '${(l * 1000).round()} ml' : '$l L';

String _describe(DeliveryExceptionModel e) {
  final scope =
      e.appliesFrom == ExceptionScope.onward ? ' (from this date onward)' : '';
  return e.type == ExceptionType.skip
      ? 'Skip delivery'
      : '${_milkLabel(e.milkType!)}: ${_qtyLabel(e.requestedQty ?? 0)}$scope';
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen> {
  late final Stream<List<DeliveryExceptionModel>> _pending =
      widget.firestoreService.watchPendingRequests();

  final Map<String, CustomerModel?> _customerCache = {};
  bool _busy = false;

  Future<CustomerModel?> _customerFor(String id) async {
    if (_customerCache.containsKey(id)) return _customerCache[id];
    final customer = await widget.firestoreService.getCustomer(id);
    _customerCache[id] = customer;
    return customer;
  }

  Future<void> _respond(DeliveryExceptionModel request, bool approve) async {
    String? note;
    if (!approve) {
      note = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectNoteDialog(),
      );
      if (note == null) return; // cancelled
    }
    setState(() => _busy = true);
    try {
      await widget.firestoreService.respondToRequest(
        request: request,
        approve: approve,
        adminUid: widget.authService.currentUserId ?? '',
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(approve ? 'Request approved.' : 'Request rejected.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your decision. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approval queue')),
      body: StreamBuilder<List<DeliveryExceptionModel>>(
        stream: _pending,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load requests. Check your connection.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final request = requests[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<CustomerModel?>(
                        future: _customerFor(request.customerId),
                        builder: (context, custSnap) => Text(
                          custSnap.data?.name ?? 'Loading…',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_dateFormat.format(request.date)),
                      const SizedBox(height: 4),
                      Text(_describe(request)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _busy ? null : () => _respond(request, false),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  _busy ? null : () => _respond(request, true),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RejectNoteDialog extends StatefulWidget {
  const _RejectNoteDialog();

  @override
  State<_RejectNoteDialog> createState() => _RejectNoteDialogState();
}

class _RejectNoteDialogState extends State<_RejectNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject request'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Note for the customer (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
