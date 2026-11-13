
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../Statemanage_riverpod/provider/AuthServicesProvider.dart';
import '../../../app_file/theme_file/app_colors.dart';
import '../../Auth_widgets/widgets/app_logo.dart';
import '../../Auth_widgets/widgets/auth_card.dart';
import '../../Auth_widgets/widgets/custom_text_field.dart';
import '../../Auth_widgets/widgets/fade_slide.dart';
import '../../Auth_widgets/widgets/google_button.dart';
import '../../Auth_widgets/widgets/gradient_background.dart';
import '../../Auth_widgets/widgets/or_divider.dart';
import '../../Auth_widgets/widgets/primary_button.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _remember = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  // Google Sign-In
  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).signInWithGoogle();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Google login successful!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Dashboard navigation AuthWrapper handle karega.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Google login failed.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In cancelled or failed.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Email and Password Sign-In
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).login(
        email: _emailC.text.trim(),
        password: _passC.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Text('Login successful!'),
        ),
      );

      // Dashboard navigation AuthWrapper handle karega.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'Wrong email ';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Email ya password was wrong.';
          break;
        case 'invalid-email':
          message = 'Email address not  valid .';
          break;
        case 'user-disabled':
          message = 'Account was  disabled .';
          break;
        case 'too-many-requests':
          message = 'Try sometime later';
          break;
        default:
          message = 'Login failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 24,
              ),
              child: Column(
                children: [
                  const FadeSlide(
                    child: AppLogo(size: 84),
                  ),
                  const SizedBox(height: 18),
                  FadeSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      '  TrackFlow Login 🔐 ',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FadeSlide(
                    delay: const Duration(milliseconds: 160),
                    child: Text(
                      'Sign in to access your tasks and synced routines.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlide(
                    delay: const Duration(milliseconds: 240),
                    child: AuthCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            CustomTextField(
                              label: 'Email Address',
                              hint: 'name@example.com',
                              prefixIcon: Icons.mail_outline_rounded,
                              controller: _emailC,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email was compulsory';
                                }

                                if (!RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(v.trim())) {
                                  return 'Sahi email daalo';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              label: 'Password',
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline_rounded,
                              controller: _passC,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) =>
                              (v == null || v.length < 6)
                                  ? 'Kam se kam 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _remember,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(6),
                                    ),
                                    onChanged: (v) => setState(
                                          () => _remember = v ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remember me',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const ForgotPasswordScreen(),
                                    ),
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            PrimaryButton(
                              label: 'Sign In',
                              isLoading: _loading,
                              onPressed: _loading ? null : _signIn,
                            ),
                            const SizedBox(height: 18),
                            const OrDivider(),
                            const SizedBox(height: 18),
                            GoogleButton(
                              onPressed:
                              _loading ? null : _signInWithGoogle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeSlide(
                    delay: const Duration(milliseconds: 360),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAccountScreen(),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
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
    );
  }
}
