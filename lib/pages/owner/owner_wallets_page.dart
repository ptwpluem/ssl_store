// lib/pages/owner/owner_wallets_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OwnerWalletsPage extends StatelessWidget {
  const OwnerWalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ยอดเงินวอลเล็ตลูกค้า')),
      body: FutureBuilder<Map<String, Map<String, dynamic>>>(
        // Pre-load all user documents once and build a uid → user-data map.
        // Users are stored at /users/{seqId} with a 'uid' field (Firebase Auth UID).
        future: FirebaseFirestore.instance
            .collection('users')
            .get()
            .then((snap) {
          final Map<String, Map<String, dynamic>> map = {};
          for (final doc in snap.docs) {
            final data = doc.data();
            final uid = data['uid'] as String?;
            if (uid != null) map[uid] = data;
          }
          return map;
        }),
        builder: (context, userSnap) {
          // Show spinner while loading user map — typically very fast.
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final userMap = userSnap.data ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('wallets')
                .orderBy('balance', descending: true)
                .snapshots(),
            builder: (context, walletSnap) {
              if (walletSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = walletSnap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('ไม่พบกระเป๋าเงินวอลเล็ต'));
              }

              // Aggregate total balance for summary bar
              double totalBalance = 0;
              for (final doc in docs) {
                totalBalance +=
                    ((doc.data() as Map<String, dynamic>)['balance'] as num?)
                        ?.toDouble() ??
                        0.0;
              }

              return Column(
                children: [
                  _SummaryBar(
                    totalBalance: totalBalance,
                    walletCount: docs.length,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final uid =
                            data['userId'] as String? ?? '';
                        final balance =
                            (data['balance'] as num?)?.toDouble() ??
                                0.0;
                        final updatedAt =
                            (data['updatedAt'] as Timestamp?)?.toDate();

                        // Join with user data
                        final userData = userMap[uid];
                        final firstName =
                            userData?['firstName'] as String? ?? '';
                        final lastName =
                            userData?['lastName'] as String? ?? '';
                        final email =
                            userData?['email'] as String? ?? '';
                        final fullName =
                            (firstName.isNotEmpty || lastName.isNotEmpty)
                                ? '$firstName $lastName'.trim()
                                : null;

                        return _WalletCard(
                          uid: uid,
                          fullName: fullName,
                          email: email,
                          balance: balance,
                          updatedAt: updatedAt,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double totalBalance;
  final int walletCount;

  const _SummaryBar(
      {required this.totalBalance, required this.walletCount});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Container(
      color: const Color(0xFF6A1B9A).withValues(alpha: 0.07),
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จำนวนลูกค้า',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
                Text('$walletCount วอลเล็ต',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800])),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('ยอดเงินรวมทั้งหมด',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600])),
                Text(
                  '฿${fmt.format(totalBalance)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wallet card ─────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final String uid;
  final String? fullName;
  final String email;
  final double balance;
  final DateTime? updatedAt;

  const _WalletCard({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.balance,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    final displayName =
        fullName ?? (email.isNotEmpty ? email : 'UID: ${uid.substring(0, 8)}...');
    final hasName = fullName != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with initials
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  const Color(0xFF6A1B9A).withValues(alpha: 0.12),
              child: Text(
                _initials(fullName, email),
                style: const TextStyle(
                  color: Color(0xFF6A1B9A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasName
                          ? Colors.black87
                          : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasName && email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (updatedAt != null)
                    Text(
                      'อัปเดต: ${dateFmt.format(updatedAt!)}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),

            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${fmt.format(balance)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: balance > 0
                        ? const Color(0xFF6A1B9A)
                        : Colors.grey[400],
                  ),
                ),
                Text(
                  'ยอดคงเหลือ',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String? name, String email) {
    if (name != null && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }
}
