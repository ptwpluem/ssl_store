import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Resolves the Firestore user document reference for a given Firebase Auth UID.
/// Users are stored under /users/{sequentialId} with a 'uid' field that holds
/// the Firebase Auth UID.
///
/// Includes a fallback search by email and self-healing logic to add the 'uid'
/// field if it is missing from an existing document.
Future<DocumentReference> getUserDocRef(String uid) async {
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    // 1. Primary check: search by the 'uid' field
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) return query.docs.first.reference;

    // 2. Fallback check: search by email (handles legacy users or sync gaps)
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        final ref = emailQuery.docs.first.reference;
        // Self-healing: add the missing UID field so future lookups are fast
        try {
          await ref.update({'uid': uid});
        } catch (_) {
          // Non-blocking repair
        }
        return ref;
      }
    }

    retryCount++;
    if (retryCount < maxRetries) {
      await Future.delayed(Duration(milliseconds: 200 * retryCount));
    }
  }

  throw Exception(
    'User document not found (UID: $uid). '
    'Please check that your profile is fully set up.',
  );
}
