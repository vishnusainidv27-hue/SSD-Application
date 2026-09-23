import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'firebase_options.dart';
import 'screens/daily_delivery_list_screen.dart';

/// Entry point for SSD Farm — Delivery Boy.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Requirements §6.5 (offline support): Cloud Firestore already persists
    // its cache to disk by default on Android/iOS, so marks made with no
    // signal are queued and sync automatically once connectivity returns.
    // Set explicitly so that's not left to an SDK default silently changing.
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
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
      title: 'SSD Farm — Delivery',
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
                  'Run `flutterfire configure` in the Delivery Boy App folder, '
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

/// Decides between the login screen and the daily delivery list based on the
/// persisted Firebase session and the user's role.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  static const String _deliveryBoyRole = 'deliveryBoy';

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _checking = true;
  bool _isDeliveryBoy = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    var isDeliveryBoy = false;
    try {
      final role = await _authService.currentUserRole();
      isDeliveryBoy = role == _deliveryBoyRole;
      if (role != null && !isDeliveryBoy) {
        // Signed in as a non-delivery-boy: this app is delivery-boy-only.
        await _authService.signOut();
      }
    } catch (_) {
      // Offline or lookup failed: fall back to the login screen.
    }
    if (!mounted) return;
    setState(() {
      _isDeliveryBoy = isDeliveryBoy;
      _checking = false;
    });
  }

  Future<void> _handleLoginSuccess(String role) async {
    if (role == _deliveryBoyRole) {
      setState(() => _isDeliveryBoy = true);
      return;
    }
    await _authService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This app is for Delivery Boy accounts only.')));
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() => _isDeliveryBoy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isDeliveryBoy) {
      final deliveryBoyId = _authService.currentUserId;
      if (deliveryBoyId == null) {
        return LoginScreen(
          authService: _authService,
          onLoginSuccess: _handleLoginSuccess,
          title: 'SSD Farm — Delivery',
        );
      }
      return DailyDeliveryListScreen(
        deliveryBoyId: deliveryBoyId,
        firestoreService: _firestoreService,
        onSignOut: _handleSignOut,
      );
    }
    return LoginScreen(
      authService: _authService,
      onLoginSuccess: _handleLoginSuccess,
      title: 'SSD Farm — Delivery',
    );
  }
}
