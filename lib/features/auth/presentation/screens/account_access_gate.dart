// Single, reusable choke point for account-level restrictions (Admin Users
// → Suspend / Block). Wraps a role home screen: shows it normally, or shows
// a restriction screen instead of it while the signed-in user is blocked or
// actively suspended. Reused from both the cold-start router (main.dart)
// and the post-login/-register navigation (register_screen.dart's
// routeByRole) — the two places that already decide which screen a signed-in
// user lands on — so the check isn't duplicated across every role screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import 'login_screen.dart';

class AccountAccessGate extends ConsumerWidget {
  final Widget child;
  const AccountAccessGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // liveCurrentUserProvider streams users/{uid} directly, so a block or
    // suspension applied by an Admin while this user is already signed in
    // is picked up here without requiring a re-login. Falls back to the
    // cached authProvider snapshot while the stream is loading.
    final user = ref.watch(liveCurrentUserProvider).valueOrNull ??
        ref.watch(authProvider);

    if (user == null) return const LoginScreen();
    // Priority: Deactivated > Blocked > Actively Suspended > Active. A
    // deactivated account never reaches the Blocked/Suspended screens even
    // if isBlocked/suspendedUntil are also set — those are preserved
    // underneath and re-evaluated normally once the account is restored.
    if (user.isDeleted) {
      return _AccountRestrictedScreen(
          kind: _RestrictionKind.deleted, user: user);
    }
    if (user.isBlocked) {
      return _AccountRestrictedScreen(
          kind: _RestrictionKind.blocked, user: user);
    }
    if (user.isActivelySuspended) {
      return _AccountRestrictedScreen(
          kind: _RestrictionKind.suspended, user: user);
    }
    return child;
  }
}

enum _RestrictionKind { deleted, blocked, suspended }

class _AccountRestrictedScreen extends ConsumerWidget {
  final _RestrictionKind kind;
  final UserModel user;
  const _AccountRestrictedScreen({required this.kind, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = kind == _RestrictionKind.blocked;
    final isDeleted = kind == _RestrictionKind.deleted;
    final color = isDeleted
        ? AppColors.textSecondary
        : isBlocked
            ? AppColors.error
            : const Color(0xFFF97316);
    final until = user.suspendedUntil;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(
                      isDeleted
                          ? Icons.no_accounts_rounded
                          : isBlocked
                              ? Icons.block_rounded
                              : Icons.pause_circle_outline_rounded,
                      color: color,
                      size: 42),
                ),
                const SizedBox(height: 24),
                Text(
                  isDeleted
                      ? 'Account Deactivated'
                      : isBlocked
                          ? 'Account Blocked'
                          : 'Account Temporarily Suspended',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  isDeleted
                      ? 'Your account has been deactivated by an administrator.'
                      : isBlocked
                          ? 'Your account has been blocked by an administrator. You will not be able to use the app while this is in effect.'
                          : 'Your account has been temporarily suspended by an administrator.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                if (isDeleted) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Please contact support if you believe this was a mistake.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                ],
                if (!isDeleted && !isBlocked && until != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.25))),
                    child: Text(
                      'Suspended until ${until.day}/${until.month}/${until.year}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Logout',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
