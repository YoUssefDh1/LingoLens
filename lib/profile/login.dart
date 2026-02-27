import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _loadLangAndCheck();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc['alreadyLoggedInSnack'] ?? 'You are already logged in'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    }
  }

  String? _validateEmail(String? value, Map<String, String> loc) {
    if (value == null || value.trim().isEmpty) return loc['emailRequired'];
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return loc['emailInvalid'];
    return null;
  }

  String? _validatePassword(String? value, Map<String, String> loc) {
    if (value == null || value.isEmpty) return loc['passwordRequired'];
    if (value.length < 6) return loc['passwordTooShort'];
    return null;
  }

  Future<void> _handleLogin(Map<String, String> loc) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      // Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Save login state locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('loggedIn', true);

      if (!mounted) return;
      
      // Navigate to home
      Navigator.pushReplacementNamed(context, '/home');
      
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = loc['userNotFound'] ?? 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = loc['wrongPassword'] ?? 'Wrong password.';
          break;
        case 'invalid-email':
          errorMessage = loc['invalidEmail'] ?? 'Invalid email format.';
          break;
        case 'user-disabled':
          errorMessage = loc['userDisabled'] ?? 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = loc['tooManyRequests'] ?? 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? (loc['loginFailed'] ?? 'Login failed');
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${loc['loginFailed'] ?? 'Login failed:'} ${e.toString()}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(_lang);

    final gradientColors = isDark
        ? const [Color(0xFF022C33), Color(0xFF064E63), Color(0xFF0B7285)]
        : const [Color(0xFF0EA5A4), Color(0xFF12B4CF), Color(0xFF0F9FB8)];
    final cardColor = isDark ? const Color(0xFF020617).withOpacity(0.88) : Colors.white.withOpacity(0.9);
    final labelColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final titleColor = isDark ? Colors.white : Colors.grey.shade900;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final fieldFill = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;
    final fieldBorder = isDark ? Colors.white.withOpacity(0.12) : Colors.grey.shade300;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                    blurRadius: 24, offset: const Offset(0, 16),
                  )],
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.6),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(color: Color(0xFF0EA5A4), shape: BoxShape.circle),
                          child: const Icon(Icons.mail_outline, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(loc['appTitle'] ?? 'LingoLens AI',
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800, color: titleColor)),
                      const SizedBox(height: 6),
                      Text(loc['loginTitle'] ?? 'Sign In to Your Account',
                          style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
                      const SizedBox(height: 24),

                      // Email
                      _LabeledField(
                        label: loc['email'] ?? 'Email',
                        labelColor: labelColor,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => _validateEmail(v, loc),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _inputDecoration(
                            hint: loc['emailHint'] ?? 'user@example.com',
                            prefixIcon: Icons.email_outlined,
                            fieldFill: fieldFill, fieldBorder: fieldBorder, isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      _LabeledField(
                        label: loc['password'] ?? 'Password',
                        labelColor: labelColor,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) => _validatePassword(v, loc),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: _inputDecoration(
                            hint: loc['password'] ?? 'Password',
                            prefixIcon: Icons.lock_outline,
                            fieldFill: fieldFill, fieldBorder: fieldBorder, isDark: isDark,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Implement password reset
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(loc['forgotPassword'] ?? 'Forgot Password?',
                              style: const TextStyle(
                                  color: Color(0xFF0F77D1), decoration: TextDecoration.underline)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Log In button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleLogin(loc),
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
                                  : Text(loc['logIn'] ?? 'Log In',
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
                          Text(loc['noAccount'] ?? 'Don\'t have an account? ',
                              style: theme.textTheme.bodyMedium?.copyWith(color: subtitleColor)),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/signup'),
                            child: Text(loc['signUp'] ?? 'Sign Up',
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

  InputDecoration _inputDecoration({
    required String hint, required IconData prefixIcon,
    required Color fieldFill, required Color fieldBorder,
    required bool isDark, Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
      suffixIcon: suffixIcon,
      filled: true, fillColor: fieldFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fieldBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: fieldBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0EA5A4), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Widget child;
  const _LabeledField({required this.label, required this.labelColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: labelColor, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      child,
    ]);
  }
}