import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves the Firestore user document reference for a given Firebase Auth UID.
/// Users are stored under /users/{sequentialId} with a 'uid' field that holds
/// the Firebase Auth UID, so we must query rather than address by key.
Future<DocumentReference> getUserDocRef(String uid) async {
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) return query.docs.first.reference;

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
