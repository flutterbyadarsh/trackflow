
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:trackflow/Statemanage_riverpod/provider/profile_provider.dart';
import 'package:trackflow/Statemanage_riverpod/provider/AuthServicesProvider.dart';

import '../Statemanage_riverpod/auth services/notification_service.dart';
import '../Statemanage_riverpod/database/category_database.dart';
import '../Statemanage_riverpod/database/task_database.dart';
import '../Statemanage_riverpod/provider/task_provider.dart';
import '../Statemanage_riverpod/provider/theme_provider.dart';
import '../notes/note_database/database.dart';
import '../notes/note_database/notes_sync_controller.dart';
import '../AuthFile/authWrapper.dart';
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const Color primaryColor = Color(0xFF5B4BDB);

  bool _isDeletingAccount = false;

  // ----------------------------------------------------------
  // Delete Account Confirmation
  // ----------------------------------------------------------

  Future<void> _showDeleteAccountDialog() async {
    if (_isDeletingAccount) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This will permanently delete your account, '
                'tasks, notes, categories, notifications and related data. '
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    await _deleteAccount();
  }

  // ----------------------------------------------------------
  // Delete Account
  // ----------------------------------------------------------

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() => _isDeletingAccount = true);

    try {
      final isGoogleUser = user.providerData.any(
            (provider) => provider.providerId == 'google.com',
      );

      String? password;

      // Email/password account ke liye password confirmation.
      if (!isGoogleUser) {
        password = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            return const _PasswordConfirmDialog();
          },
        );

        if (password == null || password.isEmpty) return;



      }

      await ref.read(authServiceProvider).deleteAccount(
        useGoogle: isGoogleUser,
        password: password,

        // Pause all background sync operations.
        pauseSync: () async {
          await ref
              .read(taskProvider.notifier)
              .pauseForAccountDeletion();

          await NotesSyncController.instance.pauseAndWait();
        },

        // Clear only current user's local SQLite data.
        clearLocalData: (uid) async {
          await TaskDatabase.instance.clearUserTaskData(uid);

          await NotesDatabase.instance.clearUserNoteData(
            userId: uid,
          );

          await CategoryDatabase.instance.clearUserCategories(
            uid,
          );
        },

        // Cancel scheduled local notifications.
        cancelNotifications: () async {
          await NotificationService.cancelAllNotifications();
        },
      );

      if (!mounted) return;

// Clear all previous screens and open AuthWrapper.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthWrapper(),
        ),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = 'Account deletion failed.';

      // Wrong password ya invalid credential ke liye custom clear message
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = 'Wrong password! please enter the correct password ';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'For security reasons, please log in again before deleting your account. ';
      } else {
        errorMessage = e.message ?? errorMessage;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account deletion failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }


  }

  // ----------------------------------------------------------
  // Logout
  // ----------------------------------------------------------

  Future<void> _logout() async {
    try {
      debugPrint('Logout started');

      await ref.read(authServiceProvider).logout();

      debugPrint('Firebase logout successful');

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase logout error: ${e.code}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Logout failed.'),
        ),
      );
    } catch (e) {
      debugPrint('Logout error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // Logout Confirmation
  // ----------------------------------------------------------

  void _showLogoutDialog() {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Log out?',
          style: TextStyle(color: colors.onSurface),
        ),
        content: Text(
          'Are you sure you want to log out of TrackFlow?',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // Build
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final profileAsync = ref.watch(profileProvider);
    final selectedTheme = ref.watch(themeModeProvider);

    final profileData = profileAsync.when(
      data: (snapshot) => snapshot?.data(),
      loading: () => null,
      error: (error, stackTrace) => null,
    );

    final currentUser = FirebaseAuth.instance.currentUser;

    final name =
    profileData?['name']?.toString().trim().isNotEmpty == true
        ? profileData!['name'].toString()
        : currentUser?.displayName ?? 'User';

    final email =
        profileData?['email']?.toString() ??
            currentUser?.email ??
            '';

    final firestorePhoto = profileData?['photoUrl']?.toString();

    final photoUrl =
    (firestorePhoto != null && firestorePhoto.isNotEmpty)
        ? firestorePhoto
        : currentUser?.photoURL;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 21,
                      color: colors.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'My Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.outlineVariant,
                      ),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7163E8),
                      Color(0xFF5142C9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFFE7E2FF),
                      backgroundImage:
                      photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: primaryColor,
                      )
                          : null,
                    ),

                    const SizedBox(height: 15),

                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Free Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Delete Account Option
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.25),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                    size: 26,
                  ),
                  title: const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Permanently remove your account',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                  onTap: _isDeletingAccount
                      ? null
                      : _showDeleteAccountDialog,
                ),
              ),

              const SizedBox(height: 28),

              // Preferences
              Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),

              // Appearance Settings
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.palette_outlined,
                          color: primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Appearance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        'Choose your preferred theme',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        _themeOption(
                          icon: Icons.light_mode_rounded,
                          label: 'Light',
                          mode: ThemeMode.light,
                          selectedTheme: selectedTheme,
                        ),
                        const SizedBox(width: 8),
                        _themeOption(
                          icon: Icons.dark_mode_rounded,
                          label: 'Dark',
                          mode: ThemeMode.dark,
                          selectedTheme: selectedTheme,
                        ),
                        const SizedBox(width: 8),
                        _themeOption(
                          icon: Icons.settings_suggest_rounded,
                          label: 'System',
                          mode: ThemeMode.system,
                          selectedTheme: selectedTheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE05260),
                    side: BorderSide(
                      color: colors.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Footer
              Center(
                child: Text(
                  'TrackFlow • Stay focused, stay organized',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // Theme Selection Option
  // ----------------------------------------------------------

  Widget _themeOption({
    required IconData icon,
    required String label,
    required ThemeMode mode,
    required ThemeMode selectedTheme,
  }) {
    final colors = Theme.of(context).colorScheme;

    final bool isSelected = selectedTheme == mode;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? colors.primary
                    : colors.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: isSelected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordConfirmDialog extends StatefulWidget {
  const _PasswordConfirmDialog();

  @override
  State<_PasswordConfirmDialog> createState() =>
      _PasswordConfirmDialogState();
}

class _PasswordConfirmDialogState
    extends State<_PasswordConfirmDialog> {
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your password'),
      content: TextField(
        controller: _passwordController,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(
              context,
              _passwordController.text,
            );
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
