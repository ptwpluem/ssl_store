import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/app_logger.dart';

// ค้นหา User ID เพื่อให้แอปรู้ว่า "คนที่ login อยู่ตอนนี้ คือ document ไหนใน Firestore" แล้วจึงดึงข้อมูลของคนนั้นได้ถูกต้อง

// [firestore] and [auth] are injectable for testing; both default to the live
// instances, so existing callers (`getUserDocRef(uid)`) are unaffected.
Future<DocumentReference> getUserDocRef(
  String uid, {
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;
  final authInstance = auth ?? FirebaseAuth.instance;

  // ค้นหาด้วย uid field ก่อน
  int retryCount = 0;
  const maxRetries = 3;

  while (retryCount < maxRetries) {
    // 1. Primary check: search by the 'uid' field
    final query = await db
        .collection('users')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) return query.docs.first.reference;

    // 2. Fallback: email search ONLY when looking up the current user's own UID.
    //    Never use the current user's email to resolve a different user's UID —
    //    that would silently return the wrong document for cross-user operations
    //    such as repair functions that iterate all transactions.
    final currentUser = authInstance.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      final email = currentUser.email;
      if (email != null) {
        final emailQuery = await db
            .collection(
              'users',
            ) // ใช้ sequcnetual id เช่น CST-0001 และไม่ใช้ row_id เพราะอ่านง่ายกว่า
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          final ref = emailQuery.docs.first.reference;
          // self-healing ถ้าเจอ user ที่ไม่มี uid (user เก่า) ระบบจะเติม uid ให้อัตโนมัติ ทำให้หาเจอเร็วขึ้นในครั้งต่อไป
          try {
            await ref.update({'uid': uid});
          } catch (e, s) {
            // Non-blocking repair — log so a persistent failure is visible.
            AppLogger.debug('uid self-heal write failed',
                error: e, stackTrace: s);
          }
          return ref;
        }
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
