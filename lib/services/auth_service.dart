import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'id_generator_service.dart';
import 'wallet_service.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final IdGeneratorService _idGeneratorService = IdGeneratorService();
  final WalletService _walletService = WalletService();


  // Stream of auth state/profile changes
  Stream<User?> get user => _auth.userChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        try {
          await _syncUserDocument(credential.user!);
        } catch (_) {
          // Non-blocking — user is still authenticated even if sync fails.
        }
      }
      return credential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Common helper to check for network/connectivity issues
  bool isNetworkError(dynamic e) {
    if (e is FirebaseAuthException) {
      return e.code == 'network-request-failed' || e.code == 'unavailable';
    }
    if (e.toString().contains('network_error') || e.toString().contains('unavailable')) {
      return true;
    }
    return false;
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String location,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document with role and extra details
      if (credential.user != null) {
        final customId = await _idGeneratorService.generateId('users');
        
        await FirebaseFirestore.instance.collection('users').doc(customId).set({
          'uid': credential.user!.uid, // Store the random UID as a field
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'phoneNumber': phoneNumber,
          'location': location,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        
        // Also update the local FirebaseAuth user profile with the display name
        await credential.user!.updateDisplayName('$firstName $lastName'.trim());

        // Ensure wallet document exists in 'wallets' collection
        await _walletService.createWalletForUser(credential.user!.uid);
      }
      
      return credential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // Hardcoded list of users who should have the 'owner' role
  static const List<String> _primaryOwners = [
    'owner_account@gmail.com',
    'owner_account2@test.com',
  ];

  // Private helper to ensure user doc exists with basics
  Future<void> _syncUserDocument(User user) async {
    final String intendedRole = _primaryOwners.contains(user.email) ? 'owner' : 'user';

    var query = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    // Fallback: try email if UID query returns nothing (handles legacy users)
    if (query.docs.isEmpty && user.email != null) {
      query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
    }

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final existingRole = data['role'];

      final Map<String, dynamic> updates = {'lastSeen': FieldValue.serverTimestamp()};
      if (data['uid'] == null) updates['uid'] = user.uid;
      // Never downgrade a manually-elevated 'owner' back to 'user'.
      // Only update role if: promoting to owner, OR the user isn't already an owner.
      if (existingRole != intendedRole && !(existingRole == 'owner' && intendedRole == 'user')) {
        updates['role'] = intendedRole;
      }

      await doc.reference.update(updates);
      // Mirror role to /roles/{authUID} for use in Firestore security rules.
      await _syncRoleMirror(user.uid, intendedRole);
    } else {
      // 3. Document truly doesn't exist, create it
      final customId = await _idGeneratorService.generateId('users');
      await FirebaseFirestore.instance.collection('users').doc(customId).set({
        'uid': user.uid,
        'email': user.email,
        'lastSeen': FieldValue.serverTimestamp(),
        'role': intendedRole,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror role to /roles/{authUID} for use in Firestore security rules.
      await _syncRoleMirror(user.uid, intendedRole);

      // Ensure wallet document exists in 'wallets' collection
      await _walletService.createWalletForUser(user.uid);
    }
  }

  /// Writes a small mirror document at /roles/{authUID} so that Firestore
  /// security rules can check the user role without a collection query.
  Future<void> _syncRoleMirror(String uid, String role) async {
    await FirebaseFirestore.instance.collection('roles').doc(uid).set(
      {'role': role, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: ${e.toString()}');
      return null;
    }
  }
}
