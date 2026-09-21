import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'create_login_screen.dart';
import 'customer_list_screen.dart';

/// Landing screen for a signed-in Admin. Placeholder until the Phase 1+
/// dashboard (customers, deliveries, billing) is built.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    super.key,
    required this.authService,
    required this.onSignOut,
  });

  final AuthService authService;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSD Farm — Admin'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome, Admin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Dashboard coming in a later phase.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.people_alt_outlined),
                label: const Text('Customers'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerListScreen(
                      authService: authService,
                      firestoreService: FirestoreService(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Create login'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreateLoginScreen(authService: authService),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
