// lib/pages/owner/owner_savings_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Owner view of all customer gold savings accounts.
///
/// From the shop's perspective every gram of gold a customer has saved is a
/// LIABILITY — the shop owes that gold (or its cash equivalent) back to the
/// customer on demand.
///
/// Key metrics shown:
///   • ภาระผูกพัน (liability) = totalWeightSaved × current sell price
///   • เงินที่รับมา (received)  = totalAmountInvested  (what customer deposited)
///   • ส่วนต่าง (gap)           = liability − received  (how much more shop owes
///                               vs. what it received — driven by price movement)
class OwnerSavingsPage extends StatelessWidget {
  const OwnerSavingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีออมทองลูกค้า')),
      body: StreamBuilder<DocumentSnapshot>(
        // Live market rate so liability updates as gold price moves
        stream: FirebaseFirestore.instance
            .collection('market')
            .doc('gold_rate')
            .snapshots(),
        builder: (context, rateSnap) {
          final rateData =
              rateSnap.data?.data() as Map<String, dynamic>?;
          final sellPrice =
              (rateData?['sellPrice'] as num?)?.toDouble() ?? 40000.0;

          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            // Pre-load all user documents once → build seqId → userData map.
            // Savings accounts live at users/{seqId}/savings/account, so
            // doc.reference.parent.parent?.id gives us the sequential doc ID.
            future: FirebaseFirestore.instance
                .collection('users')
                .get()
                .then((snap) {
              final Map<String, Map<String, dynamic>> map = {};
              for (final doc in snap.docs) {
                map[doc.id] = doc.data();
              }
              return map;
            }),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final userMap = userSnap.data ?? {};

              return StreamBuilder<List<DocumentSnapshot>>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('savings')
                    .snapshots()
                    .map((snap) => snap.docs
                        .where((doc) =>
                            doc.id == 'account' &&
                            ((doc.data())['totalWeightSaved'] as num?)
                                    ?.toDouble() !=
                                0.0)
                        .toList()),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                        child: Text('ไม่พบบัญชีออมทองที่มียอดค้างอยู่'));
                  }

                  // Sort: highest liability first
                  final sorted = docs.toList()
                    ..sort((a, b) {
                      final wA = ((a.data() as Map<String, dynamic>)[
                                  'totalWeightSaved'] as num?)
                              ?.toDouble() ??
                          0.0;
                      final wB = ((b.data() as Map<String, dynamic>)[
                                  'totalWeightSaved'] as num?)
                              ?.toDouble() ??
                          0.0;
                      return wB.compareTo(wA);
                    });

                  // Grand totals for summary bar
                  double grandWeight = 0;
                  double grandReceived = 0;
                  for (final doc in sorted) {
                    final d = doc.data() as Map<String, dynamic>;
                    grandWeight +=
                        (d['totalWeightSaved'] as num?)?.toDouble() ??
                            0.0;
                    grandReceived +=
                        (d['totalAmountInvested'] as num?)?.toDouble() ??
                            0.0;
                  }
                  final grandLiability = grandWeight * sellPrice;
                  final grandGap = grandLiability - grandReceived;

                  return Column(
                    children: [
                      _SummaryBar(
                        count: sorted.length,
                        grandWeight: grandWeight,
                        grandLiability: grandLiability,
                        grandReceived: grandReceived,
                        grandGap: grandGap,
                        sellPrice: sellPrice,
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final doc = sorted[index];
                            final data =
                                doc.data() as Map<String, dynamic>;

                            // Extract sequential user doc ID from path
                            final seqId =
                                doc.reference.parent.parent?.id ?? '';
                            final userData = userMap[seqId];
                            final firstName = userData?['firstName']
                                    as String? ??
                                '';
                            final lastName =
                                userData?['lastName'] as String? ?? '';
                            final email =
                                userData?['email'] as String? ?? '';
                            final fullName =
                                (firstName.isNotEmpty || lastName.isNotEmpty)
                                    ? '$firstName $lastName'.trim()
                                    : null;

                            final totalWeight =
                                (data['totalWeightSaved'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                            final totalInvested =
                                (data['totalAmountInvested'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                            final lastUpdated =
                                (data['lastUpdated'] as Timestamp?)
                                    ?.toDate();
                            final liability = totalWeight * sellPrice;
                            final gap = liability - totalInvested;

                            return _SavingsAccountCard(
                              seqId: seqId,
                              fullName: fullName,
                              email: email,
                              totalWeight: totalWeight,
                              totalInvested: totalInvested,
                              liability: liability,
                              gap: gap,
                              lastUpdated: lastUpdated,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
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
  final int count;
  final double grandWeight;
  final double grandLiability;
  final double grandReceived;
  final double grandGap;
  final double sellPrice;

  const _SummaryBar({
    required this.count,
    required this.grandWeight,
    required this.grandLiability,
    required this.grandReceived,
    required this.grandGap,
    required this.sellPrice,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    final gapColor = grandGap >= 0 ? Colors.red[700]! : Colors.green[700]!;

    return Container(
      color: Colors.teal.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rate indicator
          Row(
            children: [
              Icon(Icons.show_chart, size: 13, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                'ราคาทองขาย: ฿${fmt.format(sellPrice)}/บาท  (ใช้คำนวณภาระผูกพัน)',
                style: TextStyle(fontSize: 11, color: Colors.amber[800]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Cell(
                label: 'บัญชีที่มียอด',
                value: '$count บัญชี',
                color: Colors.grey[700]!,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'ทองรวมที่ต้องคืน',
                value: '${grandWeight.toStringAsFixed(4)} บาท',
                color: Colors.teal[700]!,
                bold: true,
              ),
              const SizedBox(width: 8),
              _Cell(
                label: 'เงินที่รับมารวม',
                value: '฿${fmt.format(grandReceived)}',
                color: Colors.grey[700]!,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Cell(
                label: 'ภาระผูกพันรวม',
                value: '฿${fmt.format(grandLiability)}',
                color: Colors.teal[800]!,
                bold: true,
              ),
              const SizedBox(width: 8),
              _Cell(
                label:
                    'ส่วนต่าง (ราคาทองเปลี่ยน)',
                value:
                    '${grandGap >= 0 ? '+' : ''}฿${fmt.format(grandGap)}',
                color: gapColor,
                bold: true,
              ),
              const SizedBox(width: 8),
              // Spacer
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _Cell({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Per-account card ─────────────────────────────────────────────────────────

class _SavingsAccountCard extends StatelessWidget {
  final String seqId;
  final String? fullName;
  final String email;
  final double totalWeight;
  final double totalInvested;
  final double liability;
  final double gap;
  final DateTime? lastUpdated;

  const _SavingsAccountCard({
    required this.seqId,
    required this.fullName,
    required this.email,
    required this.totalWeight,
    required this.totalInvested,
    required this.liability,
    required this.gap,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    // gap > 0 means shop owes MORE than it received (price went up = shop's
    // liability grew). Show in red. Negative gap = price fell, shop's exposure
    // is less than what it received.
    final gapColor = gap > 0 ? Colors.red[700]! : Colors.green[700]!;
    final gapLabel = gap > 0 ? 'เพิ่มขึ้นจากราคา' : 'ลดลงจากราคา';

    final displayName = fullName ??
        (email.isNotEmpty ? email : 'UID: $seqId');
    final hasName = fullName != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + weight badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      Colors.teal.withValues(alpha: 0.12),
                  child: Text(
                    _initials(fullName, email),
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                              : Colors.grey[500],
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
                    ],
                  ),
                ),
                // Weight badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${totalWeight.toStringAsFixed(4)} บาท',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Financial breakdown
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _FinRow(
                    label: 'เงินที่ลูกค้าฝากมารวม',
                    value: '฿${fmt.format(totalInvested)}',
                    color: Colors.grey[700]!,
                  ),
                  const SizedBox(height: 6),
                  _FinRow(
                    label: 'ภาระผูกพัน (ณ ราคาปัจจุบัน)',
                    sublabel:
                        '${totalWeight.toStringAsFixed(4)} บาท × ฿${fmtShort.format(liability / (totalWeight > 0 ? totalWeight : 1))}',
                    value: '฿${fmt.format(liability)}',
                    color: Colors.teal[800]!,
                    bold: true,
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ส่วนต่างจากราคาทอง',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            gapLabel,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      Text(
                        '${gap >= 0 ? '+' : ''}฿${fmt.format(gap)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: gapColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (lastUpdated != null) ...[
              const SizedBox(height: 6),
              Text(
                'อัปเดตล่าสุด: ${dateFmt.format(lastUpdated!)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
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

class _FinRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final String value;
  final Color color;
  final bool bold;

  const _FinRow({
    required this.label,
    this.sublabel,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: Colors.grey[700],
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight:
                bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
