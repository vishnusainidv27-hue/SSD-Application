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
  // TODO (Phase 1): mobileToAuthEmail(String mobile) -> '$mobile@ssdfarm.app'

  // TODO (Phase 1): signIn(String mobile, String password)
  //   -> FirebaseAuth.instance.signInWithEmailAndPassword(
  //        email: mobileToAuthEmail(mobile), password: password)

  // TODO (Phase 1): createUserAccount(String mobile, String password, String name, String role)
  //   Admin-only. Must NOT disturb the Admin's own signed-in session, so:
  //   1. Create a second, temporary FirebaseApp instance (e.g. Firebase.initializeApp(
  //      name: 'temp-create-user', options: Firebase.app().options)).
  //   2. On that temporary instance's FirebaseAuth, call createUserWithEmailAndPassword
  //      with mobileToAuthEmail(mobile) and the given password.
  //   3. Using the MAIN app's Firestore instance, write {uid, name, mobile, role}
  //      to the `users` collection.
  //   4. Sign out and delete the temporary FirebaseApp instance.
  //   Result: Admin stays logged in throughout; the new user can now sign in
  //   from their own device with just their mobile number + that password.

  // TODO (Phase 1+): changeUserPassword(String mobile, String oldPassword, String newPassword)
  //   Same secondary-instance pattern: sign in as the user on the temp instance
  //   with oldPassword, call updatePassword(newPassword), sign out, dispose.

  // TODO (Phase 1): signOut(), currentUserRole() -> reads `users/{uid}.role` from Firestore.
}
