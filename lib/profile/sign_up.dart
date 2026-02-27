import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_localizations.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _loadLangAndCheck();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadLangAndCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language') ?? 'en';
    final loggedIn = prefs.getBool('loggedIn') ?? false;

    if (!mounted) return;
    setState(() => _lang = lang);

    if (loggedIn) {
      final loc = AppLocalizations.of(_lang);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc['alreadyLoggedInSnack'] ?? 'You are already logged in'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  // ---------------- VALIDATORS ----------------

  String? _validateUsername(String? value, Map<String, String> loc) {
    if (value == null || value.trim().isEmpty) return loc['usernameRequired'];
    if (value.trim().length < 3) return loc['usernameTooShort'];
    if (value.trim().length > 20) return loc['usernameTooLong'];
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return loc['usernameInvalid'];
    }
    return null;
  }

  String? _validateEmail(String? value, Map<String, String> loc) {
    if (value == null || value.trim().isEmpty) return loc['emailRequired'];
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(value.trim())) {
      return loc['emailInvalid'];
    }
    return null;
  }

  String? _validatePassword(String? value, Map<String, String> loc) {
    if (value == null || value.isEmpty) return loc['passwordRequired'];
    if (value.length < 8) return loc['passwordWeak'];
    if (!RegExp(r'[A-Z]').hasMatch(value)) return loc['passwordNoUppercase'];
    if (!RegExp(r'[0-9]').hasMatch(value)) return loc['passwordNoNumber'];
    return null;
  }

  String? _validateConfirm(String? value, Map<String, String> loc) {
    if (value == null || value.isEmpty) return loc['confirmPasswordRequired'];
    if (value != _passwordController.text) return loc['passwordsMismatch'];
    return null;
  }

  // ---------------- PASSWORD STRENGTH ----------------

  _PasswordStrength _getStrength(String password) {
    if (password.isEmpty) return _PasswordStrength.none;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 1) return _PasswordStrength.weak;
    if (score <= 3) return _PasswordStrength.medium;
    return _PasswordStrength.strong;
  }

  // ---------------- FIREBASE SIGN UP ----------------

  Future<void> _handleSignUp(Map<String, String> loc) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final username = _usernameController.text.trim();

      // 🔥 Firebase Auth
      UserCredential credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null) {
        // 🗂 Firestore user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'username': username,
          'email': email,
          'createdAt': Timestamp.now(),
        });

        // 💾 Local session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);
        await prefs.setString('username', username);
        await prefs.setString('email', email);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc['signupSuccess'] ?? 'Account created successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacementNamed(context, '/home');
      }
    }

    // Firebase errors
    on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = loc['emailAlreadyInUse'] ?? 'Email already in use.';
          break;
        case 'weak-password':
          message = loc['passwordWeak'] ?? 'Password is too weak.';
          break;
        case 'invalid-email':
          message = loc['emailInvalid'] ?? 'Invalid email address.';
          break;
        case 'network-request-failed':
          message = loc['networkError'] ?? 'Network error.';
          break;
        default:
          message = loc['signupFailed'] ?? 'Registration failed.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc['signupFailed'] ?? 'Something went wrong'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }

    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(_lang);

    final gradientColors = isDark
        ? const [Color(0xFF022C33), Color(0xFF064E63), Color(0xFF0B356B)]
        : const [Color(0xFF0EA5A4), Color(0xFF0F9FB8), Color(0xFF0F77D1)];
    final cardColor = isDark ? const Color(0xFF020617).withOpacity(0.88) : Colors.white.withOpacity(0.95);
    final labelColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final titleColor = isDark ? Colors.white : Colors.grey.shade900;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final fieldFill = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;
    final fieldBorder = isDark ? Colors.white.withOpacity(0.12) : Colors.grey.shade300;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors,
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.16),
                    blurRadius: 26, offset: const Offset(0, 20),
                  )],
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.7),
                    width: 1.4,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(color: Color(0xFF0EA5A4), shape: BoxShape.circle),
                          child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(loc['appTitle'] ?? 'LingoLens AI',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800, color: titleColor)),
                      const SizedBox(height: 6),
                      Text(loc['signupTitle'] ?? 'Create Your Account',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
                      const SizedBox(height: 24),

                      // Username
                      _buildField(label: loc['username'] ?? 'Username', labelColor: labelColor,
                        child: TextFormField(
                          controller: _usernameController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => _validateUsername(v, loc),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _inputDecoration(hint: loc['usernameHint'] ?? 'e.g. john_doe',
                              prefixIcon: Icons.person_outline, fieldFill: fieldFill,
                              fieldBorder: fieldBorder, isDark: isDark),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Email
                      _buildField(label: loc['email'] ?? 'Email', labelColor: labelColor,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => _validateEmail(v, loc),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _inputDecoration(hint: loc['emailHint'] ?? 'user@example.com',
                              prefixIcon: Icons.email_outlined, fieldFill: fieldFill,
                              fieldBorder: fieldBorder, isDark: isDark),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password
                      _buildField(label: loc['password'] ?? 'Password', labelColor: labelColor,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: (v) => _validatePassword(v, loc),
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                            decoration: _inputDecoration(
                              hint: loc['passwordHint'] ?? 'Min 8 chars, 1 uppercase, 1 number',
                              prefixIcon: Icons.lock_outline, fieldFill: fieldFill,
                              fieldBorder: fieldBorder, isDark: isDark,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _PasswordStrengthBar(strength: _getStrength(_passwordController.text), loc: loc),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // Confirm Password
                      _buildField(label: loc['confirmPassword'] ?? 'Confirm Password', labelColor: labelColor,
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => _validateConfirm(v, loc),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _inputDecoration(
                            hint: loc['confirmPasswordHint'] ?? 'Re-enter your password',
                            prefixIcon: Icons.lock_outline, fieldFill: fieldFill,
                            fieldBorder: fieldBorder, isDark: isDark,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                              ),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Sign Up button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleSignUp(loc),
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(), padding: EdgeInsets.zero,
                            elevation: 0, backgroundColor: Colors.transparent,
                          ).copyWith(
                            backgroundColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
                            shadowColor: WidgetStateProperty.all(Colors.transparent),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: _isLoading
                                  ? [Colors.grey.shade500, Colors.grey.shade500]
                                  : const [Color(0xFF0EA5A4), Color(0xFF12B4CF)]),
                              borderRadius: const BorderRadius.all(Radius.circular(999)),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : Text(loc['signUp'] ?? 'Sign Up',
                                      style: const TextStyle(color: Colors.white,
                                          fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(loc['haveAccount'] ?? 'Already have an account? ',
                              style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: Text(loc['logIn'] ?? 'Log In',
                                style: const TextStyle(
                                    color: Color(0xFF0F77D1), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required String label, required Color labelColor, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: labelColor, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      child,
    ]);
  }

  InputDecoration _inputDecoration({
    required String hint, required IconData prefixIcon,
    required Color fieldFill, required Color fieldBorder,
    required bool isDark, Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      suffixIcon: suffixIcon, filled: true, fillColor: fieldFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fieldBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fieldBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0EA5A4), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

enum _PasswordStrength { none, weak, medium, strong }

class _PasswordStrengthBar extends StatelessWidget {
  final _PasswordStrength strength;
  final Map<String, String> loc;
  const _PasswordStrengthBar({required this.strength, required this.loc});

  @override
  Widget build(BuildContext context) {
    final Map<_PasswordStrength, ({Color color, String label, int filled})> config = {
      _PasswordStrength.weak: (color: Colors.red, label: loc['passwordStrengthWeak'] ?? 'Weak', filled: 1),
      _PasswordStrength.medium: (color: Colors.orange, label: loc['passwordStrengthMedium'] ?? 'Medium', filled: 2),
      _PasswordStrength.strong: (color: Colors.green, label: loc['passwordStrengthStrong'] ?? 'Strong', filled: 3),
    };
    final cfg = config[strength];
    if (cfg == null) return const SizedBox.shrink();

    return Row(children: [
      ...List.generate(3, (i) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
          decoration: BoxDecoration(
            color: i < cfg.filled ? cfg.color : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      )),
      const SizedBox(width: 8),
      Text(cfg.label, style: TextStyle(fontSize: 12, color: cfg.color, fontWeight: FontWeight.w500)),
    ]);
  }
}