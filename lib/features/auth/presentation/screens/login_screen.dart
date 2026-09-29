import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/helpers/location_helper.dart';
import '../providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import 'register_screen.dart' show routeByRole, validatePassword;

// ─── Premium Auth Palette ─────────────────────────────────────────────────────
// The single design-system source of truth for the ENTIRE authentication
// wizard (login, role picker, register, pro/contractor details, done) — no
// other color palette exists in this file anymore.
class _LK {
  _LK._();
  static const navyDark = Color(0xFF0F1B3D); // hero gradient top
  static const navyDeep = Color(0xFF0A1330); // hero gradient bottom
  static const royalBlue = Color(0xFF3B5EDB); // primary accent / CTA gradient
  static const glowBlue = Color(0xFF5B8DEF); // glow / focus / particles
  static const pageBg = Color(0xFFF5F7FA); // very light gray page background
  static const cardBg = Color(0xFFFFFFFF); // floating card
  static const cardBgDark = Color(0xFF161F38); // floating card, dark mode
  static const fieldBg = Color(0xFFF7F9FC); // text field fill
  static const fieldBgDark = Color(0xFF1C2540); // text field fill, dark mode
  static const border = Color(0xFFE3E8F0); // very light border
  static const borderDark = Color(0xFF2A3454);
  static const textPrimary = Color(0xFF0F1B3D);
  static const textSecondary = Color(0xFF6B7280);
}

// Emoji + label for the premium glass role-badge capsule shown on the
// register/pro-details heroes.
String _roleEmoji(UserRole r) {
  switch (r) {
    case UserRole.professional:
      return '🔧';
    case UserRole.contractor:
      return '🏗';
    default:
      return '🏠';
  }
}

String _roleLabel(UserRole r, AppLocalizations l) {
  switch (r) {
    case UserRole.professional:
      return l.get('professional');
    case UserRole.contractor:
      return l.get('contractor');
    default:
      return l.get('customer');
  }
}

// ─── View enum ────────────────────────────────────────────────────────────────
enum _View { login, signUpPick, registerForm, proDetails, done }

// ─── Region keys ─────────────────────────────────────────────────────────────
const _regionKeys = [
  'north_country',
  'south_country',
  'west_country',
  'east_country',
  'jerusalem',
  'haifa',
  'tel_aviv',
  'nazareth',
  'other',
];

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  _View _view = _View.login;
  UserRole? _chosenRole;

  // Login
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();
  bool _showLoginPass = false;
  bool _loginLoading = false;

  // Register step 1
  final _regFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _showRegPass = false;
  bool _regLoading = false;
  bool _fetchingLocation = false;
  String _detectedCity = '';
  String _detectedStreet = '';

  // Pro/Contractor step 2
  final _proFormKey = GlobalKey<FormState>();
  final _expCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  List<String> _selectedRegions = [];
  List<String> _selectedSpecialties = [];
  final _customRegionCtrl = TextEditingController();
  bool _proLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPassCtrl.dispose();
    _nameCtrl.dispose();
    _regEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _regPassCtrl.dispose();
    _addressCtrl.dispose();
    _expCtrl.dispose();
    _descCtrl.dispose();
    _companyCtrl.dispose();
    _customRegionCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  // Admin users are identified by role == 'admin' in their Firestore document.
  // No hardcoded credentials — all auth goes through Firebase.
  void _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final email = _loginEmailCtrl.text.trim();
    final pass = _loginPassCtrl.text.trim();
    setState(() => _loginLoading = true);
    try {
      await ref.read(authProvider.notifier).login(email, pass);
      if (!mounted) return;
      final user = ref.read(authProvider);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => routeByRole(user)));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_firebaseErrorMessage(e.code)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak (min 6 characters).';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }

  // ── GPS ───────────────────────────────────────────────────────────────────
  Future<void> _detectAddress() async {
    if (_fetchingLocation) return;
    setState(() => _fetchingLocation = true);
    try {
      final r = await LocationHelper.getCurrentAddress();
      setState(() {
        _detectedCity = r.city;
        _detectedStreet = r.streetNumber;
        _addressCtrl.text = r.fullAddress;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  // ── Register customer ─────────────────────────────────────────────────────
  void _registerCustomer() async {
    if (!_regFormKey.currentState!.validate()) return;
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter your address or tap the GPS button.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _regLoading = true);
    try {
      await ref.read(authProvider.notifier).register(
            fullName: _nameCtrl.text.trim(),
            email: _regEmailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _regPassCtrl.text.trim(),
            role: UserRole.customer,
            city: _detectedCity.isNotEmpty
                ? _detectedCity
                : _addressCtrl.text.trim(),
            streetNumber: _detectedStreet,
          );
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      setState(() => _view = _View.done);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.get('registration_success')),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2)));
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      final user = ref.read(authProvider);
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => routeByRole(user)), (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_firebaseErrorMessage(e.code)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  // ── Advance from Account Info step to Pro/Contractor Details step ────────
  // Guards the registerForm → proDetails transition: the step must validate
  // before the wizard is allowed to move on, same as _registerCustomer()
  // already does for the customer role.
  void _advanceToProDetails() {
    if (!_regFormKey.currentState!.validate()) return;
    _setView(_View.proDetails);
  }

  // ── Register pro/contractor ───────────────────────────────────────────────
  void _registerPro() async {
    if (!_proFormKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    if (_selectedRegions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select at least one work area.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3)));
      return;
    }
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.get('select_specialty_error_inline')),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3)));
      return;
    }
    setState(() => _proLoading = true);
    final workArea = _selectedRegions
        .map((k) => k == 'other' ? _customRegionCtrl.text.trim() : k)
        .join(',');
    try {
      await ref.read(authProvider.notifier).register(
            fullName: _nameCtrl.text.trim(),
            email: _regEmailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _regPassCtrl.text.trim(),
            role: _chosenRole!,
            workArea: workArea,
            experienceYears: int.tryParse(_expCtrl.text),
            specialty: _selectedSpecialties.isNotEmpty
                ? _selectedSpecialties.first
                : '',
            specialties: _selectedSpecialties,
            description: _descCtrl.text.trim(),
            companyName: _chosenRole == UserRole.contractor
                ? _companyCtrl.text.trim()
                : null,
          );
      if (!mounted) return;
      setState(() => _view = _View.done);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.get('registration_success')),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2)));
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      final user = ref.read(authProvider);
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => routeByRole(user)), (r) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_firebaseErrorMessage(e.code)),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3)));
    } finally {
      if (mounted) setState(() => _proLoading = false);
    }
  }

  // ── Region picker display ─────────────────────────────────────────────────
  String _regionsDisplay(AppLocalizations l) {
    if (_selectedRegions.isEmpty) return '';
    return _selectedRegions.map((k) {
      if (k == 'other') {
        final t = _customRegionCtrl.text.trim();
        return t.isEmpty ? l.get('region_other') : t;
      }
      return l.get('region_$k');
    }).join(', ');
  }

  // ── Region picker (slide from right) ─────────────────────────────────────
  void _showRegionPicker(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<String> sheetSel = List.from(_selectedRegions);
    final customCtrl = TextEditingController(text: _customRegionCtrl.text);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Region',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      pageBuilder: (ctx, _, __) => StatefulBuilder(
        builder: (ctx, setSt) {
          final bg = isDark ? _LK.cardBgDark : Colors.white;
          final txt = isDark ? Colors.white : _LK.textPrimary;
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.82,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 28,
                        offset: const Offset(-6, 0))
                  ],
                ),
                child: SafeArea(
                    child: Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_LK.navyDark, _LK.navyDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.only(topLeft: Radius.circular(28)),
                    ),
                    child: Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.location_on_outlined,
                              color: Colors.white, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Work Areas',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text('Select one or more',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.72))),
                          ])),
                      GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 17))),
                    ]),
                  ),
                  // List
                  Expanded(
                      child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      ..._regionKeys.map((key) {
                        final isSel = sheetSel.contains(key);
                        return GestureDetector(
                          onTap: () => setSt(() {
                            if (isSel) {
                              sheetSel.remove(key);
                              if (key == 'other') customCtrl.clear();
                            } else
                              sheetSel.add(key);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 130),
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? _LK.royalBlue.withOpacity(0.12)
                                  : (isDark ? _LK.fieldBgDark : _LK.fieldBg),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel ? _LK.royalBlue : _LK.border,
                                width: isSel ? 2 : 1.5,
                              ),
                            ),
                            child: Row(children: [
                              Expanded(
                                  child: Text(l.get('region_$key'),
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isSel ? _LK.royalBlue : txt))),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 130),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  gradient: isSel
                                      ? const LinearGradient(
                                          colors: [_LK.royalBlue, _LK.navyDark])
                                      : null,
                                  color: isSel ? null : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: isSel
                                          ? Colors.transparent
                                          : _LK.border,
                                      width: 2),
                                ),
                                child: isSel
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 14)
                                    : null,
                              ),
                            ]),
                          ),
                        );
                      }),
                      if (sheetSel.contains('other')) ...[
                        const SizedBox(height: 4),
                        TextField(
                          controller: customCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type your region...',
                            hintStyle:
                                const TextStyle(color: _LK.textSecondary),
                            prefixIcon: const Icon(Icons.edit_location_outlined,
                                color: _LK.royalBlue, size: 20),
                            filled: true,
                            fillColor: isDark ? _LK.fieldBgDark : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: const BorderSide(
                                    color: _LK.royalBlue, width: 2)),
                          ),
                          style: TextStyle(
                              fontSize: 14,
                              color: txt,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ]),
                  )),
                  // Confirm
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    child: _SheetConfirmButton(
                      label: 'Confirm',
                      onTap: () {
                        setState(() {
                          _selectedRegions = List.from(sheetSel);
                          _customRegionCtrl.text = customCtrl.text;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ])),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── More specialties picker (slide from left) ─────────────────────────────
  // Mirrors _showRegionPicker's visual pattern (same header/list/confirm
  // shell, header gradient, chip styling) but enters from the LEFT and shows
  // the FULL eligible category set from categoriesProvider (not just the
  // categories omitted from the main chip row) so the user can see and
  // manage the complete current specialty selection from this panel.
  // Tapping a category commits directly to _selectedSpecialties, exactly as
  // the previous bottom-sheet implementation did — no new save/cancel
  // semantics are introduced.
  void _showMoreSpecialties(BuildContext context, AppLocalizations l,
      AsyncValue<List<CategoryModel>> categoriesAsync) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCategories = categoriesAsync.value ?? [];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Categories',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      pageBuilder: (ctx, _, __) => StatefulBuilder(
        builder: (ctx, setSt) {
          final bg = isDark ? _LK.cardBgDark : Colors.white;
          return Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.82,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 28,
                        offset: const Offset(6, 0))
                  ],
                ),
                child: SafeArea(
                    child: Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_LK.navyDark, _LK.navyDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.only(topRight: Radius.circular(28)),
                    ),
                    child: Row(children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.category_outlined,
                              color: Colors.white, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('All Categories',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text('Select one or more',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.72))),
                          ])),
                      GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 17))),
                    ]),
                  ),
                  // Body
                  Expanded(
                    child: (categoriesAsync.isLoading && allCategories.isEmpty)
                        ? Center(
                            child: Text('Loading categories...',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : _LK.textSecondary)))
                        : (categoriesAsync.hasError && allCategories.isEmpty)
                            ? Center(
                                child: Text('Failed to load categories',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : _LK.textSecondary)))
                            : allCategories.isEmpty
                                ? Center(
                                    child: Text('No categories available',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white70
                                                : _LK.textSecondary)))
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.all(14),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: allCategories.map((cat) {
                                        final key = cat.nameKey;
                                        final sel =
                                            _selectedSpecialties.contains(key);
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (sel) {
                                                _selectedSpecialties
                                                    .remove(key);
                                              } else {
                                                _selectedSpecialties.add(key);
                                              }
                                            });
                                            setSt(() {});
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 140),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 13, vertical: 9),
                                            decoration: BoxDecoration(
                                              color: sel
                                                  ? _LK.royalBlue
                                                  : (isDark
                                                      ? _LK.fieldBgDark
                                                      : _LK.fieldBg),
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              border: Border.all(
                                                color: sel
                                                    ? _LK.royalBlue
                                                    : _LK.border,
                                                width: sel ? 2 : 1.5,
                                              ),
                                            ),
                                            child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(cat.icon,
                                                      style: const TextStyle(
                                                          fontSize: 15)),
                                                  const SizedBox(width: 6),
                                                  Text(_catLabel(key, l),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: sel
                                                              ? Colors.white
                                                              : (isDark
                                                                  ? Colors
                                                                      .white70
                                                                  : _LK
                                                                      .textSecondary))),
                                                  if (sel) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                        Icons.check_rounded,
                                                        color: Colors.white,
                                                        size: 13)
                                                  ],
                                                ]),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                  ),
                  // Save
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    child: _SheetConfirmButton(
                      label: l.get('save'),
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ),
                ])),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── View navigation ───────────────────────────────────────────────────────
  void _setView(_View v, {UserRole? role}) => setState(() {
        _view = v;
        if (role != null) _chosenRole = role;
      });

  // ─── build ────────────────────────────────────────────────────────────────
  // Every _View now renders through its own premium scaffold — one shared
  // design system (_LK palette, hero, progress bar, form card, fields,
  // buttons) across the entire wizard. The old vertical sidebar shell has
  // been fully removed (see the premium widgets section at the end of this
  // file). Each branch below still drives the exact same controllers,
  // validators, and _setView()/_login()/_registerCustomer()/_registerPro()
  // calls the wizard already had — this method only decides which
  // presentation to show for the current _view.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (_view) {
      case _View.login:
        return _buildPremiumLoginScaffold(isDark);
      case _View.signUpPick:
        return _buildPremiumSignUpPickScaffold(isDark);
      case _View.registerForm:
        return _buildPremiumRegisterScaffold(isDark);
      case _View.proDetails:
        return _buildPremiumProDetailsScaffold(isDark);
      case _View.done:
        return _buildPremiumDoneScaffold(isDark);
    }
  }

  // ─── New premium hero + floating-card login screen ─────────────────────────
  // Only ever rendered for _View.login (see build() above). Reuses the exact
  // same form key, controllers, validators, and _login()/_setView() calls as
  // the original login panel — this method and _PremiumLoginView below are
  // presentation-only and touch no auth/business logic.
  Widget _buildPremiumLoginScaffold(bool isDark) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _LK.pageBg,
      body: _PremiumLoginView(
        isDark: isDark,
        l: l,
        formKey: _loginFormKey,
        emailCtrl: _loginEmailCtrl,
        passCtrl: _loginPassCtrl,
        showPass: _showLoginPass,
        loading: _loginLoading,
        onTogglePass: () => setState(() => _showLoginPass = !_showLoginPass),
        onLogin: _login,
        onCreateAccount: () => _setView(_View.signUpPick),
        fadeAnimation: _fadeAnim,
      ),
    );
  }

  // ─── New premium role-picker ("Choose Your Account Type") screen ──────────
  // Only ever rendered for _View.signUpPick (see build() above). onPick and
  // onBack are the exact same _setView(...) calls the original
  // _SignUpPickPanel / _LeftPanel already used — presentation-only, no new
  // navigation/business logic.
  Widget _buildPremiumSignUpPickScaffold(bool isDark) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _LK.pageBg,
      body: _PremiumSignUpPickView(
        isDark: isDark,
        l: l,
        onBack: () => _setView(_View.login),
        onPick: (role) => _setView(_View.registerForm, role: role),
      ),
    );
  }

  // ─── New premium "Create Account" (register step 1) screen ────────────────
  // Only ever rendered for _View.registerForm. Same form key, controllers,
  // validators and onSubmit routing (_registerCustomer for Customer, or
  // advance to proDetails for Professional/Contractor) the original
  // _RegisterPanel already used.
  Widget _buildPremiumRegisterScaffold(bool isDark) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _LK.pageBg,
      body: _PremiumRegisterView(
        isDark: isDark,
        l: l,
        role: _chosenRole ?? UserRole.customer,
        formKey: _regFormKey,
        nameCtrl: _nameCtrl,
        emailCtrl: _regEmailCtrl,
        phoneCtrl: _phoneCtrl,
        passCtrl: _regPassCtrl,
        addressCtrl: _addressCtrl,
        showPass: _showRegPass,
        loading: _regLoading,
        fetchingLocation: _fetchingLocation,
        onTogglePass: () => setState(() => _showRegPass = !_showRegPass),
        onDetectAddress: _detectAddress,
        onBack: () => _setView(_View.signUpPick),
        onSubmit: _chosenRole == UserRole.customer
            ? _registerCustomer
            : _advanceToProDetails,
      ),
    );
  }

  // ─── New premium "Professional/Contractor Details" (register step 2) ──────
  // Only ever rendered for _View.proDetails. Same form key, controllers,
  // selection state, region/specialty picker callbacks and _registerPro()
  // call the original _ProDetailsPanel already used.
  Widget _buildPremiumProDetailsScaffold(bool isDark) {
    final l = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      backgroundColor: _LK.pageBg,
      body: _PremiumProDetailsView(
        isDark: isDark,
        l: l,
        role: _chosenRole ?? UserRole.professional,
        formKey: _proFormKey,
        expCtrl: _expCtrl,
        descCtrl: _descCtrl,
        companyCtrl: _companyCtrl,
        selectedRegions: _selectedRegions,
        selectedSpecialties: _selectedSpecialties,
        regionsDisplay: _regionsDisplay(l),
        loading: _proLoading,
        categoriesAsync: categoriesAsync,
        onBack: () => _setView(_View.registerForm),
        onShowRegionPicker: () => _showRegionPicker(context, l),
        onShowMoreSpecialties: () =>
            _showMoreSpecialties(context, l, categoriesAsync),
        onSpecialtyChanged: (list) =>
            setState(() => _selectedSpecialties = list),
        onSubmit: _registerPro,
      ),
    );
  }

  // ─── New premium "Done" screen ─────────────────────────────────────────────
  // Only ever rendered for _View.done. Purely presentational — the actual
  // navigation away from this screen (Navigator.pushAndRemoveUntil) already
  // happens inside _registerCustomer()/_registerPro() after a short delay,
  // completely unchanged.
  Widget _buildPremiumDoneScaffold(bool isDark) {
    return Scaffold(
      backgroundColor: _LK.pageBg,
      body: const _PremiumDoneView(),
    );
  }
}

// ─── LOGIN PANEL ──────────────────────────────────────────────────────────────
// Returns the localised label for a category nameKey.
// Falls back to a human-readable version of the key if no translation exists
// (e.g. "dckjdvjd" -> "Dckjdvjd", "test_signup" -> "Test Signup").
String _catLabel(String nameKey, AppLocalizations l) {
  final localized = l.get(nameKey);
  if (localized == nameKey) {
    return nameKey
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
  return localized;
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM LOGIN VIEW — Hero + floating-card design (Uber/Linear/Stripe/
// Notion/Airbnb style), rendered only for _View.login (see
// _LoginScreenState._buildPremiumLoginScaffold above). Every widget below is
// presentation-only: all callbacks it receives are the exact same
// controllers/methods _LoginScreenState already owned before this redesign
// (_login, the show/hide toggle, _setView) — nothing here calls Firebase,
// a provider, or introduces any new auth/business logic, except "Forgot
// Password?" which opens the self-contained _ForgotPasswordSheet below (its
// own Firebase Auth password-reset call, isolated from the login/register
// flow). San3a supports Email/Password authentication only — no Google
// sign-in.
// ═══════════════════════════════════════════════════════════════════════════
class _PremiumLoginView extends StatefulWidget {
  final bool isDark;
  final AppLocalizations l;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final bool showPass, loading;
  final VoidCallback onTogglePass, onLogin, onCreateAccount;
  final Animation<double> fadeAnimation;
  const _PremiumLoginView({
    required this.isDark,
    required this.l,
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.showPass,
    required this.loading,
    required this.onTogglePass,
    required this.onLogin,
    required this.onCreateAccount,
    required this.fadeAnimation,
  });

  @override
  State<_PremiumLoginView> createState() => _PremiumLoginViewState();
}

class _PremiumLoginViewState extends State<_PremiumLoginView>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _cardFadeAnim;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _cardFadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;
    final heroHeight = (size.height * 0.42).clamp(300.0, 420.0);

    return FadeTransition(
      opacity: widget.fadeAnimation,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LoginHero(
              height: heroHeight + topInset,
              topInset: topInset,
              floatAnim: _floatAnim,
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _cardFadeAnim,
                        child: _LoginCard(
                          isDark: widget.isDark,
                          l: l,
                          formKey: widget.formKey,
                          emailCtrl: widget.emailCtrl,
                          passCtrl: widget.passCtrl,
                          showPass: widget.showPass,
                          loading: widget.loading,
                          onTogglePass: widget.onTogglePass,
                          onLogin: widget.onLogin,
                          onCreateAccount: widget.onCreateAccount,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ─── Hero section (~40% of the screen) ────────────────────────────────────────
class _LoginHero extends StatelessWidget {
  final double height, topInset;
  final Animation<double> floatAnim;
  const _LoginHero(
      {required this.height, required this.topInset, required this.floatAnim});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_LK.navyDark, _LK.navyDeep],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -50,
              child: AnimatedBuilder(
                animation: floatAnim,
                builder: (_, child) => Transform.translate(
                    offset: Offset(0, floatAnim.value), child: child),
                child:
                    _GlowBlob(color: _LK.glowBlue.withOpacity(0.35), size: 220),
              ),
            ),
            Positioned(
              bottom: 10,
              left: -40,
              child:
                  _GlowBlob(color: _LK.royalBlue.withOpacity(0.22), size: 160),
            ),
            Positioned.fill(child: CustomPaint(painter: _HeroSkylinePainter())),
            Positioned(
              bottom: 6,
              right: 14,
              child: Icon(Icons.architecture_rounded,
                  size: 74, color: Colors.white.withOpacity(0.05)),
            ),
            const Positioned(
                top: 60, left: 40, child: _Particle(size: 4, opacity: 0.55)),
            const Positioned(
                top: 110, right: 70, child: _Particle(size: 3, opacity: 0.45)),
            const Positioned(
                top: 40, right: 120, child: _Particle(size: 5, opacity: 0.35)),
            const Positioned(
                bottom: 90, left: 100, child: _Particle(size: 3, opacity: 0.5)),
            const Positioned(
                bottom: 130,
                right: 40,
                child: _Particle(size: 4, opacity: 0.4)),
            Positioned.fill(
              child: Padding(
                padding:
                    EdgeInsets.only(top: topInset + 18, left: 24, right: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: floatAnim,
                      builder: (_, child) => Transform.translate(
                          offset: Offset(0, floatAnim.value * 0.6),
                          child: child),
                      child: const _HeroLogoBadge(),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('San',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1)),
                        Text('3',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: _LK.glowBlue,
                                height: 1)),
                        Text('a',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.4,
                                height: 1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Professional Building Services',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.65),
                            letterSpacing: 0.4)),
                    const SizedBox(height: 18),
                    const Text('Welcome Back 👋',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to manage your projects,\nworkers and customers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.white.withOpacity(0.68)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _HeroLogoBadge extends StatelessWidget {
  const _HeroLogoBadge();
  @override
  Widget build(BuildContext context) => Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.10),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.4),
          boxShadow: [
            BoxShadow(
                color: _LK.glowBlue.withOpacity(0.45),
                blurRadius: 28,
                spreadRadius: 2),
          ],
        ),
        child: Center(
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_LK.navyDark, _LK.royalBlue],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Text(
                  'S',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ─── Forgot Password ────────────────────────────────────────────────────────
// Opens a small, self-contained reset-password sheet. Its Firebase Auth call
// (sendPasswordResetEmail) is entirely local to this sheet — it never signs
// the user in, never touches Firestore, and never changes global auth state.
void _showForgotPasswordSheet(BuildContext context, bool isDark,
    AppLocalizations l, String prefillEmail) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _ForgotPasswordSheet(isDark: isDark, l: l, initialEmail: prefillEmail),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  final bool isDark;
  final AppLocalizations l;
  final String initialEmail;
  const _ForgotPasswordSheet(
      {required this.isDark, required this.l, required this.initialEmail});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    setState(() => _loading = true);

    const genericSentMessage =
        "If an account exists for this email, a password reset link has been sent.";
    const genericFailureMessage =
        'Unable to send the reset email right now. Please try again.';

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // 'user-not-found' would reveal account existence if surfaced as an
      // error — treat it the same as success so the response stays generic.
      if (e.code != 'user-not-found') {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(genericFailureMessage),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating));
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(genericFailureMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating));
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(genericSentMessage),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final isDark = widget.isDark;
    final bg = isDark ? _LK.cardBgDark : Colors.white;
    final txt = isDark ? Colors.white : _LK.textPrimary;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _LK.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: _LK.royalBlue.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: _LK.royalBlue, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text('Reset Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: txt)),
              const SizedBox(height: 8),
              Text(
                "Enter your email and we'll send you a password reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.white70 : _LK.textSecondary),
              ),
              const SizedBox(height: 22),
              _PremiumField(
                controller: _emailCtrl,
                isDark: isDark,
                hint: 'your@email.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l.get('required_email');
                  }
                  if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                      .hasMatch(v.trim())) {
                    return l.get('invalid_email');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _PremiumPrimaryButton(
                loading: _loading,
                onTap: _loading ? null : _submit,
                label: 'Send Reset Link',
                icon: Icons.send_rounded,
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white70 : _LK.textSecondary)),
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

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ));
}

class _Particle extends StatelessWidget {
  final double size, opacity;
  const _Particle({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _LK.glowBlue.withOpacity(opacity),
        boxShadow: [
          BoxShadow(
              color: _LK.glowBlue.withOpacity(opacity * 0.8),
              blurRadius: 6,
              spreadRadius: 1),
        ],
      ));
}

// Abstract construction skyline + crane silhouette + thin blueprint lines.
// Deliberately subtle/low-opacity — never distracts from the hero text.
class _HeroSkylinePainter extends CustomPainter {
  const _HeroSkylinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final skylinePaint = Paint()..color = Colors.white.withOpacity(0.055);
    final heights = [
      0.22,
      0.30,
      0.18,
      0.34,
      0.24,
      0.40,
      0.20,
      0.28,
      0.16,
      0.32
    ];
    final blockWidth = w / heights.length;
    final path = Path()..moveTo(0, h);
    double x = 0;
    for (final f in heights) {
      final bh = h * f;
      path.lineTo(x, h - bh);
      path.lineTo(x + blockWidth * 0.82, h - bh);
      x += blockWidth;
    }
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, skylinePaint);

    final cranePaint = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final baseX = w * 0.80;
    final topY = h * 0.16;
    canvas.drawLine(Offset(baseX, h * 0.62), Offset(baseX, topY), cranePaint);
    canvas.drawLine(Offset(baseX, topY),
        Offset(baseX + w * 0.15, topY + h * 0.02), cranePaint);
    canvas.drawLine(Offset(baseX, topY),
        Offset(baseX - w * 0.06, topY + h * 0.05), cranePaint);
    canvas.drawLine(Offset(baseX + w * 0.13, topY + h * 0.02),
        Offset(baseX + w * 0.13, topY + h * 0.14), cranePaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final yy = h * (0.28 + i * 0.14);
      canvas.drawLine(
          Offset(0, yy), Offset(w * 0.42, yy - h * 0.06), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroSkylinePainter oldDelegate) => false;
}

// ─── Floating login card ───────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final bool isDark, showPass, loading;
  final AppLocalizations l;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final VoidCallback onTogglePass, onLogin, onCreateAccount;
  const _LoginCard({
    required this.isDark,
    required this.l,
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.showPass,
    required this.loading,
    required this.onTogglePass,
    required this.onLogin,
    required this.onCreateAccount,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        decoration: BoxDecoration(
          color: isDark ? _LK.cardBgDark : _LK.cardBg,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _LK.navyDark.withOpacity(isDark ? 0.45 : 0.14),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PremiumField(
                controller: emailCtrl,
                isDark: isDark,
                hint: 'your@email.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l.get('required_email')
                    : null,
              ),
              const SizedBox(height: 14),
              _PremiumField(
                controller: passCtrl,
                isDark: isDark,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscureText: !showPass,
                suffixIcon: GestureDetector(
                  onTap: onTogglePass,
                  child: Icon(
                    showPass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: (isDark ? Colors.white : _LK.textSecondary)
                        .withOpacity(0.65),
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.get('required_password');
                  if (v.length < 6) return l.get('password_short');
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _showForgotPasswordSheet(
                      context, isDark, l, emailCtrl.text),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _LK.royalBlue),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PremiumPrimaryButton(
                  loading: loading, onTap: loading ? null : onLogin),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : _LK.textSecondary)),
                  GestureDetector(
                    onTap: onCreateAccount,
                    child: Text('Create Account',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _LK.royalBlue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

// ─── Premium text field — rounded, filled, blue glow on focus ─────────────────
class _PremiumField extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  const _PremiumField({
    required this.controller,
    required this.isDark,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });
  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final fill = isDark ? _LK.fieldBgDark : _LK.fieldBg;
    final borderColor =
        _focused ? _LK.royalBlue : (isDark ? _LK.borderDark : _LK.border);
    final textColor = isDark ? Colors.white : _LK.textPrimary;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: _focused ? 1.8 : 1.2),
          boxShadow: _focused
              ? [
                  BoxShadow(
                      color: _LK.royalBlue.withOpacity(0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 3))
                ]
              : const [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLines: widget.maxLines,
          style: TextStyle(
              fontSize: 14.5, color: textColor, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                TextStyle(color: isDark ? Colors.white38 : _LK.textSecondary),
            prefixIcon: widget.maxLines > 1
                ? null
                : Icon(widget.icon,
                    size: 20,
                    color: _focused
                        ? _LK.royalBlue
                        : (isDark ? Colors.white54 : _LK.textSecondary)),
            suffixIcon: widget.suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: widget.suffixIcon)
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
                horizontal: 16, vertical: widget.maxLines > 1 ? 16 : 18),
            errorStyle: const TextStyle(fontSize: 11, height: 0.8),
          ),
        ),
      ),
    );
  }
}

// ─── Primary Sign In button — blue gradient, arrow icon, press-scale ──────────
class _PremiumPrimaryButton extends StatefulWidget {
  final bool loading;
  final VoidCallback? onTap;
  // Defaults to 'Sign In' so the Login screen's existing call site is
  // unaffected; every other screen passes its own explicit label (Continue/
  // Next/Create Account/Finish) so the button text always matches what the
  // button actually does — it is never hardcoded regardless of what's asked
  // for, unlike the old _WhiteBtn3D it replaced.
  final String label;
  final IconData icon;
  const _PremiumPrimaryButton({
    required this.loading,
    required this.onTap,
    this.label = 'Sign In',
    this.icon = Icons.arrow_forward_rounded,
  });
  @override
  State<_PremiumPrimaryButton> createState() => _PremiumPrimaryButtonState();
}

class _PremiumPrimaryButtonState extends State<_PremiumPrimaryButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_LK.royalBlue, _LK.navyDark],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: _LK.royalBlue.withOpacity(0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.4))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.label,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2)),
                        const SizedBox(width: 8),
                        Icon(widget.icon, color: Colors.white, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      );
}

// ─── Small confirm button used inside the region/specialty picker sheets ──────
class _SheetConfirmButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SheetConfirmButton({required this.label, required this.onTap});
  @override
  State<_SheetConfirmButton> createState() => _SheetConfirmButtonState();
}

class _SheetConfirmButtonState extends State<_SheetConfirmButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_LK.royalBlue, _LK.navyDark],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _LK.royalBlue.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Center(
              child: Text(widget.label,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2)),
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM ROLE PICKER — "Choose Your Account Type" screen, rendered only for
// _View.signUpPick (see _LoginScreenState._buildPremiumSignUpPickScaffold
// above). Same visual identity as _PremiumLoginView: reuses _LK, _GlowBlob,
// _Particle, _HeroSkylinePainter and _HeroLogoBadge as-is rather than
// duplicating them. onPick/onBack are exactly the same _setView(...) calls
// the original _SignUpPickPanel/_LeftPanel already used — presentation-only,
// no new business/navigation logic.
// ═══════════════════════════════════════════════════════════════════════════
class _PremiumSignUpPickView extends StatefulWidget {
  final bool isDark;
  final AppLocalizations l;
  final VoidCallback onBack;
  final ValueChanged<UserRole> onPick;
  const _PremiumSignUpPickView({
    required this.isDark,
    required this.l,
    required this.onBack,
    required this.onPick,
  });

  @override
  State<_PremiumSignUpPickView> createState() => _PremiumSignUpPickViewState();
}

class _PremiumSignUpPickViewState extends State<_PremiumSignUpPickView>
    with TickerProviderStateMixin {
  static const _roleCount = 3;

  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  late final AnimationController _cardsCtrl;
  late final List<Animation<double>> _cardFade;
  late final List<Animation<Offset>> _cardSlide;

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _cardFade = List.generate(_roleCount, (i) {
      final start = 0.15 * i;
      return CurvedAnimation(
        parent: _cardsCtrl,
        curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
            curve: Curves.easeOut),
      );
    });
    _cardSlide = List.generate(_roleCount, (i) {
      final start = 0.15 * i;
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _cardsCtrl,
          curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ),
      );
    });

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardsCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;
    // Aligned to the same 24–28%-of-screen hero height used across the rest
    // of the wizard (register/pro-details) for full visual consistency.
    final heroHeight = (size.height * 0.26).clamp(190.0, 260.0);

    return Stack(
      children: [
        // Very soft, minimal decorative blobs on the light page background —
        // separate from the hero's own navy gradient above.
        Positioned(
          top: heroHeight * 0.55,
          right: -70,
          child: _GlowBlob(color: _LK.royalBlue.withOpacity(0.06), size: 240),
        ),
        Positioned(
          bottom: 30,
          left: -80,
          child: _GlowBlob(color: _LK.glowBlue.withOpacity(0.05), size: 220),
        ),
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _RolePickerHero(
                      height: heroHeight + topInset,
                      topInset: topInset,
                      floatAnim: _floatAnim,
                      onBack: widget.onBack,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _AuthProgressBar(
                              currentStep: 1,
                              totalSteps: 4,
                              currentLabel: 'Choose Role'),
                          const SizedBox(height: 26),
                          FadeTransition(
                            opacity: _cardFade[0],
                            child: SlideTransition(
                              position: _cardSlide[0],
                              child: _RoleCard2(
                                icon: Icons.home_rounded,
                                title: 'Customer',
                                description:
                                    'Find trusted professionals for your projects.',
                                badge: 'Most Popular',
                                gradient: const [_LK.royalBlue, _LK.glowBlue],
                                onTap: () => widget.onPick(UserRole.customer),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeTransition(
                            opacity: _cardFade[1],
                            child: SlideTransition(
                              position: _cardSlide[1],
                              child: _RoleCard2(
                                icon: Icons.build_rounded,
                                title: 'Professional',
                                description:
                                    'Offer your services and receive jobs.',
                                gradient: const [
                                  _LK.glowBlue,
                                  Color(0xFF22D3EE)
                                ],
                                onTap: () =>
                                    widget.onPick(UserRole.professional),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeTransition(
                            opacity: _cardFade[2],
                            child: SlideTransition(
                              position: _cardSlide[2],
                              child: _RoleCard2(
                                icon: Icons.apartment_rounded,
                                title: 'Contractor',
                                description: 'Manage projects and teams.',
                                gradient: const [_LK.navyDark, _LK.navyDeep],
                                onTap: () => widget.onPick(UserRole.contractor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Role picker hero (~30% of the screen) ─────────────────────────────────────
class _RolePickerHero extends StatelessWidget {
  final double height, topInset;
  final Animation<double> floatAnim;
  final VoidCallback onBack;
  const _RolePickerHero({
    required this.height,
    required this.topInset,
    required this.floatAnim,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_LK.navyDark, _LK.navyDeep],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -50,
                right: -40,
                child: AnimatedBuilder(
                  animation: floatAnim,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(0, floatAnim.value), child: child),
                  child: _GlowBlob(
                      color: _LK.glowBlue.withOpacity(0.32), size: 190),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -30,
                child: _GlowBlob(
                    color: _LK.royalBlue.withOpacity(0.20), size: 140),
              ),
              Positioned.fill(
                  child: CustomPaint(painter: _HeroSkylinePainter())),
              const Positioned(
                  top: 44, left: 50, child: _Particle(size: 4, opacity: 0.5)),
              const Positioned(
                  top: 30, right: 90, child: _Particle(size: 3, opacity: 0.4)),
              const Positioned(
                  bottom: 50,
                  right: 60,
                  child: _Particle(size: 4, opacity: 0.45)),
              Positioned(
                top: topInset + 10,
                left: 14,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding:
                      EdgeInsets.only(top: topInset + 20, left: 24, right: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: floatAnim,
                        builder: (_, child) => Transform.translate(
                            offset: Offset(0, floatAnim.value * 0.5),
                            child: child),
                        child: const _HeroLogoBadge(),
                      ),
                      const SizedBox(height: 14),
                      const Text('Choose Your Role',
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 6),
                      Text('Select how you want to use San3a',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.68))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Simple elegant progress indicator: ●━━○━━○━━○ ──────────────────────────
// Shared by every screen in the wizard (role picker, register, pro details,
// done) — one component, one style, everywhere, per the design-system brief.
class _AuthProgressBar extends StatelessWidget {
  final int currentStep; // 1-based
  final int totalSteps;
  final String currentLabel;
  const _AuthProgressBar({
    required this.currentStep,
    required this.totalSteps,
    required this.currentLabel,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                final segmentStep = i ~/ 2 + 1;
                final filled = segmentStep < currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: filled ? _LK.royalBlue : _LK.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }
              final step = i ~/ 2 + 1;
              final isActive = step == currentStep;
              final isDone = step < currentStep;
              final lit = isActive || isDone;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 14 : 9,
                height: isActive ? 14 : 9,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lit ? _LK.royalBlue : Colors.transparent,
                  border: Border.all(
                    color: lit ? _LK.royalBlue : _LK.border,
                    width: lit ? 0 : 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                              color: _LK.royalBlue.withOpacity(0.45),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 7)
                    : null,
              );
            }),
          ),
          const SizedBox(height: 10),
          Text('Step $currentStep of $totalSteps — $currentLabel',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _LK.textSecondary)),
        ],
      );
}

// ─── Premium role card — glassmorphism, scale on press, glow on hover,
// native ripple ────────────────────────────────────────────────────────────
class _RoleCard2 extends StatefulWidget {
  final IconData icon;
  final String title, description;
  final String? badge;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _RoleCard2({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
    this.badge,
  });

  @override
  State<_RoleCard2> createState() => _RoleCard2State();
}

class _RoleCard2State extends State<_RoleCard2> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lifted = _hovered && !_pressed;
    return AnimatedScale(
      scale: _pressed ? 0.97 : (lifted ? 1.015 : 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onHover: (v) => setState(() => _hovered = v),
          splashColor: widget.gradient.first.withOpacity(0.12),
          highlightColor: widget.gradient.first.withOpacity(0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: lifted
                    ? widget.gradient.first.withOpacity(0.55)
                    : _LK.border,
                width: lifted ? 1.6 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      widget.gradient.first.withOpacity(lifted ? 0.28 : 0.14),
                  blurRadius: lifted ? 26 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: widget.gradient.last.withOpacity(0.40),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _LK.textPrimary,
                                letterSpacing: -0.2)),
                        if (widget.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_LK.royalBlue, _LK.glowBlue]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(widget.badge!,
                                style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(widget.description,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: _LK.textSecondary,
                              height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.gradient.first.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: widget.gradient.first),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PREMIUM AUTH WIZARD — remaining screens (Create Account, Professional/
// Contractor Details, Done). Same design system as the Login and Choose
// Your Role screens above: _LK palette, _AuthStepHero, _AuthProgressBar,
// _RoleBadgeCapsule, _FormCard, _PremiumField, _PremiumPrimaryButton. Every
// widget below is presentation-only — all controllers, form keys,
// validators and onSubmit/onBack callbacks are the exact same ones
// _LoginScreenState already owned (see _buildPremiumRegisterScaffold /
// _buildPremiumProDetailsScaffold / _buildPremiumDoneScaffold above).
// ═══════════════════════════════════════════════════════════════════════════

// ─── Reusable hero for the deeper wizard steps (no logo — kept only on the
// Login/Role-Picker entry screens to save vertical space per the 24–28%
// height budget) ─────────────────────────────────────────────────────────────
class _AuthStepHero extends StatelessWidget {
  final double height, topInset;
  final Animation<double> floatAnim;
  final VoidCallback onBack;
  final String title, subtitle;
  const _AuthStepHero({
    required this.height,
    required this.topInset,
    required this.floatAnim,
    required this.onBack,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_LK.navyDark, _LK.navyDeep],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -50,
                right: -40,
                child: AnimatedBuilder(
                  animation: floatAnim,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(0, floatAnim.value), child: child),
                  child: _GlowBlob(
                      color: _LK.glowBlue.withOpacity(0.30), size: 180),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -30,
                child: _GlowBlob(
                    color: _LK.royalBlue.withOpacity(0.18), size: 130),
              ),
              Positioned.fill(
                  child: CustomPaint(painter: _HeroSkylinePainter())),
              const Positioned(
                  top: 40, left: 46, child: _Particle(size: 4, opacity: 0.5)),
              const Positioned(
                  top: 26, right: 80, child: _Particle(size: 3, opacity: 0.4)),
              const Positioned(
                  bottom: 30,
                  right: 50,
                  child: _Particle(size: 4, opacity: 0.45)),
              Positioned(
                top: topInset + 10,
                left: 14,
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding:
                      EdgeInsets.only(top: topInset + 20, left: 28, right: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.68))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Premium glass role-badge capsule (🏠 Customer / 🔧 Professional /
// 🏗 Contractor) ────────────────────────────────────────────────────────────
class _RoleBadgeCapsule extends StatelessWidget {
  final UserRole role;
  final AppLocalizations l;
  const _RoleBadgeCapsule({required this.role, required this.l});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: _LK.royalBlue.withOpacity(0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: _LK.royalBlue.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_roleEmoji(role), style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Text(_roleLabel(role, l),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _LK.textPrimary)),
        ]),
      );
}

// ─── Floating premium form card — rounded 30, glassmorphism, soft shadow ──────
class _FormCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _FormCard({required this.isDark, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        decoration: BoxDecoration(
          color: isDark ? _LK.cardBgDark : _LK.cardBg,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: _LK.navyDark.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 14)),
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      );
}

// ─── Premium region-picker trigger field (replaces _GlassRegionPicker) ────────
class _PremiumRegionField extends StatelessWidget {
  final String display;
  final bool hasSelection;
  final bool isDark;
  final VoidCallback onTap;
  final String? Function(String?)? validator;
  const _PremiumRegionField({
    required this.display,
    required this.hasSelection,
    required this.isDark,
    required this.onTap,
    this.validator,
  });
  @override
  Widget build(BuildContext context) => FormField<String>(
        validator: (_) => validator?.call(null),
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                decoration: BoxDecoration(
                  color: isDark ? _LK.fieldBgDark : _LK.fieldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasSelection
                        ? _LK.royalBlue.withOpacity(0.6)
                        : (isDark ? _LK.borderDark : _LK.border),
                    width: hasSelection ? 1.6 : 1.2,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.map_outlined,
                      size: 20,
                      color: hasSelection
                          ? _LK.royalBlue
                          : (isDark ? Colors.white54 : _LK.textSecondary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: hasSelection
                          ? Text(display,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : _LK.textPrimary))
                          : Text('Tap to select work areas...',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  color: isDark
                                      ? Colors.white38
                                      : _LK.textSecondary))),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : _LK.textSecondary),
                ]),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(state.errorText!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 11)),
              ),
          ],
        ),
      );
}

// ─── Premium specialty chips (replaces _SpecialtiesWrap) ──────────────────────
class _PremiumSpecialtyChips extends StatelessWidget {
  final List<String> selected;
  final bool isDark;
  final AppLocalizations l;
  final AsyncValue<List<CategoryModel>> categoriesAsync;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onMoreTap;
  const _PremiumSpecialtyChips({
    required this.selected,
    required this.isDark,
    required this.l,
    required this.categoriesAsync,
    required this.onChanged,
    required this.onMoreTap,
  });

  Widget _stateText(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(msg,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : _LK.textSecondary)),
      );

  @override
  Widget build(BuildContext context) {
    if (categoriesAsync.isLoading && !categoriesAsync.hasValue) {
      return _stateText('Loading categories...');
    }
    if (categoriesAsync.hasError && !categoriesAsync.hasValue) {
      return _stateText('Failed to load categories');
    }
    final categories = categoriesAsync.value ?? [];
    if (categories.isEmpty) return _stateText('No categories available');

    final mainCats = categories.take(6).toList();
    final moreCats = categories.skip(6).toList();
    final moreKeys = moreCats.map((c) => c.nameKey).toSet();
    final selMore = selected.where((k) => moreKeys.contains(k)).toList();

    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...mainCats.map((cat) {
        final key = cat.nameKey;
        final sel = selected.contains(key);
        return GestureDetector(
          onTap: () {
            final u = List<String>.from(selected);
            if (sel) {
              u.remove(key);
            } else {
              u.add(key);
            }
            onChanged(u);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(colors: [_LK.royalBlue, _LK.navyDark])
                  : null,
              color: sel ? null : (isDark ? _LK.fieldBgDark : _LK.fieldBg),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel
                    ? Colors.transparent
                    : (isDark ? _LK.borderDark : _LK.border),
                width: 1.2,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: _LK.royalBlue.withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : const [],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(cat.icon, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(_catLabel(key, l),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: sel
                          ? Colors.white
                          : (isDark ? Colors.white70 : _LK.textPrimary))),
              if (sel) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              ],
            ]),
          ),
        );
      }),
      ...selMore.map((key) {
        final cat = moreCats.firstWhere((c) => c.nameKey == key,
            orElse: () => CategoryModel(
                id: key, nameKey: key, icon: '✨', providerCount: 0));
        return GestureDetector(
          onTap: () => onChanged(List<String>.from(selected)..remove(key)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_LK.royalBlue, _LK.navyDark]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(cat.icon, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(_catLabel(key, l),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, color: Colors.white, size: 13),
            ]),
          ),
        );
      }),
      GestureDetector(
        onTap: onMoreTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: _LK.royalBlue.withOpacity(0.5), width: 1.3),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, size: 15, color: _LK.royalBlue),
            const SizedBox(width: 4),
            Text(l.get('more'),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _LK.royalBlue)),
          ]),
        ),
      ),
    ]);
  }
}

// ─── "Create Account" (register step 1) — full premium screen ─────────────────
class _PremiumRegisterView extends StatefulWidget {
  final bool isDark, showPass, loading, fetchingLocation;
  final AppLocalizations l;
  final UserRole role;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl,
      emailCtrl,
      phoneCtrl,
      passCtrl,
      addressCtrl;
  final VoidCallback onTogglePass, onDetectAddress, onBack, onSubmit;
  const _PremiumRegisterView({
    required this.isDark,
    required this.l,
    required this.role,
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.addressCtrl,
    required this.showPass,
    required this.loading,
    required this.fetchingLocation,
    required this.onTogglePass,
    required this.onDetectAddress,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  State<_PremiumRegisterView> createState() => _PremiumRegisterViewState();
}

class _PremiumRegisterViewState extends State<_PremiumRegisterView>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final AnimationController _cardCtrl;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..forward();
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final isCustomer = widget.role == UserRole.customer;
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;
    final heroHeight = (size.height * 0.26).clamp(190.0, 260.0);

    return Stack(
      children: [
        Positioned(
            top: heroHeight * 0.6,
            right: -70,
            child:
                _GlowBlob(color: _LK.royalBlue.withOpacity(0.06), size: 240)),
        Positioned(
            bottom: 30,
            left: -80,
            child: _GlowBlob(color: _LK.glowBlue.withOpacity(0.05), size: 220)),
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _AuthStepHero(
                      height: heroHeight + topInset,
                      topInset: topInset,
                      floatAnim: _floatAnim,
                      onBack: widget.onBack,
                      title: 'Create Account',
                      subtitle: 'Tell us about yourself.',
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                              child:
                                  _RoleBadgeCapsule(role: widget.role, l: l)),
                          const SizedBox(height: 20),
                          const _AuthProgressBar(
                              currentStep: 2,
                              totalSteps: 4,
                              currentLabel: 'Account'),
                          const SizedBox(height: 26),
                          FadeTransition(
                            opacity: _cardFade,
                            child: SlideTransition(
                              position: _cardSlide,
                              child: _FormCard(
                                isDark: widget.isDark,
                                child: Form(
                                  key: widget.formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _PremiumField(
                                        controller: widget.nameCtrl,
                                        isDark: widget.isDark,
                                        hint: 'John Smith',
                                        icon: Icons.person_outline_rounded,
                                        validator: (v) {
                                          if (v == null ||
                                              v.trim().length < 3) {
                                            return l.get('required_name');
                                          }
                                          if (!RegExp(r'^[a-zA-Z ]+$')
                                              .hasMatch(v.trim())) {
                                            return 'English letters only';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _PremiumField(
                                        controller: widget.emailCtrl,
                                        isDark: widget.isDark,
                                        hint: 'your@email.com',
                                        icon: Icons.mail_outline_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return l.get('required_email');
                                          }
                                          if (!RegExp(
                                                  r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                                              .hasMatch(v.trim())) {
                                            return l.get('invalid_email');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _PremiumField(
                                        controller: widget.phoneCtrl,
                                        isDark: widget.isDark,
                                        hint: '05x-xxxxxxx',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return l.get('required_phone');
                                          }
                                          if (!RegExp(r'^\d+$')
                                              .hasMatch(v.trim())) {
                                            return l.get('invalid_phone');
                                          }
                                          if (v.trim().length < 8 ||
                                              v.trim().length > 15) {
                                            return l.get('invalid_phone');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _PremiumField(
                                        controller: widget.passCtrl,
                                        isDark: widget.isDark,
                                        hint: '••••••••',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: !widget.showPass,
                                        suffixIcon: GestureDetector(
                                          onTap: widget.onTogglePass,
                                          child: Icon(
                                            widget.showPass
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: (widget.isDark
                                                    ? Colors.white
                                                    : _LK.textSecondary)
                                                .withOpacity(0.65),
                                            size: 20,
                                          ),
                                        ),
                                        validator: (v) => validatePassword(v, l,
                                            email: widget.emailCtrl.text,
                                            name: widget.nameCtrl.text,
                                            phone: widget.phoneCtrl.text),
                                      ),
                                      if (isCustomer) ...[
                                        const SizedBox(height: 14),
                                        _PremiumField(
                                          controller: widget.addressCtrl,
                                          isDark: widget.isDark,
                                          hint: 'Type or tap GPS',
                                          icon: Icons.location_on_outlined,
                                          suffixIcon: widget.fetchingLocation
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: _LK
                                                                  .royalBlue
                                                                  .withOpacity(
                                                                      0.70))))
                                              : GestureDetector(
                                                  onTap: widget.onDetectAddress,
                                                  child: Icon(
                                                      Icons.my_location_rounded,
                                                      color: _LK.royalBlue
                                                          .withOpacity(0.75),
                                                      size: 20)),
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? 'Address is required'
                                                  : null,
                                        ),
                                      ],
                                      const SizedBox(height: 24),
                                      _PremiumPrimaryButton(
                                        loading: widget.loading,
                                        onTap: widget.loading
                                            ? null
                                            : widget.onSubmit,
                                        label: isCustomer
                                            ? l.get('sign_up')
                                            : 'Continue',
                                        icon: isCustomer
                                            ? Icons.check_rounded
                                            : Icons.arrow_forward_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── "Professional/Contractor Details" (register step 2) — full premium
// screen ─────────────────────────────────────────────────────────────────────
class _PremiumProDetailsView extends StatefulWidget {
  final bool isDark, loading;
  final AppLocalizations l;
  final UserRole role;
  final GlobalKey<FormState> formKey;
  final TextEditingController expCtrl, descCtrl, companyCtrl;
  final List<String> selectedRegions, selectedSpecialties;
  final String regionsDisplay;
  final AsyncValue<List<CategoryModel>> categoriesAsync;
  final VoidCallback onBack,
      onShowRegionPicker,
      onShowMoreSpecialties,
      onSubmit;
  final ValueChanged<List<String>> onSpecialtyChanged;
  const _PremiumProDetailsView({
    required this.isDark,
    required this.l,
    required this.role,
    required this.formKey,
    required this.expCtrl,
    required this.descCtrl,
    required this.companyCtrl,
    required this.selectedRegions,
    required this.selectedSpecialties,
    required this.regionsDisplay,
    required this.loading,
    required this.categoriesAsync,
    required this.onBack,
    required this.onShowRegionPicker,
    required this.onShowMoreSpecialties,
    required this.onSpecialtyChanged,
    required this.onSubmit,
  });

  @override
  State<_PremiumProDetailsView> createState() => _PremiumProDetailsViewState();
}

class _PremiumProDetailsViewState extends State<_PremiumProDetailsView>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final AnimationController _cardCtrl;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..forward();
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final isContractor = widget.role == UserRole.contractor;
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;
    final heroHeight = (size.height * 0.26).clamp(190.0, 260.0);

    return Stack(
      children: [
        Positioned(
            top: heroHeight * 0.6,
            right: -70,
            child:
                _GlowBlob(color: _LK.royalBlue.withOpacity(0.06), size: 240)),
        Positioned(
            bottom: 30,
            left: -80,
            child: _GlowBlob(color: _LK.glowBlue.withOpacity(0.05), size: 220)),
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _AuthStepHero(
                      height: heroHeight + topInset,
                      topInset: topInset,
                      floatAnim: _floatAnim,
                      onBack: widget.onBack,
                      title: isContractor
                          ? 'Contractor Details'
                          : 'Professional Details',
                      subtitle: isContractor
                          ? 'Set up your company profile.'
                          : 'Add your skills and experience.',
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                              child:
                                  _RoleBadgeCapsule(role: widget.role, l: l)),
                          const SizedBox(height: 20),
                          const _AuthProgressBar(
                              currentStep: 3,
                              totalSteps: 4,
                              currentLabel: 'Details'),
                          const SizedBox(height: 26),
                          FadeTransition(
                            opacity: _cardFade,
                            child: SlideTransition(
                              position: _cardSlide,
                              child: _FormCard(
                                isDark: widget.isDark,
                                child: Form(
                                  key: widget.formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (isContractor) ...[
                                        _PremiumField(
                                          controller: widget.companyCtrl,
                                          isDark: widget.isDark,
                                          hint: l.get('hint_company_name'),
                                          icon: Icons.business_outlined,
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                                  ? l.get('required_company')
                                                  : null,
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      _PremiumRegionField(
                                        display: widget.regionsDisplay,
                                        hasSelection:
                                            widget.selectedRegions.isNotEmpty,
                                        isDark: widget.isDark,
                                        onTap: widget.onShowRegionPicker,
                                        validator: (_) =>
                                            widget.selectedRegions.isEmpty
                                                ? 'Select at least one region'
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      _PremiumField(
                                        controller: widget.expCtrl,
                                        isDark: widget.isDark,
                                        hint: 'e.g. 5',
                                        icon: Icons.timeline_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return l.get('required_experience');
                                          }
                                          if (int.tryParse(v.trim()) == null) {
                                            return l.get('invalid_experience');
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      Text(l.get('specialty'),
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: widget.isDark
                                                  ? Colors.white
                                                  : _LK.textPrimary)),
                                      const SizedBox(height: 10),
                                      _PremiumSpecialtyChips(
                                        selected: widget.selectedSpecialties,
                                        isDark: widget.isDark,
                                        l: l,
                                        categoriesAsync: widget.categoriesAsync,
                                        onChanged: widget.onSpecialtyChanged,
                                        onMoreTap: widget.onShowMoreSpecialties,
                                      ),
                                      if (widget.selectedSpecialties.isEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                              l.get('choose_at_least_one'),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: widget.isDark
                                                      ? Colors.white54
                                                      : _LK.textSecondary)),
                                        ),
                                      const SizedBox(height: 18),
                                      _PremiumField(
                                        controller: widget.descCtrl,
                                        isDark: widget.isDark,
                                        hint: l.get('hint_describe_services'),
                                        icon: Icons.description_outlined,
                                        maxLines: 3,
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? l.get('required_description')
                                                : null,
                                      ),
                                      const SizedBox(height: 24),
                                      _PremiumPrimaryButton(
                                        loading: widget.loading,
                                        onTap: widget.loading
                                            ? null
                                            : widget.onSubmit,
                                        label: 'Finish',
                                        icon: Icons.check_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── "Done" — success screen ────────────────────────────────────────────────
// Purely presentational; the actual navigation away from this screen already
// happens inside _registerCustomer()/_registerPro() (unchanged), after a
// short delay, exactly like the original _DonePanel.
class _PremiumDoneView extends StatefulWidget {
  const _PremiumDoneView();
  @override
  State<_PremiumDoneView> createState() => _PremiumDoneViewState();
}

class _PremiumDoneViewState extends State<_PremiumDoneView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned(
              top: -60,
              right: -50,
              child:
                  _GlowBlob(color: _LK.royalBlue.withOpacity(0.10), size: 260)),
          Positioned(
              bottom: -40,
              left: -60,
              child:
                  _GlowBlob(color: _LK.glowBlue.withOpacity(0.08), size: 220)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _scale,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [_LK.royalBlue, _LK.navyDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            boxShadow: [
                              BoxShadow(
                                  color: _LK.royalBlue.withOpacity(0.45),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14)),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 46),
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text("You're all set!",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: _LK.textPrimary,
                              letterSpacing: -0.4)),
                      const SizedBox(height: 8),
                      Text('Account created successfully',
                          style: TextStyle(
                              fontSize: 14, color: _LK.textSecondary)),
                      const SizedBox(height: 6),
                      Text('Taking you in...',
                          style: TextStyle(
                              fontSize: 12,
                              color: _LK.textSecondary.withOpacity(0.7))),
                      const SizedBox(height: 24),
                      const _AuthProgressBar(
                          currentStep: 4, totalSteps: 4, currentLabel: 'Done'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
