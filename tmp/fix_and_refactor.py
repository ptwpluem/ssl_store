import os

file_path = "lib/services/mock_service.dart"
with open(file_path, "r") as f:
    content = f.read()

# --- 1. Syntax Fixes ---

replacements = [
    # GoldRate
    (
        '''            return GoldRate(
              buyPrice: 40000.0,
              sellPrice: 40100.0,
              timestamp: now,
                  }''',
        '''            return GoldRate(
              buyPrice: 40000.0,
              sellPrice: 40100.0,
              timestamp: now,
              trend: 'stable',
            );
          }'''
    ),
    # addFunds notification
    (
        '''    await _walletService.performTransaction(
      walletId: walletId,
      amount: amount,
      type: WalletTransactionType.deposit,
      description: 'Wallet Top-Up',


    // Add a notification
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final formatter = NumberFormat('#,##0.00');
      isRead: false,
    );
    await notifRef.set(notif.toMap());''',
        '''    await _walletService.performTransaction(
      walletId: walletId,
      amount: amount,
      type: WalletTransactionType.deposit,
      description: 'Wallet Top-Up',
    );

    // Add a notification
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final formatter = NumberFormat('#,##0.00');
    final notif = NotificationItem(
      id: notifId,
      title: 'Deposit Successful',
      message: 'Successfully topped up ฿${formatter.format(amount)} to your wallet.',
      type: 'store',
      timestamp: DateTime.now(),
      isRead: false,
    );
    await notifRef.set(notif.toMap());'''
    ),
    # withdrawFunds notification
    (
        '''    await _walletService.performTransaction(
      walletId: walletId,
      amount: amount,
      type: WalletTransactionType.withdrawal,
      description: 'Wallet Withdrawal',


    // Add a notification
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final formatter = NumberFormat('#,##0.00');
      isRead: false,
    );
    await notifRef.set(notif.toMap());''',
        '''    await _walletService.performTransaction(
      walletId: walletId,
      amount: amount,
      type: WalletTransactionType.withdrawal,
      description: 'Wallet Withdrawal',
    );

    // Add a notification
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final formatter = NumberFormat('#,##0.00');
    final notif = NotificationItem(
      id: notifId,
      title: 'Withdrawal Successful',
      message: 'Successfully withdrawn ฿${formatter.format(amount)} from your wallet.',
      type: 'store',
      timestamp: DateTime.now(),
      isRead: false,
    );
    await notifRef.set(notif.toMap());'''
    ),
    # purity
    (
        '''            purity: (data['purity'] ?? 0.965 as num).toDouble(),
              }).toList();''',
        '''            purity: (data['purity'] ?? 0.965 as num).toDouble(),
          );
        }).toList();'''
    ),
    # collectionFuture
    (
        '''    final collectionFuture = userRefFuture.then(
      (ref) => ref.collection('notifications'),''',
        '''    final collectionFuture = userRefFuture.then(
      (ref) => ref.collection('notifications'),
    );'''
    ),
    # id
    (
        '''    final id = await _idGeneratorService.generateId(
      'transactions',
      prefixOverride: prefix,
    String displayName = 'Unknown User';''',
        '''    final id = await _idGeneratorService.generateId(
      'transactions',
      prefixOverride: prefix,
    );
    String displayName = 'Unknown User';'''
    ),
    # rateDoc
    (
        '''        final rateDoc = await transaction.get(
          FirebaseFirestore.instance.collection('market').doc('gold_rate'),
            final sellRate =''',
        '''        final rateDoc = await transaction.get(
          FirebaseFirestore.instance.collection('market').doc('gold_rate'),
        );
        final sellRate ='''
    ),
    # productDoc
    (
        '''            productDoc = await transaction.get(
              FirebaseFirestore.instance.collection('products').doc(productId),
                    // If product doesn't exist, we just skip stock deduction rather than failing (for demo resilience)
            if (productDoc.exists) {''',
        '''            productDoc = await transaction.get(
              FirebaseFirestore.instance.collection('products').doc(productId),
            );
            if (productDoc.exists) {'''
    ),
    # performTransactionWithTx
    (
        '''          await _walletService.performTransactionWithTx(
            transaction: transaction,
            walletId: walletQuery.docs.first.id,
            amount: amount,
            type: WalletTransactionType.purchase,
            description: 'Purchase: $assetName',''',
        '''          await _walletService.performTransactionWithTx(
            transaction: transaction,
            walletId: walletQuery.docs.first.id,
            amount: amount,
            type: WalletTransactionType.purchase,
            description: 'Purchase: $assetName',
          );'''
    ),
    # duplicate notif in redeemAsset
    (
        '''        // 3. Add a notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Asset Redeemed',
          message:
              'Successfully redeemed ${asset.name}. Total paid: ฿${formatter.format(totalOwed)}.',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        );
        transaction.set(notifRef, notif.toMap());
      });

        // 5. Add a notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Asset Redeemed',
          message:
              'Successfully redeemed ${asset.name}. Total paid: ฿${formatter.format(totalOwed)}.',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
            transaction.set(notifRef, notif.toMap());
      });''',
        '''        // 3. Add a notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Asset Redeemed',
          message:
              'Successfully redeemed ${asset.name}. Total paid: ฿${formatter.format(totalOwed)}.',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        );
        transaction.set(notifRef, notif.toMap());
      });'''
    ),
    # completeAppointment
    (
        '''      final notif = NotificationItem(
        id: notifId,
        title: 'Pickup Successful',
        message:
            'You have successfully picked up your $assetName from the store.',
        type: 'appointment',
        timestamp: DateTime.now(),
        isRead: false,
        transaction.set(notifRef, notif.toMap());
    });''',
        '''      final notif = NotificationItem(
        id: notifId,
        title: 'Pickup Successful',
        message:
            'You have successfully picked up your $assetName from the store.',
        type: 'appointment',
        timestamp: DateTime.now(),
        isRead: false,
      );
      transaction.set(notifRef, notif.toMap());
    });'''
    ),
    # category
    (
        '''          category: data['category'] ?? 'General',
          }).toList();''',
        '''          category: data['category'] ?? 'General',
        );
      }).toList();'''
    ),
    # GoldSavingsAccount 1
    (
        '''        GoldSavingsAccount(
          totalWeightSaved: 0.0,
          totalAmountInvested: 0.0,
          lastUpdated: DateTime.now(),
        ),
      }''',
        '''        GoldSavingsAccount(
          totalWeightSaved: 0.0,
          totalAmountInvested: 0.0,
          lastUpdated: DateTime.now(),
        ),
      );
    }'''
    ),
    # GoldSavingsAccount 2
    (
        '''          return GoldSavingsAccount(
            totalWeightSaved: 0.0,
            totalAmountInvested: 0.0,
            lastUpdated: DateTime.now(),
              }''',
        '''          return GoldSavingsAccount(
            totalWeightSaved: 0.0,
            totalAmountInvested: 0.0,
            lastUpdated: DateTime.now(),
          );
        }'''
    )
]

for old, new in replacements:
    content = content.replace(old, new)


# --- 2. Refactoring ---

helpers = """
  // --- Private Helpers for Redundancy Reduction ---
  static final NumberFormat _currencyFormatter = NumberFormat('#,##0.00');

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
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
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
  // ------------------------------------------------
"""

content = content.replace(
    "  // Helper to find the sequential user document by Auth UID",
    helpers + "\n  // Helper to find the sequential user document by Auth UID"
)

# UID Replacements
uid_pattern = '''    final uid = currentUserId;\n    if (uid == null) throw Exception('User not logged in');'''
content = content.replace(uid_pattern, '''    final uid = _requireUserId();''')

# Replace wallet queries carefully! Check exact strings
wallet_query_1 = '''    final walletQuery = await FirebaseFirestore.instance
        .collection('wallets')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();
    if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');
    final walletId = walletQuery.docs.first.id;'''
content = content.replace(wallet_query_1, '''    final walletId = await _getUserWalletId(uid);''')

wallet_query_2 = '''        final walletQuery = await FirebaseFirestore.instance
            .collection('wallets')
            .where('userId', isEqualTo: uid)
            .limit(1)
            .get();
        if (walletQuery.docs.isEmpty) throw Exception('Wallet not found');'''
content = content.replace(wallet_query_2, '''        final walletId = await _getUserWalletId(uid);''')

wallet_query_3 = '''          final walletQuery = await FirebaseFirestore.instance
              .collection('wallets')
              .where('userId', isEqualTo: uid)
              .limit(1)
              .get();
          if (walletQuery.docs.isEmpty)
            throw Exception('Wallet not found. Please top up first.');'''
content = content.replace(wallet_query_3, '''          final walletId = await _getUserWalletId(uid);''')

wallet_query_4 = '''          walletId: walletQuery.docs.first.id,'''
content = content.replace(wallet_query_4, '''          walletId: walletId,''')

# Notification replacements
notifs_blocks = [
    (
        '''    // Add a notification
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final formatter = NumberFormat('#,##0.00');
    final notif = NotificationItem(
      id: notifId,
      title: 'Deposit Successful',
      message: 'Successfully topped up ฿${formatter.format(amount)} to your wallet.',
      type: 'store',
      timestamp: DateTime.now(),
      isRead: false,
    );
    await notifRef.set(notif.toMap());''',
        '''    await _createNotification(
      uid: uid,
      title: 'Deposit Successful',
      message: 'Successfully topped up ฿${_currencyFormatter.format(amount)} to your wallet.',
      type: 'store',
    );'''
    ),
    (
        '''    // Add a notification
    final notifId = DateTime.now().millisecondsSinceEpoch.toString();
    final userRef = await _getUserDocRef(uid);
    final notifRef = userRef.collection('notifications').doc('n_$notifId');
    final formatter = NumberFormat('#,##0.00');
    final notif = NotificationItem(
      id: notifId,
      title: 'Withdrawal Successful',
      message: 'Successfully withdrawn ฿${formatter.format(amount)} from your wallet.',
      type: 'store',
      timestamp: DateTime.now(),
      isRead: false,
    );
    await notifRef.set(notif.toMap());''',
        '''    await _createNotification(
      uid: uid,
      title: 'Withdrawal Successful',
      message: 'Successfully withdrawn ฿${_currencyFormatter.format(amount)} from your wallet.',
      type: 'store',
    );'''
    ),
    (
        '''        // 7. Add Notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final userRef = await _getUserDocRef(uid);
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Transaction Successful',
          message:
              'Successfully completed ${type.name} for $assetName (${weight.toStringAsFixed(2)} Baht).',
          type: type == TransactionType.buy ? 'store' : 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        );
        transaction.set(notifRef, notif.toMap());''',
        '''        await _createNotification(
          uid: uid,
          title: 'Transaction Successful',
          message: 'Successfully completed ${type.name} for $assetName (${weight.toStringAsFixed(2)} Baht).',
          type: type == TransactionType.buy ? 'store' : 'pawn',
          transaction: transaction,
        );'''
    ),
    (
        '''        // 4. Add a notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Asset Sold',
          message:
              'Successfully sold ${asset.name} for ฿${formatter.format(sellPrice)}.',
          type: 'store',
          timestamp: DateTime.now(),
          isRead: false,
        );
        transaction.set(notifRef, notif.toMap());''',
        '''        await _createNotification(
          uid: uid,
          title: 'Asset Sold',
          message: 'Successfully sold ${asset.name} for ฿${_currencyFormatter.format(sellPrice)}.',
          type: 'store',
          transaction: transaction,
        );'''
    ),
    (
        '''        // 4. Add a notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Pawn Successful',
          message:
              'Successfully pawned ${asset.name} for a loan of ฿${formatter.format(loanAmount)}.',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        );
        transaction.set(notifRef, notif.toMap());''',
        '''        await _createNotification(
          uid: uid,
          title: 'Pawn Successful',
          message: 'Successfully pawned ${asset.name} for a loan of ฿${_currencyFormatter.format(loanAmount)}.',
          type: 'pawn',
          transaction: transaction,
        );'''
    ),
    (
        '''        // 3. Add a notification
        final notifId = DateTime.now().millisecondsSinceEpoch.toString();
        final notifRef = userRef.collection('notifications').doc('n_$notifId');
        final formatter = NumberFormat('#,##0.00');
        final notif = NotificationItem(
          id: notifId,
          title: 'Asset Redeemed',
          message:
              'Successfully redeemed ${asset.name}. Total paid: ฿${formatter.format(totalOwed)}.',
          type: 'pawn',
          timestamp: DateTime.now(),
          isRead: false,
        );
        transaction.set(notifRef, notif.toMap());
      });''',
        '''        await _createNotification(
          uid: uid,
          title: 'Asset Redeemed',
          message: 'Successfully redeemed ${asset.name}. Total paid: ฿${_currencyFormatter.format(totalOwed)}.',
          type: 'pawn',
          transaction: transaction,
        );
      });'''
    ),
    (
        '''      // 3. Send Notification to User
      final notifId = DateTime.now().millisecondsSinceEpoch.toString();
      final notifRef = userRef.collection('notifications').doc('n_$notifId');
      final notif = NotificationItem(
        id: notifId,
        title: 'Pickup Successful',
        message:
            'You have successfully picked up your $assetName from the store.',
        type: 'appointment',
        timestamp: DateTime.now(),
        isRead: false,
      );
      transaction.set(notifRef, notif.toMap());''',
        '''      await _createNotification(
        uid: userId, // Here we use userId parameter instead of currentUserId
        title: 'Pickup Successful',
        message: 'You have successfully picked up your $assetName from the store.',
        type: 'appointment',
        transaction: transaction,
      );'''
    ),
    (
        '''      // 5. Add a notification
      final formatter = NumberFormat('#,##0.00');
      final notifId = DateTime.now().millisecondsSinceEpoch.toString();
      final notifRef = userRef.collection('notifications').doc('n_$notifId');
      final notif = NotificationItem(
        id: notifId,
        title: 'Gold Savings Deposit',
        message:
            'Successfully deposited ฿${formatter.format(amountInTHB)} toward your Gold Savings. Gained ${weightGained.toStringAsFixed(4)} Baht.',
        type: 'savings',
        timestamp: DateTime.now(),
        isRead: false,
      );
      transaction.set(notifRef, notif.toMap());''',
        '''      await _createNotification(
        uid: uid,
        title: 'Gold Savings Deposit',
        message: 'Successfully deposited ฿${_currencyFormatter.format(amountInTHB)} toward your Gold Savings. Gained ${weightGained.toStringAsFixed(4)} Baht.',
        type: 'savings',
        transaction: transaction,
      );'''
    ),
    (
        '''      // 6. Add a notification
      final formatter = NumberFormat('#,##0.00');
      final notifId = DateTime.now().millisecondsSinceEpoch.toString();
      final notifRef = userRef.collection('notifications').doc('n_$notifId');
      final notif = NotificationItem(
        id: notifId,
        title: 'Gold Savings Sold',
        message:
            'Successfully sold ${weightToSell.toStringAsFixed(4)} Baht of saved gold. You received ฿${formatter.format(amountInTHB)} back into your wallet.',
        type: 'savings',
        timestamp: DateTime.now(),
        isRead: false,
      );
      transaction.set(notifRef, notif.toMap());''',
        '''      await _createNotification(
        uid: uid,
        title: 'Gold Savings Sold',
        message: 'Successfully sold ${weightToSell.toStringAsFixed(4)} Baht of saved gold. You received ฿${_currencyFormatter.format(amountInTHB)} back into your wallet.',
        type: 'savings',
        transaction: transaction,
      );'''
    )
]

for old, new in notifs_blocks:
    if old in content:
        content = content.replace(old, new)
    else:
        print("Warning: Could not find block:")
        print(old)

with open(file_path, "w") as f:
    f.write(content)
