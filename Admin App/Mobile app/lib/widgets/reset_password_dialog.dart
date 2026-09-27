import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Asks Admin for the customer's current password and a new one, then resets
/// it with [AuthService.changeUserPassword] (which signs in as the customer on
/// a temporary Firebase instance, so Admin's own session is untouched).
///
/// Returns the new password on success, or null if cancelled. The caller shows
/// the copy/share step afterwards.
Future<String?> showResetPasswordDialog(
  BuildContext context, {
  required AuthService authService,
  required CustomerModel customer,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _ResetPasswordDialog(authService: authService, customer: customer),
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.authService,
    required this.customer,
  });

  final AuthService authService;
  final CustomerModel customer;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  static const int _minPasswordLength = 6; // Firebase Auth minimum

  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final newPassword = _newController.text;
    try {
      await widget.authService.changeUserPassword(
        mobile: widget.customer.mobile,
        oldPassword: _currentController.text,
        newPassword: newPassword,
      );
      if (!mounted) return;
      Navigator.of(context).pop(newPassword);
    } on FirebaseAuthException catch (e) {
      _fail(_messageForAuthError(e));
    } catch (_) {
      _fail('Something went wrong. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  String _messageForAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'The current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak. Use at least '
            '$_minPasswordLength characters.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Could not reset the password (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${widget.customer.name} (${widget.customer.mobile})'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter the current password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < _minPasswordLength)
                    ? 'Use at least $_minPasswordLength characters'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reset'),
        ),
      ],
    );
  }
}
