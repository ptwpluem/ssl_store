// lib/pages/member/member_login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';

// ─── Design tokens (matches owner dashboard) ──────────────────────────────────
const Color _loginPrimary     = Color(0xFF800000);
const Color _loginPrimaryDark = Color(0xFF5C0000);
const Color _loginGold        = Color(0xFFFFD700);
const Color _loginBg          = Color(0xFFF5F7FA);

class LoginPage extends StatefulWidget {
  final bool initialIsLogin;
  const LoginPage({super.key, this.initialIsLogin = true});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController  = TextEditingController();
  final _phoneController     = TextEditingController();
  final _locationController  = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin   = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authService.registerWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          location: _locationController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String message = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim();
        Color bgColor = Colors.red;
        if (_authService.isNetworkError(e)) {
          message = 'เกิดข้อผิดพลาดในการเชื่อมต่อ: กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตหรือการตั้งค่า Firebase';
          bgColor = Colors.orange.shade800;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _loginBg,
        body: Column(
          children: [
            // ── Gradient header ───────────────────────────────────────────
            _buildHeader(),

            // ── Scrollable form card ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Top gold accent stripe
                        Container(
                          height: 5,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_loginPrimary, _loginGold],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          child: _buildForm(),
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
    );
  }

  // ─── Gradient header ────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_loginPrimary, _loginPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Store logo
          GestureDetector(
            onLongPress: () {
              // Developer Bypass: Fill with mock credentials
              _emailController.text = 'owner_account@gmail.com';
              _passwordController.text = 'password123';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Developer Bypass: โหลดข้อมูลจำลองแล้ว')),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _loginGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _loginGold.withValues(alpha: 0.5), width: 2),
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 40, color: _loginGold),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ห้างทองสุ้นเซ่งหลี • ทองคำบริสุทธิ์ 96.5%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form ────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section label ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(color: _loginGold, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(
                _isLogin ? 'ข้อมูลเข้าสู่ระบบ' : 'ข้อมูลสมาชิกใหม่',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _loginPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Register-only fields ─────────────────────────────────────────
          if (!_isLogin) ...[
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _firstNameController,
                    label: 'ชื่อ',
                    icon: Icons.person_rounded,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _lastNameController,
                    label: 'นามสกุล',
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกนามสกุล' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _phoneController,
              label: 'เบอร์โทรศัพท์',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _locationController,
              label: 'ที่อยู่',
              icon: Icons.location_on_rounded,
              keyboardType: TextInputType.streetAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกที่อยู่' : null,
            ),
            const SizedBox(height: 14),
          ],

          // ── Email ────────────────────────────────────────────────────────
          _buildField(
            controller: _emailController,
            label: 'อีเมล',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'กรุณากรอกอีเมล';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return 'รูปแบบอีเมลไม่ถูกต้อง';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // ── Password ─────────────────────────────────────────────────────
          _buildPasswordField(),
          const SizedBox(height: 28),

          // ── Submit button ─────────────────────────────────────────────────
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _loginPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _loginPrimary.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
              shadowColor: _loginPrimary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    _isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Toggle mode ───────────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _isLogin = !_isLogin),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  children: [
                    TextSpan(text: _isLogin ? 'ยังไม่มีบัญชี? ' : 'มีบัญชีอยู่แล้ว? '),
                    TextSpan(
                      text: _isLogin ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                      style: const TextStyle(
                        color: _loginPrimary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: _loginPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared text field builder ────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF888888)),
        prefixIcon: icon != null ? Icon(icon, size: 20, color: _loginPrimary) : null,
        filled: true,
        fillColor: const Color(0xFFF9F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _loginPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  // ─── Password field with visibility toggle ────────────────────────────────────
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(fontSize: 14.5),
      decoration: InputDecoration(
        labelText: 'รหัสผ่าน',
        labelStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF888888)),
        prefixIcon: const Icon(Icons.lock_rounded, size: 20, color: _loginPrimary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: Colors.grey[500],
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _loginPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: (v) => (v == null || v.length < 6)
          ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'
          : null,
    );
  }
}
