import 'package:admin_mobile_app/screens/approval_queue_screen.dart';
import 'package:admin_mobile_app/screens/create_login_screen.dart';
import 'package:admin_mobile_app/screens/customer_list_screen.dart';
import 'package:admin_mobile_app/screens/delivery_tracking_screen.dart';
import 'package:admin_mobile_app/screens/price_list_screen.dart';
import 'package:admin_mobile_app/screens/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

/// Desktop shell for the Admin Web panel (Requirements: office staff working
/// from a desktop, Development Plan Phase 8): a persistent side nav instead
/// of the mobile app's list of big buttons, opening the exact same screens —
/// see `admin_mobile_app` in this app's pubspec.yaml for how that's wired up
/// without duplicating any of them.
class AdminWebHomeScreen extends StatefulWidget {
  const AdminWebHomeScreen({
    super.key,
    required this.authService,
    required this.onSignOut,
  });

  final AuthService authService;
  final VoidCallback onSignOut;

  @override
  State<AdminWebHomeScreen> createState() => _AdminWebHomeScreenState();
}

class _AdminWebHomeScreenState extends State<AdminWebHomeScreen> {
  final _firestoreService = FirestoreService();
  final _pricingService = PricingService();
  final _planningService = DeliveryPlanningService(
    firestoreService: FirestoreService(),
    pricingService: PricingService(),
  );

  late final List<({IconData icon, String label, WidgetBuilder builder})>
      _destinations = [
    (
      icon: Icons.people_alt_outlined,
      label: 'Customers',
      builder: (_) => CustomerListScreen(
        authService: widget.authService,
        firestoreService: _firestoreService,
        pricingService: _pricingService,
      ),
    ),
    (
      icon: Icons.currency_rupee,
      label: 'Prices',
      builder: (_) => PriceListScreen(
        authService: widget.authService,
        pricingService: _pricingService,
        firestoreService: _firestoreService,
      ),
    ),
    (
      icon: Icons.local_shipping_outlined,
      label: 'Delivery tracking',
      builder: (_) => DeliveryTrackingScreen(
        firestoreService: _firestoreService,
        planningService: _planningService,
      ),
    ),
    (
      icon: Icons.fact_check_outlined,
      label: 'Approval queue',
      builder: (_) => ApprovalQueueScreen(
        authService: widget.authService,
        firestoreService: _firestoreService,
      ),
    ),
    (
      icon: Icons.bar_chart_outlined,
      label: 'Reports',
      builder: (_) => ReportsScreen(firestoreService: _firestoreService),
    ),
    (
      icon: Icons.person_add_alt_1,
      label: 'Create login',
      builder: (_) => CreateLoginScreen(authService: widget.authService),
    ),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final userId = widget.authService.currentUserId;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selected,
            onDestinationSelected: (i) => setState(() => _selected = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.local_drink_outlined, size: 32),
                  const SizedBox(height: 8),
                  const Text('SSD Farm', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (userId != null)
                    NotificationCentre(userId: userId, firestoreService: _firestoreService),
                  IconButton(
                    tooltip: 'Log out',
                    icon: const Icon(Icons.logout),
                    onPressed: widget.onSignOut,
                  ),
                ],
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          // Each destination is a full, independent screen (its own
          // Scaffold/AppBar) reused unmodified from the mobile app.
          Expanded(child: _destinations[_selected].builder(context)),
        ],
      ),
    );
  }
}
