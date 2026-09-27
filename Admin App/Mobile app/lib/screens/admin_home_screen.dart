import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

import 'approval_queue_screen.dart';
import 'create_login_screen.dart';
import 'customer_list_screen.dart';
import 'delivery_tracking_screen.dart';
import 'price_list_screen.dart';
import 'reports/reports_screen.dart';

/// Landing dashboard for a signed-in Admin: a greeting header, then every
/// area of the app grouped into clearly separated, titled sections
/// (Requirements: this is the hub Admin works from all day) — see
/// `docs/DESIGN_SYSTEM.md` for the layout pattern.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({
    super.key,
    required this.authService,
    required this.onSignOut,
  });

  final AuthService authService;
  final VoidCallback onSignOut;

  void _open(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSD Farm — Admin'),
        actions: [
          if (authService.currentUserId != null)
            NotificationCentre(
              userId: authService.currentUserId!,
              firestoreService: FirestoreService(),
            ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        children: [
          _WelcomeHeader(authService: authService),
          const SectionHeader('Customers & delivery',
              icon: Icons.route_outlined, topGap: false),
          _ActionGrid(tiles: [
            _ActionTile(
              icon: Icons.people_alt_outlined,
              title: 'Customers',
              subtitle: 'Onboard, edit, search',
              onTap: () => _open(
                context,
                (_) => CustomerListScreen(
                  authService: authService,
                  firestoreService: FirestoreService(),
                  pricingService: PricingService(),
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.local_shipping_outlined,
              title: 'Delivery tracking',
              subtitle: "Today's status, live",
              onTap: () => _open(
                context,
                (_) => DeliveryTrackingScreen(
                  firestoreService: FirestoreService(),
                  planningService: DeliveryPlanningService(
                    firestoreService: FirestoreService(),
                    pricingService: PricingService(),
                  ),
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.fact_check_outlined,
              title: 'Approval queue',
              subtitle: 'Customer requests',
              onTap: () => _open(
                context,
                (_) => ApprovalQueueScreen(
                  authService: authService,
                  firestoreService: FirestoreService(),
                ),
              ),
            ),
          ]),
          const SectionHeader('Pricing & reports', icon: Icons.insights_outlined),
          _ActionGrid(tiles: [
            _ActionTile(
              icon: Icons.currency_rupee,
              title: 'Prices',
              subtitle: 'Date-effective rates',
              onTap: () => _open(
                context,
                (_) => PriceListScreen(
                  authService: authService,
                  pricingService: PricingService(),
                  firestoreService: FirestoreService(),
                ),
              ),
            ),
            _ActionTile(
              icon: Icons.bar_chart_outlined,
              title: 'Reports',
              subtitle: 'Delivery, billing & more',
              onTap: () => _open(
                context,
                (_) => ReportsScreen(firestoreService: FirestoreService()),
              ),
            ),
          ]),
          const SectionHeader('Account', icon: Icons.manage_accounts_outlined),
          _ActionGrid(tiles: [
            _ActionTile(
              icon: Icons.person_add_alt_1,
              title: 'Create login',
              subtitle: 'Customer, delivery boy, admin',
              onTap: () =>
                  _open(context, (_) => CreateLoginScreen(authService: authService)),
            ),
            _ActionTile(
              icon: Icons.logout,
              title: 'Log out',
              subtitle: 'End this session',
              onTap: onSignOut,
            ),
          ]),
        ],
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppTheme.brandNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Admin',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Everything you need to run SSD Farm, in one place.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A responsive 2-column grid of [_ActionTile]s (single column on very
/// narrow phones) — the recurring "pick a task" pattern for every Admin
/// screen's landing area.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.tiles});

  final List<_ActionTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 360 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: columns == 2 ? 2.6 : 4.2,
          children: tiles,
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.brandNavy),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
