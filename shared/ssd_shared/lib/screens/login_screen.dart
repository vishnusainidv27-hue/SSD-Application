import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

/// Shared login screen for all three apps: mobile number + password only
/// (no email, no OTP). Accounts are created by Admin; see [AuthService].
///
/// On success, [onLoginSuccess] is called with the user's role from
/// `users/{uid}`; the host app decides where to navigate.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLoginSuccess,
    this.title = 'SSD Farm',
  });

  final AuthService authService;
  final void Function(String role) onLoginSuccess;
  final String title;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _minMobileDigits = 10;
  static const int _maxMobileDigits = 15;

  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateMobile(String? value) {
    final mobile = value?.trim() ?? '';
    if (mobile.isEmpty) return 'Enter your mobile number';
    if (mobile.length < _minMobileDigits) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.signIn(
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
      );
      final role = await widget.authService.currentUserRole();
      if (role == null) {
        // Signed in but rejected (deactivated, or no profile/role): don't
        // leave a half-authenticated session.
        final deactivated = await widget.authService.isCurrentUserDeactivated();
        await widget.authService.signOut();
        _fail(deactivated
            ? 'This account has been deactivated. Contact Admin.'
            : 'Your account has no role assigned. Please contact Admin.');
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onLoginSuccess(role);
    } on FirebaseAuthException catch (e) {
      _fail(_messageForAuthError(e));
    } on FirebaseException catch (e) {
      // Firestore failure while reading the role.
      await _signOutQuietly();
      _fail(e.code == 'unavailable'
          ? 'No internet connection. Please try again.'
          : 'Could not load your account. Please try again.');
    } catch (_) {
      await _signOutQuietly();
      _fail('Something went wrong. Please try again.');
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await widget.authService.signOut();
    } catch (_) {}
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
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-email':
        return 'Incorrect mobile number or password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact Admin.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with your mobile number',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _mobileController,
                      enabled: !_loading,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_maxMobileDigits),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateMobile,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_loading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
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
                      validator: _validatePassword,
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
                            : const Text('Sign in'),
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
