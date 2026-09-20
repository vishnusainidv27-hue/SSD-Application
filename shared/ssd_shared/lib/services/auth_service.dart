import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Wraps Firebase Authentication for all three apps.
/// Built in Phase 1 – Foundation & Login.
///
/// FINALIZED LOGIN APPROACH (see Requirements §2 and Development Plan Phase 1):
/// Every screen only ever asks the user for a MOBILE NUMBER and a PASSWORD set
/// by Admin — no OTP, no visible email field. Underneath, this is implemented
/// with Firebase Authentication's standard email/password sign-in: each mobile
/// number is mapped to a fixed-format internal address (mobileToAuthEmail),
/// purely so Firebase Auth has somewhere to store it. This keeps everything
/// client-side and free (Spark plan) — no Cloud Functions / Blaze required.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _authOverride = auth,
        _firestoreOverride = firestore;

  static const String _emailDomain = 'ssdfarm.app';
  static const String _usersCollection = 'users';
  static const int _mobileDigits = 10;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  // Resolved lazily so constructing an AuthService never requires Firebase to
  // be initialised yet.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Normalizes a mobile number to its last 10 digits: all non-digits are
  /// stripped, so '+91 98765-43210' and '9876543210' both give '9876543210'.
  /// Throws [ArgumentError] if there are fewer than 10 digits.
  static String normalizeMobile(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _mobileDigits) {
      throw ArgumentError.value(
          mobile, 'mobile', 'Must contain at least $_mobileDigits digits');
    }
    return digits.substring(digits.length - _mobileDigits);
  }

  /// Converts a mobile number to the internal Firebase Auth email, e.g.
  /// '+91 98765-43210' -> '9876543210@ssdfarm.app' (see [normalizeMobile]).
  static String mobileToAuthEmail(String mobile) =>
      '${normalizeMobile(mobile)}@$_emailDomain';

  /// Signs in with mobile number + password.
  Future<UserCredential> signIn({
    required String mobile,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: mobileToAuthEmail(mobile),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<Map<String, dynamic>?> _currentUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    return doc.data();
  }

  /// Reads `role` from `users/{uid}` for the signed-in user. Returns null when
  /// nobody is signed in, the profile document / role field is missing, or the
  /// account is deactivated (`active` is explicitly false). Use
  /// [isCurrentUserDeactivated] to tell the last case apart.
  Future<String?> currentUserRole() async {
    final data = await _currentUserData();
    if (data == null || data['active'] == false) return null;
    return data['role'] as String?;
  }

  /// True when the signed-in user's profile has `active == false`.
  Future<bool> isCurrentUserDeactivated() async {
    final data = await _currentUserData();
    return data?['active'] == false;
  }

  /// Admin-only. Creates a Firebase Auth account for [mobile] and its
  /// `users/{uid}` profile without disturbing the Admin's own session.
  ///
  /// The Auth user is created on a temporary secondary [FirebaseApp] (creating
  /// it on the default app would sign the Admin out and sign the new user in).
  /// The profile is written through the main app's Firestore so it is
  /// authorised as the Admin.
  ///
  /// Returns the new user's uid.
  Future<String> createUserAccount({
    required String mobile,
    required String password,
    required String name,
    required String role,
  }) async {
    final normalizedMobile = normalizeMobile(mobile);
    final email = mobileToAuthEmail(normalizedMobile);
    return _withTempAuth((tempAuth) async {
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      try {
        await _firestore.collection(_usersCollection).doc(user.uid).set({
          'name': name,
          'mobile': normalizedMobile,
          'role': role,
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Don't leave an Auth account with no profile behind (the temp
        // instance is signed in as that new user, so it may delete it).
        try {
          await user.delete();
        } catch (_) {}
        rethrow;
      }
      return user.uid;
    });
  }

  /// Changes a user's password by signing in as them on a temporary secondary
  /// [FirebaseApp], so the currently signed-in session is left untouched.
  Future<void> changeUserPassword({
    required String mobile,
    required String oldPassword,
    required String newPassword,
  }) {
    final email = mobileToAuthEmail(mobile);
    return _withTempAuth((tempAuth) async {
      final credential = await tempAuth.signInWithEmailAndPassword(
        email: email,
        password: oldPassword,
      );
      await credential.user!.updatePassword(newPassword);
    });
  }

  /// Runs [action] against a FirebaseAuth bound to a throwaway FirebaseApp,
  /// always signing out and deleting that app afterwards.
  Future<T> _withTempAuth<T>(
      Future<T> Function(FirebaseAuth auth) action) async {
    final tempApp = await Firebase.initializeApp(
      name: 'temp-auth-${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
    try {
      return await action(tempAuth);
    } finally {
      try {
        await tempAuth.signOut();
      } catch (_) {}
      await tempApp.delete();
    }
  }
}
