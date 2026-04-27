import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final bool initialIsLogin;
  const LoginPage({super.key, this.initialIsLogin = true});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();


  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
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
      if (mounted) {
        Navigator.pop(context); // Go back to where they came from
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim();
        Color bgColor = Colors.red;

        if (_authService.isNetworkError(e)) {
          message =
              "เกิดข้อผิดพลาดในการเชื่อมต่อ: กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตหรือการตั้งค่า Firebase";
          bgColor = Colors.orange.shade800;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onLongPress: () {
                  // Developer Bypass: Fill with mock credentials
                  _emailController.text = 'owner_account@gmail.com';
                  _passwordController.text = 'password123';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Developer Bypass: โหลดข้อมูลจำลองแล้ว',
                      ),
                    ),
                  );
                },
                child: const Icon(
                  Icons.stars,
                  size: 80,
                  color: Color(0xFFFFD700),
                ),
              ), // Gold Icon
              const SizedBox(height: 24),
              Text(
                _isLogin ? 'ยินดีต้อนรับกลับ!' : 'เข้าร่วมกับ สุ้นเซ่งหลี โกลด์',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF800000),
                ),
              ),
              const SizedBox(height: 48),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              decoration: InputDecoration(
                                labelText: 'ชื่อ *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.person),
                              ),
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'กรุณากรอกชื่อ'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              decoration: InputDecoration(
                                labelText: 'นามสกุล *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'กรุณากรอกนามสกุล'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'เบอร์โทรศัพท์ *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'กรุณากรอกเบอร์โทรศัพท์'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'ที่อยู่ *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        keyboardType: TextInputType.streetAddress,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'กรุณากรอกที่อยู่'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'อีเมล *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'กรุณากรอกอีเมล';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(val)) {
                          return 'รูปแบบอีเมลไม่ถูกต้อง';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      validator: (val) => val == null || val.length < 6
                          ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF800000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isLogin ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? "ยังไม่มีบัญชี? สมัครสมาชิก"
                      : "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ",
                  style: const TextStyle(color: Color(0xFF800000)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
