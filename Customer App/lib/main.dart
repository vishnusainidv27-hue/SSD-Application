import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'firebase_options.dart';
import 'screens/customer_home_screen.dart';

/// Entry point for SSD Farm — Customer.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    firebaseError = e;
  }

  runApp(SsdApp(firebaseError: firebaseError));
}

class SsdApp extends StatelessWidget {
  const SsdApp({super.key, this.firebaseError});

  /// Non-null when Firebase.initializeApp failed.
  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSD Farm',
      theme: AppTheme.light,
      home: firebaseError != null
          ? FirebaseNotConfiguredScreen(error: firebaseError!)
          : const _AuthGate(),
    );
  }
}

/// Shown instead of crashing when Firebase can't be initialised.
class FirebaseNotConfiguredScreen extends StatelessWidget {
  const FirebaseNotConfiguredScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  "Firebase isn't configured yet",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Run `flutterfire configure` in the Customer App folder, '
                  'then restart the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Decides between the login screen and the Customer home based on the
/// persisted Firebase session and the user's role.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  static const String _customerRole = 'customer';

  final _authService = AuthService();

  bool _checking = true;
  bool _isCustomer = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    var isCustomer = false;
    try {
      final role = await _authService.currentUserRole();
      isCustomer = role == _customerRole;
      if (role != null && !isCustomer) {
        // Signed in as a non-customer: this app is Customer-only.
        await _authService.signOut();
      }
    } catch (_) {
      // Offline or lookup failed: fall back to the login screen.
    }
    if (!mounted) return;
    setState(() {
      _isCustomer = isCustomer;
      _checking = false;
    });
  }

  Future<void> _handleLoginSuccess(String role) async {
    if (role == _customerRole) {
      setState(() => _isCustomer = true);
      return;
    }
    await _authService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This app is for Customer accounts only.')),
    );
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() => _isCustomer = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isCustomer) {
      return CustomerHomeScreen(onSignOut: _handleSignOut);
    }
    return LoginScreen(
      authService: _authService,
      onLoginSuccess: _handleLoginSuccess,
      title: 'SSD Farm',
    );
  }
}
