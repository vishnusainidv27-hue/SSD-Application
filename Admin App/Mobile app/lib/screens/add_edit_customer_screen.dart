import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ssd_shared/ssd_shared.dart';

import '../widgets/credentials_share_dialog.dart';

/// Admin form to onboard a new customer (login + profile + address + milk
/// subscription) or, when [customer] is given, edit an existing one
/// (Requirements §4.2, §4.3). Pops with `true` when something was saved.
class AddEditCustomerScreen extends StatefulWidget {
  const AddEditCustomerScreen({
    super.key,
    required this.authService,
    required this.firestoreService,
    this.customer,
  });

  final AuthService authService;
  final FirestoreService firestoreService;
  final CustomerModel? customer;

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  static const int _minPasswordLength = 6; // Firebase Auth minimum
  static const List<double> _quantityPresets = [0.5, 1.0, 1.5, 2.0];
  static const double _customQuantity = -1; // dropdown sentinel
  static const String _passwordChars =
      'abcdefghjkmnpqrstuvwxyz23456789'; // no look-alikes (i, l, o, 0, 1)

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _altMobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _societyController = TextEditingController();
  final _blockController = TextEditingController();
  final _floorController = TextEditingController();
  final _flatController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _addressController = TextEditingController();

  // Per milk type: whether subscribed, the dropdown choice, and a custom value.
  final Map<MilkType, bool> _subscribed = {
    for (final t in MilkType.values) t: false,
  };
  final Map<MilkType, double> _quantityChoice = {
    for (final t in MilkType.values) t: 1.0,
  };
  final Map<MilkType, TextEditingController> _customQuantityControllers = {
    for (final t in MilkType.values) t: TextEditingController(),
  };

  /// Existing subscriptions when editing, so frequency/start date are kept.
  final Map<MilkType, SubscriptionModel> _existingSubscriptions = {};

  double? _latitude;
  double? _longitude;

  bool _loading = false;
  bool _loadingExisting = false;
  bool _loadFailed = false;
  String? _error;

  /// Set once the Auth login + profile exist but the customer write failed, so
  /// a retry doesn't try to create the (now existing) login again.
  String? _createdUid;
  String? _createdPassword;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    if (c != null) {
      _nameController.text = c.name;
      _mobileController.text = c.mobile;
      _altMobileController.text = c.alternateMobile;
      _societyController.text = c.societyName;
      _blockController.text = c.blockName;
      _floorController.text = c.floor;
      _flatController.text = c.flatNumber;
      _landmarkController.text = c.landmark;
      _addressController.text = c.finalAddress;
      _latitude = c.latitude;
      _longitude = c.longitude;
      _loadExistingSubscriptions(c.id);
    } else {
      _passwordController.text = _generatePassword();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _mobileController,
      _altMobileController,
      _passwordController,
      _societyController,
      _blockController,
      _floorController,
      _flatController,
      _landmarkController,
      _addressController,
      ..._customQuantityControllers.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingSubscriptions(String customerId) async {
    setState(() => _loadingExisting = true);
    try {
      final subs = await widget.firestoreService.getSubscriptions(customerId);
      if (!mounted) return;
      setState(() {
        for (final sub in subs) {
          _existingSubscriptions[sub.milkType] = sub;
          _subscribed[sub.milkType] = true;
          if (_quantityPresets.contains(sub.quantityLitres)) {
            _quantityChoice[sub.milkType] = sub.quantityLitres;
          } else {
            _quantityChoice[sub.milkType] = _customQuantity;
            _customQuantityControllers[sub.milkType]!.text =
                sub.quantityLitres.toString();
          }
        }
        _loadingExisting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingExisting = false;
        _loadFailed = true;
        _error = 'Could not load the current milk subscription. '
            'Saving now would overwrite it — go back and try again.';
      });
    }
  }

  String _generatePassword() {
    final random = Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < 8; i++)
        _passwordChars.codeUnitAt(random.nextInt(_passwordChars.length)),
    ]);
  }

  String _computeFinalAddress() => CustomerModel.buildFinalAddress(
        societyName: _societyController.text,
        blockName: _blockController.text,
        floor: _floorController.text,
        flatNumber: _flatController.text,
        landmark: _landmarkController.text,
      );

  void _autoFillAddress() {
    setState(() => _addressController.text = _computeFinalAddress());
  }

  double? _quantityFor(MilkType type) {
    final choice = _quantityChoice[type]!;
    if (choice != _customQuantity) return choice;
    return double.tryParse(_customQuantityControllers[type]!.text.trim());
  }

  List<SubscriptionModel> _buildSubscriptions(String customerId) {
    return [
      for (final type in MilkType.values)
        if (_subscribed[type]!)
          SubscriptionModel(
            id: '${customerId}_${type.name}',
            customerId: customerId,
            milkType: type,
            quantityLitres: _quantityFor(type)!,
            frequency: _existingSubscriptions[type]?.frequency ?? 'daily',
            startDate: _existingSubscriptions[type]?.startDate ??
                DateUtils.dateOnly(DateTime.now()),
          ),
    ];
  }

  Future<void> _submit() async {
    if (_loading || _loadingExisting || _loadFailed) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_subscribed.values.any((v) => v)) {
      setState(() => _error = 'Select at least one milk type.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (_addressController.text.trim().isEmpty) {
      _addressController.text = _computeFinalAddress();
    }
    final name = _nameController.text.trim();
    final mobile = AuthService.normalizeMobile(_mobileController.text.trim());

    try {
      final String customerId;
      final String? passwordToShare;
      if (_isEdit) {
        customerId = widget.customer!.id;
        passwordToShare = null;
      } else if (_createdUid != null) {
        customerId = _createdUid!;
        passwordToShare = _createdPassword;
      } else {
        passwordToShare = _passwordController.text;
        customerId = await widget.authService.createUserAccount(
          mobile: mobile,
          password: passwordToShare,
          name: name,
          role: 'customer',
        );
        _createdUid = customerId;
        _createdPassword = passwordToShare;
      }

      final subscriptions = _buildSubscriptions(customerId);
      final customer = CustomerModel(
        id: customerId,
        name: name,
        mobile: mobile,
        alternateMobile: _altMobileController.text.trim(),
        societyName: _societyController.text.trim(),
        blockName: _blockController.text.trim(),
        floor: _floorController.text.trim(),
        flatNumber: _flatController.text.trim(),
        landmark: _landmarkController.text.trim(),
        finalAddress: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        assignedDeliveryBoyId: widget.customer?.assignedDeliveryBoyId,
        milkTypes: [for (final s in subscriptions) s.milkType],
        active: widget.customer?.active ?? true,
      );

      if (_isEdit) {
        await widget.firestoreService.updateCustomer(customer, subscriptions);
      } else {
        await widget.firestoreService.createCustomer(customer, subscriptions);
      }
      if (!mounted) return;
      setState(() => _loading = false);

      if (!_isEdit) {
        // The password is never stored, so this is Admin's one chance to send
        // it to the customer and keep a record in their own sent messages.
        await showCredentialsShareDialog(
          context,
          title: 'Customer created',
          name: name,
          mobile: mobile,
          password: passwordToShare!,
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      _fail(_messageForAuthError(e));
    } on FirebaseException catch (e) {
      final retryHint = _createdUid != null
          ? ' The login was already created — tap Save again to finish.'
          : '';
      _fail((e.code == 'permission-denied'
              ? 'Permission denied. Check Firestore rules.'
              : 'Could not save the customer (${e.code}).') +
          retryHint);
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

  String _milkLabel(MilkType t) => t == MilkType.cow ? 'Cow milk' : 'Buffalo milk';

  String _quantityLabel(double litres) =>
      litres < 1 ? '${(litres * 1000).round()} ml' : '$litres L';

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _gap() => const SizedBox(height: 16);

  Widget _milkSection(MilkType type) {
    final enabled = !_loading && !_loadingExisting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(_milkLabel(type)),
          value: _subscribed[type],
          onChanged: enabled
              ? (v) => setState(() => _subscribed[type] = v ?? false)
              : null,
        ),
        if (_subscribed[type]!) ...[
          DropdownButtonFormField<double>(
            initialValue: _quantityChoice[type],
            decoration: const InputDecoration(
              labelText: 'Quantity per day',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final q in _quantityPresets)
                DropdownMenuItem(value: q, child: Text(_quantityLabel(q))),
              const DropdownMenuItem(
                  value: _customQuantity, child: Text('Custom…')),
            ],
            onChanged: enabled
                ? (v) => setState(() => _quantityChoice[type] = v ?? 1.0)
                : null,
          ),
          if (_quantityChoice[type] == _customQuantity) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _customQuantityControllers[type],
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Custom quantity (litres)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final q = double.tryParse(v?.trim() ?? '');
                return (q == null || q <= 0) ? 'Enter a quantity above 0' : null;
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !_loading;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'Add customer')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Customer'),
                    TextFormField(
                      controller: _nameController,
                      enabled: enabled,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a name'
                          : null,
                    ),
                    _gap(),
                    TextFormField(
                      controller: _mobileController,
                      // The mobile number is the login ID, so it can't change.
                      enabled: enabled && !_isEdit && _createdUid == null,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Mobile number (login ID)',
                        helperText:
                            _isEdit ? 'Login ID cannot be changed.' : null,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
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
                    _gap(),
                    TextFormField(
                      controller: _altMobileController,
                      enabled: enabled,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Alternate number (optional)',
                        prefixIcon: Icon(Icons.phone_forwarded_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (!_isEdit) ...[
                      _gap(),
                      TextFormField(
                        controller: _passwordController,
                        enabled: enabled && _createdUid == null,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: 'Shown again after saving so you can '
                              'send it to the customer.',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Generate a new password',
                            icon: const Icon(Icons.autorenew),
                            onPressed: enabled && _createdUid == null
                                ? () => setState(() => _passwordController
                                    .text = _generatePassword())
                                : null,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < _minPasswordLength)
                                ? 'Use at least $_minPasswordLength characters'
                                : null,
                      ),
                    ],
                    _sectionTitle('Address'),
                    TextFormField(
                      controller: _societyController,
                      enabled: enabled,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Society / Colony',
                        prefixIcon: Icon(Icons.apartment_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the society or colony name'
                          : null,
                    ),
                    _gap(),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _blockController,
                            enabled: enabled,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Block',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _floorController,
                            enabled: enabled,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Floor',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _gap(),
                    TextFormField(
                      controller: _flatController,
                      enabled: enabled,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Flat / House number',
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the flat or house number'
                          : null,
                    ),
                    _gap(),
                    TextFormField(
                      controller: _landmarkController,
                      enabled: enabled,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Landmark (optional)',
                        prefixIcon: Icon(Icons.flag_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    _gap(),
                    TextFormField(
                      controller: _addressController,
                      enabled: enabled,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Final address',
                        helperText: 'Auto-built from the fields above — '
                            'edit if needed.',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Auto-fill from address fields',
                          icon: const Icon(Icons.auto_fix_high),
                          onPressed: enabled ? _autoFillAddress : null,
                        ),
                      ),
                    ),
                    _sectionTitle('Milk subscription'),
                    for (final type in MilkType.values) _milkSection(type),
                    if (_loadingExisting)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (_error != null) ...[
                      _gap(),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: (_loading || _loadingExisting || _loadFailed)
                          ? null
                          : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isEdit ? 'Save changes' : 'Create customer'),
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
