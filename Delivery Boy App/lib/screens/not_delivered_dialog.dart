import 'package:flutter/material.dart';

/// Requirements §6.3: "'Not Delivered' option with a mandatory reason ... "
/// plus an optional free-text remark on every entry. Combines both into the
/// single string [DeliveryModel.remark] stores. Returns null if cancelled.
class NotDeliveredDialog extends StatefulWidget {
  const NotDeliveredDialog({super.key});

  @override
  State<NotDeliveredDialog> createState() => _NotDeliveredDialogState();
}

const _reasons = [
  'Customer not home',
  'Gate locked',
  'Customer refused',
  'Other',
];

class _NotDeliveredDialogState extends State<NotDeliveredDialog> {
  String _reason = _reasons.first;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _noteController.text.trim();
    Navigator.of(context).pop(note.isEmpty ? _reason : '$_reason — $note');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Not delivered'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final r in _reasons) DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Remark (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
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
