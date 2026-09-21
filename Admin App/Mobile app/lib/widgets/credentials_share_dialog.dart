import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Builds the pre-filled message Admin sends to a user with their login.
String credentialsMessage({required String mobile, required String password}) =>
    'Your SSD Farm app login — Mobile: $mobile, Password: $password. '
    'Download the app and sign in with these details.';

/// Shows a login's mobile number and password with Copy and Share buttons, so
/// Admin can send them straight to the user (WhatsApp/SMS/etc.) and keep a
/// record in their own sent messages. Reused after both creating a login and
/// resetting a password.
Future<void> showCredentialsShareDialog(
  BuildContext context, {
  required String title,
  required String name,
  required String mobile,
  required String password,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CredentialsShareDialog(
      title: title,
      name: name,
      mobile: mobile,
      password: password,
    ),
  );
}

class _CredentialsShareDialog extends StatelessWidget {
  const _CredentialsShareDialog({
    required this.title,
    required this.name,
    required this.mobile,
    required this.password,
  });

  final String title;
  final String name;
  final String mobile;
  final String password;

  String get _message => credentialsMessage(mobile: mobile, password: password);

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _message));
    messenger.showSnackBar(
      const SnackBar(content: Text('Login details copied.')),
    );
  }

  Future<void> _share(BuildContext context) async {
    // iPad needs an anchor rect for the share sheet.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(
      ShareParams(
        text: _message,
        subject: 'Your SSD Farm login',
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium;
    final valueStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send these details to $name now. This is the only time the '
                'password is shown, so copy or share it before closing.'),
            const SizedBox(height: 16),
            Text('Mobile', style: labelStyle),
            SelectableText(mobile, style: valueStyle),
            const SizedBox(height: 12),
            Text('Password', style: labelStyle),
            SelectableText(password, style: valueStyle),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
        ),
        TextButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
