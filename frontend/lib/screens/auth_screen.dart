import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'shell_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, this.isLogin = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late bool isLogin;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _bgController1;
  late AnimationController _bgController2;
  late AnimationController _bgController3;
  late AnimationController _bgController4;

  @override
  void initState() {
    super.initState();
    isLogin = widget.isLogin;

    _bgController1 =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
    _bgController2 =
        AnimationController(vsync: this, duration: const Duration(seconds: 15))
          ..repeat(reverse: true);
    _bgController3 =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat(reverse: true);
    _bgController4 =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController1.dispose();
    _bgController2.dispose();
    _bgController3.dispose();
    _bgController4.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final endpoint = isLogin ? '/auth/login' : '/auth/signup';
      final body = isLogin
          ? {
              'email': _emailController.text,
              'password': _passwordController.text,
            }
          : {
              'name': _nameController.text,
              'email': _emailController.text,
              'phone': _phoneController.text,
              'password': _passwordController.text,
            };

      final response = await ApiService.post(endpoint, body);

      if (response != null && response['error'] == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => ShellScreen(userData: response['user'])),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(response?['error'] ?? 'Authentication failed'),
                backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/google');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Google Sign In')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        // Increased border opacity and width to make the field clearly visible against the card
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), // Slightly stronger shadow
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          // Darker hint text for better readability
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: Colors.blue[600], size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.blue[600],
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF), // Light gradient-like background matching image
      body: Stack(
        children: [
          // Background blobs for soft wave effect
          AnimatedBuilder(
            animation: _bgController1,
            builder: (context, child) {
              return Positioned(
                top: -100 + 50 * sin(_bgController1.value * 2 * pi),
                left: -80 + 50 * cos(_bgController1.value * 2 * pi),
                child: _buildBall(300, const Color(0xFFD4DEFF)), // Top left light blue
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController2,
            builder: (context, child) {
              return Positioned(
                bottom: -150 + 60 * cos(_bgController2.value * 2 * pi),
                left: -100 + 60 * sin(_bgController2.value * 2 * pi),
                child: _buildBall(400, const Color(0xFF8BA6FF)), // Bottom left strong blue
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController3,
            builder: (context, child) {
              return Positioned(
                bottom: 50 + 40 * sin(_bgController3.value * 2 * pi),
                right: -100 + 40 * cos(_bgController3.value * 2 * pi),
                child: _buildBall(250, const Color(0xFFE2D9FF)), // Bottom right light purple
              );
            },
          ),
          AnimatedBuilder(
            animation: _bgController4,
            builder: (context, child) {
              return Positioned(
                top: 80 + 70 * sin(_bgController4.value * 2 * pi),
                right: -50 + 70 * cos(_bgController4.value * 2 * pi),
                child: _buildBall(200, const Color(0xFFC7D3FF)), // Top right soft blue
              );
            },
          ),

          // Top left and bottom right dot patterns
          Positioned(top: 60, left: 24, child: _buildDots()),
          Positioned(bottom: 80, right: 24, child: _buildDots()),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo / Icon
                            Icon(Icons.business, size: 40, color: Colors.blue[600]),
                            const SizedBox(height: 10),
            
                            Text(
                              isLogin ? 'WELCOME BACK' : 'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.blue[900],
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
            
                            // Line divider
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(height: 2, width: 32, color: Colors.blue[600]),
                                const SizedBox(width: 4),
                                Icon(Icons.circle, size: 5, color: Colors.blue[600]),
                                const SizedBox(width: 4),
                                Container(height: 1, width: 32, color: Colors.grey[300]),
                              ],
                            ),
                            const SizedBox(height: 28),
            
                            if (!isLogin) ...[
                              _buildTextField(
                                controller: _nameController,
                                hint: 'Full Name',
                                icon: Icons.person_outline,
                              ),
                              _buildTextField(
                                controller: _phoneController,
                                hint: 'Phone Number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
            
                            _buildTextField(
                              controller: _emailController,
                              hint: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
            
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),
            
                            const SizedBox(height: 6),
            
                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.flash_on,
                                                color: Colors.white, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
            
                            const SizedBox(height: 20),
            
                            // OR divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('OR',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ),
                                Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                              ],
                            ),
            
                            const SizedBox(height: 16),
            
                            // Google Button
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _signInWithGoogle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                                  ),
                                  elevation: 0,
                                ),
                                icon: Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Google_%22G%22_Logo.svg/512px-Google_%22G%22_Logo.svg.png',
                                  height: 18,
                                  width: 18,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.g_mobiledata, color: Colors.blue, size: 28),
                                ),
                                label: const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                              ),
                            ),
                          ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutQuart),
                    
                    const SizedBox(height: 20),
                    
                    // Bottom Sign In / Sign Up Link
                    Column(
                      children: [
                        Text(
                          isLogin
                              ? "Don't have an account?"
                              : 'Already have an account?',
                          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isLogin ? 'Sign Up' : 'Sign In',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.blue[700], size: 20),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBall(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.0)],
          center: Alignment.center,
          radius: 0.8,
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Column(
      children: List.generate(
          5,
          (i) => Row(
                children: List.generate(
                    5,
                    (j) => Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )),
              )),
    );
  }
}

