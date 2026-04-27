// lib/pages/owner/owner_pawns_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/pawn_service.dart';

class OwnerPawnsPage extends StatefulWidget {
  const OwnerPawnsPage({super.key});

  @override
  State<OwnerPawnsPage> createState() => _OwnerPawnsPageState();
}

class _OwnerPawnsPageState extends State<OwnerPawnsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PawnService _pawnService = PawnService();

  // Active-pawns status filter
  String _filter = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการรับจำนำ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'จำนำอยู่'),
            Tab(text: 'ไถ่ถอนแล้ว'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivePawnsTab(
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            pawnService: _pawnService,
          ),
          const _RedeemedPawnsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Active pawns (จำนำอยู่)
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivePawnsTab extends StatelessWidget {
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final PawnService pawnService;

  const _ActivePawnsTab({
    required this.filter,
    required this.onFilterChanged,
    required this.pawnService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: ['ทั้งหมด', 'เกินกำหนด', 'ใกล้ครบกำหนด'].map((f) {
              final isSelected = filter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (_) => onFilterChanged(f),
                  selectedColor: Colors.orange.withValues(alpha: 0.2),
                  checkmarkColor: Colors.orange,
                ),
              );
            }).toList(),
          ),
        ),

        // List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('assets')
                .where('status', isEqualTo: 'pawned')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final soonThreshold = today.add(const Duration(days: 7));

              List<Map<String, dynamic>> items = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                items = snapshot.data!.docs
                    .map((d) => d.data() as Map<String, dynamic>)
                    .toList();
              }

              if (items.isEmpty) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('type', isEqualTo: 'pawn')
                      .snapshots(),
                  builder: (ctx, txSnap) {
                    if (txSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!txSnap.hasData || txSnap.data!.docs.isEmpty) {
                      return const Center(
                          child: Text('ไม่พบรายการรับจำนำที่เปิดอยู่'));
                    }
                    items = txSnap.data!.docs.map((tx) {
                      final d = tx.data() as Map<String, dynamic>;
                      final ts = (d['timestamp'] as Timestamp?) ?? Timestamp.now();
                      return {
                        'name': d['details']?.toString().split(':').last.trim() ??
                            'Pawned Item',
                        'weight': (d['weight'] as num?)?.toDouble() ?? 0.0,
                        'loanAmount': (d['amount'] as num?)?.toDouble() ?? 0.0,
                        'pawnDate': ts,
                        'dueDate': Timestamp.fromDate(
                            ts.toDate().add(const Duration(days: 30))),
                        'interestRate': 0.0125,
                        'status': 'pawned',
                      };
                    }).toList();
                    return _buildActiveList(
                        context, items, now, today, soonThreshold);
                  },
                );
              }

              return _buildActiveList(
                  context, items, now, today, soonThreshold);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveList(
    BuildContext context,
    List<Map<String, dynamic>> items,
    DateTime now,
    DateTime today,
    DateTime soonThreshold,
  ) {
    // Apply status filter
    var filtered = items.where((data) {
      final dueDateRaw = data['dueDate'] as Timestamp?;
      if (filter == 'ทั้งหมด') return true;
      if (dueDateRaw == null) return false;
      final d = dueDateRaw.toDate();
      final dueDay = DateTime(d.year, d.month, d.day);
      final overdue = dueDay.isBefore(today);
      if (filter == 'เกินกำหนด') return overdue;
      if (filter == 'ใกล้ครบกำหนด') {
        return !overdue &&
            (dueDay.isBefore(soonThreshold) ||
                dueDay.isAtSameMomentAs(soonThreshold));
      }
      return true;
    }).toList();

    // Sort: overdue first, then by pawnDate descending
    filtered.sort((a, b) {
      final t1 = a['pawnDate'] as Timestamp?;
      final t2 = b['pawnDate'] as Timestamp?;
      return (t2 ?? Timestamp(0, 0)).compareTo(t1 ?? Timestamp(0, 0));
    });

    if (filtered.isEmpty) {
      return Center(child: Text('ไม่พบรายการในหมวด $filter'));
    }

    // Summary bar totals
    double totalPrincipal = 0, totalOwed = 0, totalInterest = 0;
    for (final data in filtered) {
      final principal = (data['loanAmount'] as num?)?.toDouble() ?? 0.0;
      final pawnDate = (data['pawnDate'] as Timestamp?)?.toDate();
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
      final rate = (data['interestRate'] as num?)?.toDouble() ?? 0.0125;
      totalPrincipal += principal;
      if (pawnDate != null && dueDate != null) {
        final calc = pawnService.calculatePawnOwed(
            principal, pawnDate, dueDate, rate);
        totalOwed += calc['totalOwed'] ?? principal;
        totalInterest += (calc['standardInterest'] ?? 0.0) +
            (calc['penaltyInterest'] ?? 0.0);
      } else {
        totalOwed += principal;
      }
    }

    return Column(
      children: [
        _ActiveSummaryBar(
          count: filtered.length,
          totalPrincipal: totalPrincipal,
          totalInterest: totalInterest,
          totalOwed: totalOwed,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final data = filtered[index];
              return _ActivePawnCard(
                data: data,
                now: now,
                today: today,
                soonThreshold: soonThreshold,
                pawnService: pawnService,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Active pawns summary bar ─────────────────────────────────────────────────

class _ActiveSummaryBar extends StatelessWidget {
  final int count;
  final double totalPrincipal;
  final double totalInterest;
  final double totalOwed;

  const _ActiveSummaryBar({
    required this.count,
    required this.totalPrincipal,
    required this.totalInterest,
    required this.totalOwed,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: Colors.orange.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SumCell('รายการ', '$count รายการ', Colors.grey[700]!),
          const SizedBox(width: 8),
          _SumCell('เงินกู้รวม', '฿${fmt.format(totalPrincipal)}', Colors.orange[800]!),
          const SizedBox(width: 8),
          _SumCell('ดอกเบี้ยรวม', '฿${fmt.format(totalInterest)}', Colors.deepOrange),
          const SizedBox(width: 8),
          _SumCell('ยอดค้างชำระรวม', '฿${fmt.format(totalOwed)}', Colors.red[700]!,
              bold: true),
        ],
      ),
    );
  }
}

class _SumCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _SumCell(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
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

// ─── Active pawn card ─────────────────────────────────────────────────────────

class _ActivePawnCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime now;
  final DateTime today;
  final DateTime soonThreshold;
  final PawnService pawnService;

  const _ActivePawnCard({
    required this.data,
    required this.now,
    required this.today,
    required this.soonThreshold,
    required this.pawnService,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy');

    final name = data['name'] as String? ?? 'ไม่ทราบชื่อ';
    final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
    final principal = (data['loanAmount'] as num?)?.toDouble() ?? 0.0;
    final pawnDate = (data['pawnDate'] as Timestamp?)?.toDate();
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    final rate = (data['interestRate'] as num?)?.toDouble() ?? 0.0125;
    final userId = data['userId'] as String?;

    // Determine status
    bool isOverdue = false;
    bool isDueSoon = false;
    if (dueDate != null) {
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      isOverdue = dueDay.isBefore(today);
      isDueSoon = !isOverdue &&
          (dueDay.isBefore(soonThreshold) ||
              dueDay.isAtSameMomentAs(soonThreshold));
    }

    Color statusColor = Colors.grey;
    String statusLabel = 'ปกติ';
    if (isOverdue) {
      statusColor = Colors.red;
      statusLabel = 'เกินกำหนด';
    } else if (isDueSoon) {
      statusColor = Colors.orange;
      statusLabel = 'ใกล้ครบกำหนด';
    }

    // Calculate interest
    Map<String, double> interest = {
      'standardInterest': 0.0,
      'penaltyInterest': 0.0,
      'totalOwed': principal,
    };
    if (pawnDate != null && dueDate != null) {
      interest = pawnService.calculatePawnOwed(principal, pawnDate, dueDate, rate);
    }
    final standardInterest = interest['standardInterest'] ?? 0.0;
    final penaltyInterest = interest['penaltyInterest'] ?? 0.0;
    final totalOwed = interest['totalOwed'] ?? principal;

    // Days pawned
    final daysPawned = pawnDate != null ? now.difference(pawnDate).inDays : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isOverdue ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.4),
          width: isOverdue ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(Icons.real_estate_agent,
                      color: statusColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (userId != null)
                        Text(userId,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor)),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Date and weight row
            Row(
              children: [
                _InfoChip(
                    icon: Icons.scale,
                    label: '${weight.toStringAsFixed(2)} บาท'),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.calendar_today,
                    label: pawnDate != null
                        ? 'วันที่จำนำ: ${dateFmt.format(pawnDate)}'
                        : '-'),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.event,
                    label: dueDate != null
                        ? 'ครบ: ${dateFmt.format(dueDate)}'
                        : '-',
                    color: isOverdue
                        ? Colors.red
                        : isDueSoon
                            ? Colors.orange
                            : null),
              ],
            ),

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
                      label: 'เงินต้น',
                      value: '฿${fmt.format(principal)}',
                      color: Colors.grey[800]!),
                  const SizedBox(height: 4),
                  _FinRow(
                      label:
                          'ดอกเบี้ย ($daysPawned วัน × ${(rate * 100).toStringAsFixed(2)}%/เดือน)',
                      value: '฿${fmt.format(standardInterest)}',
                      color: Colors.deepOrange),
                  if (penaltyInterest > 0) ...[
                    const SizedBox(height: 4),
                    _FinRow(
                        label: 'ค่าปรับเกินกำหนด',
                        value: '฿${fmt.format(penaltyInterest)}',
                        color: Colors.red),
                  ],
                  const Divider(height: 12),
                  _FinRow(
                    label: 'ยอดต้องชำระ',
                    value: '฿${fmt.format(totalOwed)}',
                    color: statusColor == Colors.grey
                        ? Colors.orange[800]!
                        : statusColor,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey[700]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _FinRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Redeemed pawns (ไถ่ถอนแล้ว)
// ═══════════════════════════════════════════════════════════════════════════════

class _RedeemedPawnsTab extends StatelessWidget {
  const _RedeemedPawnsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'redeem')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีรายการไถ่ถอน'));
        }

        final sortedDocs = docs.toList()
          ..sort((a, b) {
            final t1 = (a.data() as Map<String, dynamic>)['timestamp']
                as Timestamp?;
            final t2 = (b.data() as Map<String, dynamic>)['timestamp']
                as Timestamp?;
            if (t1 == null || t2 == null) return 0;
            return t2.compareTo(t1);
          });

        // Totals
        double totalInterest = 0;
        for (final doc in sortedDocs) {
          final d = doc.data() as Map<String, dynamic>;
          totalInterest +=
              (d['interestPaid'] as num?)?.toDouble() ?? 0.0;
        }

        return Column(
          children: [
            _RedeemedSummaryBar(
                count: sortedDocs.length, totalInterest: totalInterest),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      sortedDocs[index].data() as Map<String, dynamic>;
                  return _RedeemedPawnCard(data: data);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RedeemedSummaryBar extends StatelessWidget {
  final int count;
  final double totalInterest;

  const _RedeemedSummaryBar(
      {required this.count, required this.totalInterest});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      color: Colors.green.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ไถ่ถอนแล้ว',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('$count รายการ',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ดอกเบี้ยที่เก็บได้รวม',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text('฿${fmt.format(totalInterest)}',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RedeemedPawnCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RedeemedPawnCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd/MM/yyyy');

    final details = data['details'] as String? ?? 'ไถ่ถอน';
    final userEmail = data['userEmail'] as String? ?? '';
    final totalOwed = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final principal = (data['principal'] as num?)?.toDouble() ?? 0.0;
    final interestPaid = (data['interestPaid'] as num?)?.toDouble() ?? 0.0;
    final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(details,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(userEmail,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (timestamp != null)
                    Text(dateFmt.format(timestamp),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Tag('${weight.toStringAsFixed(2)} บาท',
                          Colors.amber.withValues(alpha: 0.1), Colors.amber[800]!),
                      _Tag('เงินต้น ฿${fmt.format(principal)}',
                          Colors.grey[100]!, Colors.grey[600]!),
                      _Tag('ดอกเบี้ย ฿${fmt.format(interestPaid)}',
                          Colors.green.withValues(alpha: 0.1),
                          Colors.green[700]!),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('฿${fmt.format(totalOwed)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2E7D32))),
                Text('รับชำระ',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Tag(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 10, color: fg)),
    );
  }
}
