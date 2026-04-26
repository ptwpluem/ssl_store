import os

file_path = "lib/services/mock_service.dart"
with open(file_path, "r") as f:
    content = f.read()

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

with open(file_path, "w") as f:
    f.write(content)

