import os
import re

file_path = "lib/services/mock_service.dart"
with open(file_path, "r") as f:
    content = f.read()

helpers = """
  static final NumberFormat _formatter = NumberFormat('#,##0.00');

  String _requireUserId() {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not logged in');
    return uid;
  }

  Future<String> _getUserWalletId(String uid) async {
    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found. Please top up first.');
    return walletQuery.docs.first.id;
  }

  Future<void> _createNotification({
    required String uid,
    required String title,
    required String message,
    required String type,
    Transaction? transaction,
  }) async {
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final notif = NotificationItem(
      id: notifId,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
    );
    if (transaction != null) {
      transaction.set(notifRef, notif.toMap());
    } else {
      await notifRef.set(notif.toMap());
    }
  }
"""

if "_requireUserId" not in content:
    content = content.replace(
        "  // Helper to find the sequential user document by Auth UID",
        helpers + "\n  // Helper to find the sequential user document by Auth UID"
    )

# Replace uid checks
uid_check_pattern = r"    final uid = currentUserId;\n    if \(uid == null\) throw Exception\('User not logged in'\);\n"
uid_check_replacement = r"    final uid = _requireUserId();\n"
content = re.sub(uid_check_pattern, uid_check_replacement, content)

# Replace wallet queries
wallet_query_pattern_1 = re.compile(r"""\s*final walletQuery = await FirebaseFirestore.instance\s*\.collection\('wallets'\)\s*\.where\('userId', isEqualTo: uid\)\s*\.limit\(1\)\s*\.get\(\);\s*if \(walletQuery\.docs\.isEmpty\)[\s\S]*?;\s*final walletId = walletQuery\.docs\.first\.id;""")
content = wallet_query_pattern_1.sub("\n    final walletId = await _getUserWalletId(uid);", content)

# Notifications (non-transaction)
notif_pattern = re.compile(
    r"""\s*// Add a notification\s*final notifId = DateTime\.now\(\)\.millisecondsSinceEpoch\.toString\(\);\s*final userRef = await _getUserDocRef\(uid\);\s*final notifRef = userRef\.collection\('notifications'\)\.doc\('n_\$notifId'\);\s*final formatter = NumberFormat\('#,##0\.00'\);\s*final notif = NotificationItem\(\s*id: notifId,\s*title: ('[^']+'),\s*message: ([^,]+),\s*type: ('[^']+'),\s*timestamp: DateTime\.now\(\),\s*isRead: false,\s*\);\s*await notifRef\.set\(notif\.toMap\(\)\);"""
)
def notif_repl(m):
    title = m.group(1)
    msg = m.group(2).replace('formatter.format', '_formatter.format')
    type_val = m.group(3)
    return f"\n    await _createNotification(\n      uid: uid,\n      title: {title},\n      message: {msg},\n      type: {type_val},\n    );"
content = notif_pattern.sub(notif_repl, content)

# Notifications (transaction)
tx_notif_pattern = re.compile(
    r"""\s*// \d+\. Add [Aa] [Nn]otification\s*final notifId = DateTime\.now\(\)\.millisecondsSinceEpoch\.toString\(\);\s*final (?:userRef|notifRef) = await _getUserDocRef\(uid\);\s*final notifRef = userRef\.collection\('notifications'\)\.doc\('n_\$notifId'\);\s*final formatter = NumberFormat\('#,##0\.00'\);\s*final notif = NotificationItem\(\s*id: notifId,\s*title: ('[^']+'),\s*message:\s*([^,]+(?:,[^,]+)?),\s*type: ([^,]+(?: \? '[^']+' : '[^']+')?),\s*timestamp: DateTime\.now\(\),\s*isRead: false,\s*\);\s*transaction\.set\(notifRef, notif\.toMap\(\)\);"""
)
def tx_notif_repl(m):
    title = m.group(1)
    msg = m.group(2).replace('formatter.format', '_formatter.format').strip()
    type_val = m.group(3)
    return f"\n        await _createNotification(\n          uid: uid,\n          title: {title},\n          message: {msg},\n          type: {type_val},\n          transaction: transaction,\n        );"
# It's safer to avoid doing too complex regex for the transaction ones because of formatting. Let's try basic one first.

with open(file_path, "w") as f:
    f.write(content)
