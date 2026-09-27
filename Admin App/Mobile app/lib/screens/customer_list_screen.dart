import 'package:flutter/material.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../utils/customer_filter.dart';
import '../widgets/credentials_share_dialog.dart';
import '../widgets/reset_password_dialog.dart';
import 'add_edit_customer_screen.dart';
import 'bill_generation_screen.dart';
import 'delivery_exception_screen.dart';

/// Admin's customer master list (Requirements §4.3): live list with search
/// (name / mobile / society / block / flat), filters (society, milk type,
/// active status) and per-customer edit / deactivate / reactivate / reset
/// password actions.
///
/// The delivery-boy/route filter arrives with delivery-boy management
/// (Phase 6), since there is nothing to assign customers to yet.
class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({
    super.key,
    required this.authService,
    required this.firestoreService,
    required this.pricingService,
  });

  final AuthService authService;
  final FirestoreService firestoreService;
  final PricingService pricingService;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

enum _CustomerAction { edit, calendar, bill, resetPassword, toggleActive }

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _searchController = TextEditingController();
  late final Stream<List<CustomerModel>> _customers =
      widget.firestoreService.watchCustomers();

  String _query = '';
  String? _society;
  MilkType? _milkType;
  CustomerStatusFilter _status = CustomerStatusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddEdit([CustomerModel? customer]) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditCustomerScreen(
          authService: widget.authService,
          firestoreService: widget.firestoreService,
          customer: customer,
        ),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openCalendar(CustomerModel customer) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DeliveryExceptionScreen(
          customer: customer,
          authService: widget.authService,
          firestoreService: widget.firestoreService,
        ),
      ),
    );
  }

  void _openBill(CustomerModel customer) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BillGenerationScreen(
          customer: customer,
          authService: widget.authService,
          firestoreService: widget.firestoreService,
          pricingService: widget.pricingService,
        ),
      ),
    );
  }

  Future<void> _resetPassword(CustomerModel customer) async {
    final newPassword = await showResetPasswordDialog(
      context,
      authService: widget.authService,
      customer: customer,
    );
    if (newPassword == null || !mounted) return;
    await showCredentialsShareDialog(
      context,
      title: 'Password reset',
      name: customer.name,
      mobile: customer.mobile,
      password: newPassword,
    );
  }

  Future<void> _toggleActive(CustomerModel customer) async {
    final deactivating = customer.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(deactivating ? 'Deactivate customer?' : 'Reactivate customer?'),
        content: Text(deactivating
            ? '${customer.name} will no longer be able to log in. '
                'You can reactivate them at any time.'
            : '${customer.name} will be able to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(deactivating ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.firestoreService
          .setCustomerActive(customer.id, !customer.active);
      _snack(deactivating
          ? '${customer.name} deactivated.'
          : '${customer.name} reactivated.');
    } catch (_) {
      _snack('Could not update ${customer.name}. Please try again.');
    }
  }

  String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow' : 'Buffalo';

  Widget _filters(List<String> societies) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final s in CustomerStatusFilter.values) ...[
            ChoiceChip(
              label: Text(switch (s) {
                CustomerStatusFilter.all => 'All',
                CustomerStatusFilter.active => 'Active',
                CustomerStatusFilter.inactive => 'Inactive',
              }),
              selected: _status == s,
              onSelected: (_) => setState(() => _status = s),
            ),
            const SizedBox(width: 8),
          ],
          for (final t in MilkType.values) ...[
            FilterChip(
              label: Text(_milkLabel(t)),
              selected: _milkType == t,
              onSelected: (on) => setState(() => _milkType = on ? t : null),
            ),
            const SizedBox(width: 8),
          ],
          if (societies.isNotEmpty)
            PopupMenuButton<String?>(
              tooltip: 'Filter by society',
              onSelected: (value) => setState(() => _society = value),
              itemBuilder: (_) => [
                const PopupMenuItem<String?>(
                    value: null, child: Text('All societies')),
                for (final s in societies)
                  PopupMenuItem<String?>(value: s, child: Text(s)),
              ],
              child: Chip(
                avatar: const Icon(Icons.apartment_outlined, size: 18),
                label: Text(_society ?? 'Society'),
                deleteIcon: _society == null
                    ? const Icon(Icons.arrow_drop_down, size: 18)
                    : const Icon(Icons.close, size: 18),
                onDeleted: _society == null
                    ? () {}
                    : () => setState(() => _society = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(CustomerModel c) {
    final theme = Theme.of(context);
    final details = [
      if (c.societyName.isNotEmpty) c.societyName,
      if (c.blockName.isNotEmpty) 'Block ${c.blockName}',
      if (c.flatNumber.isNotEmpty) 'Flat ${c.flatNumber}',
    ].join(' · ');
    final milk = c.milkTypes.map(_milkLabel).join(' + ');
    final initial = c.name.trim().isEmpty ? '?' : c.name.trim()[0].toUpperCase();

    return ListTile(
      enabled: c.active,
      leading: CircleAvatar(child: Text(initial)),
      title: Text(c.name),
      subtitle: Text([
        c.mobile,
        if (details.isNotEmpty) details,
        if (milk.isNotEmpty) milk,
      ].join('\n')),
      isThreeLine: true,
      onTap: () => _openAddEdit(c),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!c.active)
            Chip(
              label: const Text('Inactive'),
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.colorScheme.errorContainer,
            ),
          PopupMenuButton<_CustomerAction>(
            onSelected: (action) {
              switch (action) {
                case _CustomerAction.edit:
                  _openAddEdit(c);
                case _CustomerAction.calendar:
                  _openCalendar(c);
                case _CustomerAction.bill:
                  _openBill(c);
                case _CustomerAction.resetPassword:
                  _resetPassword(c);
                case _CustomerAction.toggleActive:
                  _toggleActive(c);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: _CustomerAction.edit, child: Text('Edit')),
              const PopupMenuItem(
                  value: _CustomerAction.calendar,
                  child: Text('Delivery calendar')),
              const PopupMenuItem(
                  value: _CustomerAction.bill, child: Text('Generate bill')),
              const PopupMenuItem(
                  value: _CustomerAction.resetPassword,
                  child: Text('Reset password')),
              PopupMenuItem(
                value: _CustomerAction.toggleActive,
                child: Text(c.active ? 'Deactivate' : 'Reactivate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEdit(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add customer'),
      ),
      body: StreamBuilder<List<CustomerModel>>(
        stream: _customers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load customers. Check your connection and '
                  'Firestore rules.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final societies = {
            for (final c in all)
              if (c.societyName.trim().isNotEmpty) c.societyName.trim(),
          }.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          final shown = filterCustomers(
            all,
            query: _query,
            society: _society,
            milkType: _milkType,
            status: _status,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search name, mobile, society, block or flat',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              _filters(societies),
              const SizedBox(height: 4),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(all.isEmpty
                            ? 'No customers yet. Tap “Add customer”.'
                            : 'No customers match these filters.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _tile(shown[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
