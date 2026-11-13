
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../Statemanage_riverpod/provider/AuthServicesProvider.dart';
import '../../../app_file/theme_file/app_colors.dart';
import '../../Auth_widgets/widgets/auth_card.dart';
import '../../Auth_widgets/widgets/custom_text_field.dart';
import '../../Auth_widgets/widgets/fade_slide.dart';
import '../../Auth_widgets/widgets/gradient_background.dart';
import '../../Auth_widgets/widgets/or_divider.dart';
import '../../Auth_widgets/widgets/primary_button.dart';
import 'login_screen.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState
    extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();

  bool _agree = false;
  bool _loading = false;
  int _strength = 0;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  int _calcStrength(String p) {
    int s = 0;

    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(p)) s++;

    return s;
  }

  String get _strengthLabel =>
      const ['Too short', 'Weak', 'Okay', 'Good', 'Strong'][_strength];

  Color get _strengthColor {
    if (_strength <= 1) return AppColors.error;
    if (_strength == 2) return AppColors.warning;
    return AppColors.success;
  }

  // Create Account
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    try {
      await ref.read(authServiceProvider).signup(
        name: _nameC.text.trim(),
        email: _emailC.text.trim(),
        password: _passC.text,
      );

      // Firebase automatically login kar deta hai.
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Login screen par bhejo.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
            (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'weak-password':
          message = 'Please choose a stronger password.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email.';
          break;
        default:
          message = e.message ?? 'Account creation failed.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong.'),
          ),
        );
      }
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
          child: Column(
            children: [
              _TopBar(
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeSlide(
                        child: Text(
                          'Create Account 🚀',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeSlide(
                        delay: const Duration(milliseconds: 80),
                        child: Text(
                          'Start organizing your daily flow with calm, intelligent momentum.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeSlide(
                        delay: const Duration(milliseconds: 160),
                        child: AuthCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomTextField(
                                  label: 'Full Name',
                                  hint: 'Adarsh Gupta',
                                  prefixIcon: Icons.person_outline_rounded,
                                  controller: _nameC,
                                  validator: (v) =>
                                  (v == null || v.trim().length < 2)
                                      ? 'Naam daalo'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Work or Personal Email',
                                  hint: 'adarsh@trackflow.app',
                                  prefixIcon: Icons.mail_outline_rounded,
                                  controller: _emailC,
                                  keyboardType:
                                  TextInputType.emailAddress,
                                  validator: (v) => RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch((v ?? '').trim())
                                      ? null
                                      : 'Sahi email daalo',
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Password',
                                  hint: 'Min 8 characters',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  controller: _passC,
                                  isPassword: true,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (v) => setState(
                                        () => _strength = _calcStrength(v),
                                  ),
                                  validator: (v) =>
                                  (v == null || v.length < 8)
                                      ? 'Kam se kam 8 characters'
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                _StrengthMeter(
                                  strength: _strength,
                                  color: _strengthColor,
                                  label: _strengthLabel,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _agree,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),
                                        onChanged: (v) => setState(
                                              () => _agree = v ?? false,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          text: 'I agree to the ',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.4,
                                            color: colors.onSurfaceVariant,
                                          ),
                                          children: const [
                                            TextSpan(
                                              text: 'Terms of Service',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                PrimaryButton(
                                  label: 'Create Account',
                                  isLoading: _loading,
                                  onPressed:
                                  _agree ? _createAccount : null,
                                ),
                                const SizedBox(height: 18),
                                const OrDivider(text: 'Lets Go'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Text(
                                  'Sign In',
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
                      const SizedBox(height: 16),
                    ],
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

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: colors.onSurface,
            ),
          ),
          Text(
            'TrackFlow',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final int strength;
  final Color color;
  final String label;

  const _StrengthMeter({
    required this.strength,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  margin: EdgeInsets.only(
                    right: i == 3 ? 0 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: i < strength
                        ? color
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.shield_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
