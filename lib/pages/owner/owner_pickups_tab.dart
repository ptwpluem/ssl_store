// lib/pages/owner/owner_pickups_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../models/appointment.dart';
import '../../services/appointment_service.dart';

class OwnerPickupsTab extends StatefulWidget {
  const OwnerPickupsTab({super.key});

  @override
  State<OwnerPickupsTab> createState() => _OwnerPickupsTabState();
}

class _OwnerPickupsTabState extends State<OwnerPickupsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AppointmentService _service = AppointmentService();

  // Created ONCE in initState so FutureBuilder keeps the same Future object
  // across rebuilds. Recreating it inside build() causes FutureBuilder to
  // reset to its loading state on every setState() call.
  late final Future<Map<String, Map<String, dynamic>>> _userMapFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userMapFuture = FirebaseFirestore.instance.collection('users').get().then(
      (snap) {
        final Map<String, Map<String, dynamic>> map = {};
        for (final doc in snap.docs) {
          final data = doc.data();
          final uid = data['uid'] as String?;
          if (uid != null) map[uid] = data;
        }
        return map;
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Complete action ───────────────────────────────────────────────────────

  Future<void> _confirmComplete(
      Appointment apt, Map<String, Map<String, dynamic>> userMap) async {
    final name = _customerName(apt.userId, userMap);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการส่งมอบสินค้า?'),
        content: Text(
            'ยืนยันส่งมอบ "${apt.assetName}" ให้ลูกค้า $name เรียบร้อยแล้ว?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _service.completeAppointment(
        appointmentId: apt.id,
        userId: apt.userId,
        assetId: apt.assetId,
        assetName: apt.assetName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งมอบ ${apt.assetName} ให้ $name สำเร็จ'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _customerName(String userId, Map<String, Map<String, dynamic>> userMap) {
    final data = userMap[userId];
    if (data == null) return 'ลูกค้า';
    final first = data['firstName'] as String? ?? '';
    final last = data['lastName'] as String? ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final email = data['email'] as String? ?? '';
    return email.isNotEmpty ? email : 'ลูกค้า';
  }

  String _purposeLabel(String? purpose) {
    switch (purpose) {
      case 'gold_bar_pickup':
        return 'รับทองแท่ง';
      case 'pawn_dropoff':
        return 'ฝากจำนำ';
      case 'consultation':
        return 'ปรึกษา';
      case 'purchase_pickup':
        return 'รับสินค้า';
      default:
        return 'นัดรับสินค้า';
    }
  }

  Color _purposeColor(String? purpose) {
    switch (purpose) {
      case 'gold_bar_pickup':
        return const Color(0xFFE65100);
      case 'pawn_dropoff':
        return const Color(0xFF1976D2);
      case 'consultation':
        return const Color(0xFF00695C);
      default:
        return const Color(0xFF800000);
    }
  }

  String _thaiDateLabel(DateTime dateKey) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (dateKey == today) return 'วันนี้';
    if (dateKey == tomorrow) return 'พรุ่งนี้';

    const thaiDays = [
      'วันจันทร์',
      'วันอังคาร',
      'วันพุธ',
      'วันพฤหัสบดี',
      'วันศุกร์',
      'วันเสาร์',
      'วันอาทิตย์',
    ];
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];

    final dayName = thaiDays[dateKey.weekday - 1];
    final monthName = thaiMonths[dateKey.month - 1];
    final year = dateKey.year + 543;
    return '$dayName ${dateKey.day} $monthName $year';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, dynamic>>>(
      future: _userMapFuture,
      builder: (context, userSnap) {
        final userMap = userSnap.data ?? {};

        return Column(
          children: [
            // Tab bar (no AppBar — we're inside the owner dashboard scaffold)
            Container(
              color: const Color(0xFF800000),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: const Color(0xFFFFD700),
                tabs: const [
                  Tab(icon: Icon(Icons.pending_actions, size: 18), text: 'รอดำเนินการ'),
                  Tab(icon: Icon(Icons.history, size: 18), text: 'ประวัติ'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PendingTab(
                    service: _service,
                    userMap: userMap,
                    onConfirm: _confirmComplete,
                    purposeLabel: _purposeLabel,
                    purposeColor: _purposeColor,
                    thaiDateLabel: _thaiDateLabel,
                    customerName: _customerName,
                  ),
                  _HistoryTab(
                    service: _service,
                    userMap: userMap,
                    purposeLabel: _purposeLabel,
                    purposeColor: _purposeColor,
                    customerName: _customerName,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Pending Tab ──────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final AppointmentService service;
  final Map<String, Map<String, dynamic>> userMap;
  final Future<void> Function(Appointment, Map<String, Map<String, dynamic>>)
      onConfirm;
  final String Function(String?) purposeLabel;
  final Color Function(String?) purposeColor;
  final String Function(DateTime) thaiDateLabel;
  final String Function(String, Map<String, Map<String, dynamic>>) customerName;

  const _PendingTab({
    required this.service,
    required this.userMap,
    required this.onConfirm,
    required this.purposeLabel,
    required this.purposeColor,
    required this.thaiDateLabel,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: service.getAllScheduledAppointmentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('โหลดข้อมูลไม่สำเร็จ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final appointments = snapshot.data ?? [];

        // Summary counts
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayCount = appointments
            .where((a) =>
                DateTime(a.date.year, a.date.month, a.date.day) == today)
            .length;
        final overdueCount = appointments
            .where((a) =>
                DateTime(a.date.year, a.date.month, a.date.day).isBefore(today))
            .length;

        if (appointments.isEmpty) {
          return Column(
            children: [
              _SummaryBar(total: 0, todayCount: 0, overdueCount: 0),
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ไม่มีรายการนัดรับสินค้า',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('รายการนัดรับทั้งหมดได้รับการจัดการเรียบร้อยแล้ว',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Group by date
        final grouped = <DateTime, List<Appointment>>{};
        for (final apt in appointments) {
          final key =
              DateTime(apt.date.year, apt.date.month, apt.date.day);
          grouped.putIfAbsent(key, () => []).add(apt);
        }
        final sortedDates = grouped.keys.toList()..sort();

        return Column(
          children: [
            _SummaryBar(
                total: appointments.length,
                todayCount: todayCount,
                overdueCount: overdueCount),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  final dateKey = sortedDates[index];
                  final dailyApts = grouped[dateKey]!;
                  final isOverdue = dateKey.isBefore(today);
                  final isToday = dateKey == today;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 12, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? Colors.red
                                    : isToday
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF800000),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              thaiDateLabel(dateKey),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isOverdue
                                    ? Colors.red[700]
                                    : isToday
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF800000),
                              ),
                            ),
                            if (isOverdue) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('เกินกำหนด',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...dailyApts.map((apt) => _AppointmentCard(
                            apt: apt,
                            userMap: userMap,
                            isToday: isToday || isOverdue,
                            purposeLabel: purposeLabel,
                            purposeColor: purposeColor,
                            customerName: customerName,
                            onConfirm: onConfirm,
                          )),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final AppointmentService service;
  final Map<String, Map<String, dynamic>> userMap;
  final String Function(String?) purposeLabel;
  final Color Function(String?) purposeColor;
  final String Function(String, Map<String, Map<String, dynamic>>) customerName;

  const _HistoryTab({
    required this.service,
    required this.userMap,
    required this.purposeLabel,
    required this.purposeColor,
    required this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: service.getAllAppointmentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('ข้อผิดพลาด: ${snapshot.error}'));
        }

        final all = snapshot.data ?? [];
        final completed = all
            .where((a) =>
                a.status == 'completed' || a.status == 'cancelled')
            .toList();

        if (completed.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('ยังไม่มีประวัติการรับสินค้า',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: completed.length,
          itemBuilder: (context, index) {
            final apt = completed[index];
            final name = customerName(apt.userId, userMap);
            final isCompleted = apt.status == 'completed';
            final pColor = purposeColor(apt.purpose);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isCompleted
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.grey[200],
                      child: Icon(
                        isCompleted ? Icons.check_circle : Icons.cancel,
                        color: isCompleted ? Colors.green[700] : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(apt.assetName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(apt.date),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(purposeLabel(apt.purpose),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: pColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green.withValues(alpha: 0.08)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isCompleted ? 'เสร็จสิ้น' : 'ยกเลิก',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? Colors.green[700]
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Summary bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int total;
  final int todayCount;
  final int overdueCount;

  const _SummaryBar({
    required this.total,
    required this.todayCount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF800000).withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _Cell(
            label: 'รอดำเนินการทั้งหมด',
            value: '$total รายการ',
            color: const Color(0xFF800000),
          ),
          const SizedBox(width: 8),
          _Cell(
            label: 'วันนี้',
            value: '$todayCount รายการ',
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(width: 8),
          _Cell(
            label: 'เกินกำหนด',
            value: '$overdueCount รายการ',
            color: overdueCount > 0 ? Colors.red[700]! : Colors.grey,
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

  const _Cell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── Appointment card ─────────────────────────────────────────────────────────

class _AppointmentCard extends StatelessWidget {
  final Appointment apt;
  final Map<String, Map<String, dynamic>> userMap;
  final bool isToday;
  final String Function(String?) purposeLabel;
  final Color Function(String?) purposeColor;
  final String Function(String, Map<String, Map<String, dynamic>>) customerName;
  final Future<void> Function(Appointment, Map<String, Map<String, dynamic>>)
      onConfirm;

  const _AppointmentCard({
    required this.apt,
    required this.userMap,
    required this.isToday,
    required this.purposeLabel,
    required this.purposeColor,
    required this.customerName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');
    final name = customerName(apt.userId, userMap);
    final pColor = purposeColor(apt.purpose);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isToday ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Time column
            Column(
              children: [
                Text(
                  timeFmt.format(apt.date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: isToday
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF800000),
                  ),
                ),
                Text('น.',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(width: 14),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Purpose badge + asset name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          purposeLabel(apt.purpose),
                          style: TextStyle(
                              fontSize: 10,
                              color: pColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    apt.assetName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Action button
            isToday
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.delivery_dining, size: 16),
                    label: const Text('ส่งมอบ',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => onConfirm(apt, userMap),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[500],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: null,
                    child: Text('ยังไม่ถึงกำหนด',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ),
          ],
        ),
      ),
    );
  }
}
