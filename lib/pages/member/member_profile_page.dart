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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF800000), Color(0xFF330000)], // Deep Brand Maroon to Dark Red
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Container(
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 2),
                      ),
                      child: const Icon(Icons.workspace_premium, size: 64, color: Color(0xFF800000)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'ยินดีต้อนรับสู่\nห้างทองสุ้นเซ่งหลี',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia', // Elegant serif fallback
                        fontSize: 26, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF800000)
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'เข้าสู่ระบบเพื่อดูพอร์ตการลงทุน จัดการการนัดหมาย และติดตามยอดคงเหลือของคุณ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onLoginRequest,
                        icon: const Icon(Icons.login),
                        label: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF800000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onSignUpRequest,
                        icon: const Icon(Icons.person_add),
                        label: const Text('สมัครสมาชิก', style: TextStyle(fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF800000),
                          side: const BorderSide(color: Color(0xFF800000), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
