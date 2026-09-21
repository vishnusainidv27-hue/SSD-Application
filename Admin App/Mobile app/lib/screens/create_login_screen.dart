import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../widgets/credentials_share_dialog.dart';

/// Admin-only form to create a login (mobile number + password + role) for a
/// customer, delivery boy or another admin. Uses [AuthService.createUserAccount],
/// which leaves the Admin's own session untouched.
class CreateLoginScreen extends StatefulWidget {
  const CreateLoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<CreateLoginScreen> createState() => _CreateLoginScreenState();
}

class _CreateLoginScreenState extends State<CreateLoginScreen> {
  static const List<String> _roles = ['customer', 'deliveryBoy', 'admin'];
  static const int _minPasswordLength = 6; // Firebase Auth minimum

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = _roles.first;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final mobile = AuthService.normalizeMobile(_mobileController.text.trim());
    final password = _passwordController.text;
    try {
      await widget.authService.createUserAccount(
        mobile: mobile,
        password: password,
        name: name,
        role: _role,
      );
      if (!mounted) return;
      _formKey.currentState?.reset();
      _nameController.clear();
      _mobileController.clear();
      _passwordController.clear();
      setState(() {
        _loading = false;
        _role = _roles.first;
      });
      // The password is never stored, so this is Admin's one chance to send it
      // to the user and keep a record in their own sent messages.
      await showCredentialsShareDialog(
        context,
        title: 'Login created',
        name: name,
        mobile: mobile,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _fail(_messageForAuthError(e));
    } on FirebaseException catch (e) {
      // Auth user was rolled back by AuthService; this is the profile write.
      _fail(e.code == 'permission-denied'
          ? 'Permission denied saving the profile. Check Firestore rules.'
          : 'Could not save the profile (${e.code}). Please try again.');
    } on ArgumentError {
      _fail('Enter a valid 10-digit mobile number.');
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
      case 'email-already-in-use':
        return 'A login for this mobile number already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least $_minPasswordLength characters.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Auth.';
      default:
        return 'Could not create the login (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create login')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_loading,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      enabled: !_loading,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final mobile = v?.trim() ?? '';
                        if (mobile.isEmpty) return 'Enter a mobile number';
                        if (mobile.length < 10) {
                          return 'Enter a valid mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < _minPasswordLength)
                              ? 'Use at least $_minPasswordLength characters'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final role in _roles)
                          DropdownMenuItem(value: role, child: Text(role)),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value != null) setState(() => _role = value);
                            },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
