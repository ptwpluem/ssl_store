import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import 'package:intl/intl.dart';
import 'member_login_page.dart';
import 'member_appointment_page.dart';
import 'member_edit_profile_page.dart';
import 'member_transactions_page.dart';
import 'member_security_settings_page.dart';
import 'member_help_support_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user != null) {
          return _ProfileMemberView(
            user: user,
            onLogout: () async {
              await _authService.signOut();
            },
          );
        } else {
          return _ProfileGuestView(
            onLoginRequest: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage(initialIsLogin: true)));
            },
            onSignUpRequest: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage(initialIsLogin: false)));
            },
          );
        }
      },
    );
  }
}

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _guestPrimary     = Color(0xFF800000);
const Color _guestPrimaryDark = Color(0xFF5C0000);
const Color _guestGold        = Color(0xFFFFD700);

// ── Guest View (Landing) ─────────────────────────────────────────────────────
class _ProfileGuestView extends StatelessWidget {
  final VoidCallback onLoginRequest;
  final VoidCallback onSignUpRequest;
  const _ProfileGuestView({required this.onLoginRequest, required this.onSignUpRequest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_guestPrimary, _guestPrimaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Branded header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _guestGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _guestGold.withValues(alpha: 0.5), width: 1),
                      ),
                      child: const Icon(Icons.store_rounded, color: _guestGold, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ห้างทองสุ้นเซ่งหลี',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'ทองคำบริสุทธิ์ 96.5%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Card ───────────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Card header stripe ────────────────────────
                          Container(
                            height: 6,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_guestPrimary, _guestGold],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                            child: Column(
                              children: [
                                // ── Logo icon ───────────────────────────
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_guestPrimary, _guestPrimaryDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _guestPrimary.withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.workspace_premium_rounded, size: 48, color: _guestGold),
                                ),
                                const SizedBox(height: 20),

                                // ── Title ───────────────────────────────
                                const Text(
                                  'ยินดีต้อนรับสู่',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF888888),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'ห้างทองสุ้นเซ่งหลี',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _guestPrimary,
                                    letterSpacing: 0.3,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // ── Feature highlights ──────────────────
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: const [
                                      _FeatureRow(
                                        icon: Icons.pie_chart_rounded,
                                        iconColor: Color(0xFF1565C0),
                                        text: 'ดูพอร์ตการลงทุนและมูลค่าทองของคุณ',
                                      ),
                                      SizedBox(height: 10),
                                      _FeatureRow(
                                        icon: Icons.account_balance_wallet_rounded,
                                        iconColor: Color(0xFF2E7D32),
                                        text: 'ติดตามยอดวอลเล็ตและประวัติรายการ',
                                      ),
                                      SizedBox(height: 10),
                                      _FeatureRow(
                                        icon: Icons.calendar_month_rounded,
                                        iconColor: Color(0xFFF57C00),
                                        text: 'จัดการนัดหมายรับทองที่หน้าร้าน',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // ── Login button ────────────────────────
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: onLoginRequest,
                                    icon: const Icon(Icons.login_rounded, size: 18),
                                    label: const Text(
                                      'เข้าสู่ระบบ',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _guestPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      elevation: 2,
                                      shadowColor: _guestPrimary.withValues(alpha: 0.4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // ── Register button ─────────────────────
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: onSignUpRequest,
                                    icon: const Icon(Icons.person_add_rounded, size: 18),
                                    label: const Text(
                                      'สมัครสมาชิก',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _guestPrimary,
                                      side: const BorderSide(color: _guestPrimary, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Footer note ─────────────────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 4, height: 4,
                                      decoration: BoxDecoration(
                                        color: _guestGold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ราคาทองอ้างอิงจากสมาคมค้าทองคำ',
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 4, height: 4,
                                      decoration: BoxDecoration(
                                        color: _guestGold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Feature row helper ───────────────────────────────────────────────────────
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  const _FeatureRow({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ── Member View (Profile Hub) ───────────────────────────────────────────────
class _ProfileMemberView extends StatelessWidget {
  final User user;
  final VoidCallback onLogout;
  
  const _ProfileMemberView({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Soft premium grey background
      body: CustomScrollView(
        slivers: [
          _buildHeroHeader(context),
          SliverToBoxAdapter(
            child: _buildOverlappingContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final name = user.displayName ?? 'สมาชิกคนสำคัญ';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'ส';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF800000),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF800000), Color(0xFF550000)], // Rich Maroon Gradient
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFD700), width: 4), // Gold Border
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                      child: user.photoURL == null 
                        ? Text(
                            initial,
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF800000)),
                          )
                        : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                StreamBuilder<int>(
                  stream: UserService().getRewardPointsStream(),
                  builder: (context, snapshot) {
                    final points = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700), // Gold badge
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        '${NumberFormat('#,##0').format(points)} คะแนน',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF800000), letterSpacing: 0.5),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30), // Padding for the overlap
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlappingContent(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -30), // Overlap the header
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F7), // Match scaffold body
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             _buildSectionTitle('ข้อมูลบัญชี'),
            _buildGroupedList([
              _buildListTile(
                icon: Icons.person_outline,
                title: 'แก้ไขข้อมูลส่วนตัว',
                subtitle: 'อัปเดตชื่อ รูปถ่าย และเบอร์โทรศัพท์ของคุณ',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage())),
              ),
            ]),
            const SizedBox(height: 32),
            _buildInfoCard(
              icon: Icons.email,
              title: 'ที่อยู่อีเมล',
              subtitle: user.email ?? 'ไม่ได้ระบุอีเมล',
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle('บริการของทางร้าน'),
            _buildGroupedList([
              _buildListTile(
                icon: Icons.calendar_month, 
                title: 'รายการนัดหมายของฉัน', 
                subtitle: 'จัดการตารางนัดหมายรับทองที่หน้าร้าน',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentPage())),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.history, 
                title: 'ประวัติการทำรายการ', 
                subtitle: 'ดูรายการซื้อ ขายคืน และจำนำ ย้อนหลัง',
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryPage()));
                },
              ),
            ]),
            
            const SizedBox(height: 32),
            _buildSectionTitle('การตั้งค่า'),
            _buildGroupedList([
              _buildListTile(
                icon: Icons.lock_outline, 
                title: 'ระบบความปลอดภัย', 
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsPage()));
                },
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.help_outline, 
                title: 'ความช่วยเหลือและติดต่อเรา', 
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()));
                },
              ),
            ]),

            const SizedBox(height: 48),
            _buildLogoutButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF800000).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF800000)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF800000).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF800000)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 64, thickness: 1, color: Color(0xFFF0F0F0));
  }

  Widget _buildLogoutButton() {
    return ElevatedButton.icon(
      onPressed: onLogout,
      icon: const Icon(Icons.logout),
      label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red.shade700,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade200, width: 1.5),
        ),
      ),
    );
  }
}
