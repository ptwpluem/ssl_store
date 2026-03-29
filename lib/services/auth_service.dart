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
      print('DEBUG: Attempting sign in for $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Ensure user document exists in Firestore for console visibility
      if (credential.user != null) {
        try {
          await _syncUserDocument(credential.user!);
        } catch (e) {
          // Non-blocking sync error
          print('WARNING: Background user sync failed: $e. The user is still authenticated.');
        }
      }
      
      print('DEBUG: Sign in successful for ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      // CRITICAL: Log exact error code to help diagnose "Network Error"
      print('DEBUG: Firebase Auth Error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected sign in error: $e');
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
    } on FirebaseAuthException catch (e) {
      print('DEBUG: Firebase Register Error [${e.code}]: ${e.message}');
      rethrow;
    } catch (e) {
      print('DEBUG: Unexpected register error: $e');
      rethrow;
    }
  }

  // Hardcoded list of users who should have the 'owner' role
  static const List<String> _primaryOwners = [
    'owner_account@gmail.com',
  ];

  // Private helper to ensure user doc exists with basics
  Future<void> _syncUserDocument(User user) async {
    print('DEBUG: Syncing document for UID: ${user.uid}, Email: ${user.email}');
    
    // Determine the intended role
    final String intendedRole = _primaryOwners.contains(user.email) ? 'owner' : 'user';
    print('DEBUG: Intended role for ${user.email} is: $intendedRole');
    var query = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    // 2. Fallback: Try finding by email if UID fails (handles legacy users or missing UID fields)
    if (query.docs.isEmpty && user.email != null) {
      print('DEBUG: No doc found by UID, trying email fallback for ${user.email}');
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
      
      print('DEBUG: Found existing user document: ${doc.id}. Current role: $existingRole');

      Map<String, dynamic> updates = {
        'lastSeen': FieldValue.serverTimestamp(),
      };

      // Ensure UID is set if it was missing (e.g. found by email)
      if (data['uid'] == null) {
        updates['uid'] = user.uid;
      }

      // SELF-HEALING: If it's a primary owner and has the wrong role, fix it
      if (existingRole != intendedRole) {
        print('DEBUG: Role mismatch! Upgrading/Changing role for ${user.email} from $existingRole to $intendedRole');
        updates['role'] = intendedRole;
      }

      await doc.reference.update(updates);
      print('DEBUG: Updated user document ${doc.id}');
    } else {
      // 3. Document truly doesn't exist, create it
      print('DEBUG: No document found for ${user.email}. Creating new $intendedRole document.');
      final customId = await _idGeneratorService.generateId('users');
      await FirebaseFirestore.instance.collection('users').doc(customId).set({
        'uid': user.uid,
        'email': user.email,
        'lastSeen': FieldValue.serverTimestamp(),
        'role': intendedRole, 
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('DEBUG: Created new $intendedRole document: $customId');

      // Ensure wallet document exists in 'wallets' collection
      await _walletService.createWalletForUser(user.uid);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print('Sign out error: ${e.toString()}');
      return null;
    }
  }
}
