import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/auth/presentation/providers/app_providers.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/account_access_gate.dart';
import 'features/customer/presentation/screens/customer_home_screen.dart';
import 'features/professional/presentation/screens/professional_home_screen.dart';
import 'features/contractor/presentation/screens/contractor_home_screen.dart';
import 'features/admin/presentation/screens/admin_home_screen.dart';
import 'shared/models/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: San3aApp()));
}

class San3aApp extends ConsumerStatefulWidget {
  const San3aApp({super.key});

  @override
  ConsumerState<San3aApp> createState() => _San3aAppState();
}

class _San3aAppState extends ConsumerState<San3aApp> {
  // Created once and stable across every rebuild of this widget (unlike a
  // key created inline in build), so the forced reset below always targets
  // the same Navigator.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // FirebaseAuth is the authoritative identity (see firebaseAuthUidProvider
    // / authIdentitySyncProvider in app_providers.dart). When it changes for
    // a reason this tab didn't itself initiate — most notably another
    // browser tab signing into a different account under this browser's
    // shared Auth session — force the navigation stack back to a single
    // fresh root so no previous account's screen stays reachable, including
    // via Back. Self-managed transitions (this tab's own login()/register()/
    // logout()) already drive their own navigation and are skipped here to
    // avoid a redundant reset racing them.
    ref.listen<AsyncValue<String?>>(firebaseAuthUidProvider, (previous, next) {
      final authNotifier = ref.read(authProvider.notifier);
      if (authNotifier.isSelfManagingTransition) return;
      final realUid = next.valueOrNull;
      final localId = ref.read(authProvider)?.id;
      if (realUid == localId) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const _HomeRouter()),
        (route) => false,
      );
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'San3a',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _HomeRouter(),
    );
  }
}

class _HomeRouter extends ConsumerWidget {
  const _HomeRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps authProvider synchronized to the real Firebase Auth identity —
    // watched here so the side effect stays alive for as long as any role
    // screen (or this loading state) is shown.
    ref.watch(authIdentitySyncProvider);

    final authNotifier = ref.read(authProvider.notifier);
    final firebaseUidAsync = ref.watch(firebaseAuthUidProvider);
    final user = ref.watch(authProvider);

    // While this tab's own login()/register()/logout() is actively driving
    // a transition, authProvider is already authoritative for what it's
    // doing — render it directly rather than waiting on the raw Firebase-
    // Auth-UID comparison below to catch up, so that call's own screen
    // (e.g. LoginScreen mid-submit) is never yanked out from under it.
    //
    // Otherwise, never render an interactive role screen while Firebase
    // Auth's own identity hasn't resolved yet, or while it disagrees with
    // the locally cached UserModel — a synchronization is in flight (see
    // authIdentitySyncProvider) and the old screen must not stay
    // interactive for even one frame past a real Firebase Auth UID change.
    final isSynchronized = authNotifier.isSelfManagingTransition ||
        (firebaseUidAsync.hasValue && firebaseUidAsync.valueOrNull == user?.id);
    if (!isSynchronized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) return const LoginScreen();

    switch (user.role) {
      case UserRole.customer:
        return const AccountAccessGate(child: CustomerHomeScreen());
      case UserRole.professional:
        return const AccountAccessGate(child: ProfessionalHomeScreen());
      case UserRole.contractor:
        return const AccountAccessGate(child: ContractorHomeScreen());
      case UserRole.admin:
        return const AccountAccessGate(child: AdminHomeScreen());
    }
  }
}
