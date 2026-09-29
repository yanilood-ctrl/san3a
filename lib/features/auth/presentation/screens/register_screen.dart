import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/helpers/location_helper.dart';
import '../../../customer/presentation/screens/customer_home_screen.dart';
import '../../../professional/presentation/screens/professional_home_screen.dart';
import '../../../contractor/presentation/screens/contractor_home_screen.dart';
import '../../../admin/presentation/screens/admin_home_screen.dart';
import '../../../../shared/widgets/auth_widgets.dart';
import 'account_access_gate.dart';

Widget routeByRole(UserModel? user) {
  switch (user?.role) {
    case UserRole.professional:
      return const AccountAccessGate(child: ProfessionalHomeScreen());
    case UserRole.contractor:
      return const AccountAccessGate(child: ContractorHomeScreen());
    case UserRole.admin:
      return const AccountAccessGate(child: AdminHomeScreen());
    default:
      return const AccountAccessGate(child: CustomerHomeScreen());
  }
}

// ── Palette (matches login_screen.dart) ──────────────────────────────────────
const _kPink = Color(0xFFFF97B5);
const _kLight = Color(0xFFF2F7FF);
const _kDark = Color(0xFF2F2D51);
const _kTeal = Color(0xFF0D9488);
const _kBlueAcc = Color(0xFF2563EB);
const _kPurpleA = Color(0xFF7C5CBF);
const _kPurpleB = Color(0xFF5B3FA0);

Color _roleAccent(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return _kBlueAcc;
    case UserRole.professional:
      return _kTeal;
    case UserRole.contractor:
      return _kPurpleA;
    default:
      return _kBlueAcc;
  }
}

// Lighter accent for gradients/buttons
List<Color> _roleGradient(UserRole role) {
  switch (role) {
    case UserRole.customer:
      return const [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E3A8A)];
    case UserRole.professional:
      return const [Color(0xFF0D9488), Color(0xFF0B5E52), Color(0xFF064E44)];
    case UserRole.contractor:
      return const [Color(0xFFA855F7), Color(0xFF7C5CBF), Color(0xFF6D28D9)];
    default:
      return const [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E3A8A)];
  }
}

// ─── Shared password validator (used by both registration screens) ────────────
String? validatePassword(
  String? v,
  AppLocalizations l, {
  String email = '',
  String name = '',
  String phone = '',
}) {
  if (v == null || v.isEmpty) return l.get('required_password');
  if (v.length < 8) return l.get('password_short');
  if (!v.contains(RegExp(r'[A-Z]'))) return l.get('password_no_uppercase');
  if (!v.contains(RegExp(r'[a-z]'))) return l.get('password_no_lowercase');
  if (!v.contains(RegExp(r'[0-9]'))) return l.get('password_no_number');
  final lv = v.toLowerCase();
  if (email.trim().isNotEmpty && lv == email.trim().toLowerCase())
    return l.get('password_equals_email');
  if (name.trim().isNotEmpty && lv == name.trim().toLowerCase())
    return l.get('password_equals_name');
  if (phone.trim().isNotEmpty && v.trim() == phone.trim())
    return l.get('password_equals_phone');
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // Address — user can type manually OR auto-detect via GPS button.
  final _addressCtrl = TextEditingController();
  String _detectedCity = '';
  String _detectedStreet = '';
  bool _fetchingLocation = false;
  bool _showPass = false;
  UserRole _selectedRole = UserRole.customer;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectAddress() async {
    if (_fetchingLocation) return;
    setState(() => _fetchingLocation = true);
    try {
      final result = await LocationHelper.getCurrentAddress();
      setState(() {
        _detectedCity = result.city;
        _detectedStreet = result.streetNumber;
        _addressCtrl.text = result.fullAddress;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == UserRole.customer) {
      // Address must be provided (typed or detected) before sign-up
      if (_addressCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Please enter your address or tap the GPS button to detect it.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      _register();
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessionalDetailsScreen(
              name: _nameCtrl.text,
              email: _emailCtrl.text,
              phone: _phoneCtrl.text,
              password: _passCtrl.text,
              role: _selectedRole,
            ),
          ));
    }
  }

  void _register() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    ref.read(authProvider.notifier).register(
          fullName: _nameCtrl.text,
          email: _emailCtrl.text,
          phone: _phoneCtrl.text,
          password: _passCtrl.text,
          role: _selectedRole,
          city: _detectedCity.isNotEmpty
              ? _detectedCity
              : _addressCtrl.text.trim(),
          streetNumber: _detectedStreet,
        );
    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('registration_success')),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      final user = ref.read(authProvider);
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => routeByRole(user)), (r) => false);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _roleAccent(_selectedRole);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1830) : _kLight,
      body: Stack(
        children: [
          // ── Full gradient background (matches login) ─────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1A1830),
                        const Color(0xFF2A1F50),
                        const Color(0xFF1A1830)
                      ]
                    : [_kPurpleB, _kPurpleA, const Color(0xFF93D8F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // ── Blobs ────────────────────────────────────────────────────────
          Positioned(
              top: -60,
              right: -50,
              child: _AuthGlowBlob(color: _kPink.withOpacity(0.28), size: 200)),
          Positioned(
              bottom: 100,
              left: -60,
              child: _AuthGlowBlob(
                  color: Colors.white.withOpacity(0.07), size: 220)),

          // ── Main scrollable card ─────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Header bar ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // San3a wordmark mini
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Colors.white70, Colors.white],
                          ).createShader(b),
                          child: const Text('San',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                        const Text('3',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF93D8F8))),
                        const Text('a',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ],
                    ),
                    const Spacer(),
                    Text(l.get('register'),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 8),

                // ── White card scrollable ────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1C38)
                          : const Color(0xFFF5F6FF),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                            color: _kPurpleB.withOpacity(0.35),
                            blurRadius: 30,
                            offset: const Offset(0, -6)),
                      ],
                    ),
                    child: Column(children: [
                      // Gradient pill at top of card
                      Container(
                        height: 5,
                        margin:
                            const EdgeInsets.only(top: 12, left: 80, right: 80),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF93D8F8), Color(0xFF7C5CBF)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(l.get('register'),
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : _kDark,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 5),
                                Text(l.get('create_account_now'),
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white54
                                            : _kDark.withOpacity(0.50))),
                                const SizedBox(height: 28),

                                // ── Role Selector ─────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('role'), isDark: isDark),
                                const SizedBox(height: 10),
                                _ModernRoleSelector(
                                  selected: _selectedRole,
                                  onChanged: (r) =>
                                      setState(() => _selectedRole = r),
                                  l: l,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 24),

                                // ── Full name ─────────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('full_name'), isDark: isDark),
                                const SizedBox(height: 8),
                                AuthSoftTextField(
                                  controller: _nameCtrl,
                                  hint: l.get('hint_full_name'),
                                  icon: Icons.person_outline_rounded,
                                  isDark: isDark,
                                  accentColor: accent,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return l.get('required_name');
                                    if (v.trim().length < 3)
                                      return l.get('required_name');
                                    final englishOnly = RegExp(r'^[a-zA-Z ]+$');
                                    if (!englishOnly.hasMatch(v.trim())) {
                                      return 'Please enter your full name in English letters only.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // ── Email ─────────────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('email'), isDark: isDark),
                                const SizedBox(height: 8),
                                AuthSoftTextField(
                                  controller: _emailCtrl,
                                  hint: 'example@email.com',
                                  icon: Icons.email_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.emailAddress,
                                  accentColor: accent,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return l.get('required_email');
                                    final emailRegex = RegExp(
                                        r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                                    if (!emailRegex.hasMatch(v.trim()))
                                      return l.get('invalid_email');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // ── Phone ─────────────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('phone'), isDark: isDark),
                                const SizedBox(height: 8),
                                AuthSoftTextField(
                                  controller: _phoneCtrl,
                                  hint: '05x-xxxxxxx',
                                  icon: Icons.phone_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.phone,
                                  accentColor: accent,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return l.get('required_phone');
                                    final digitsOnly = RegExp(r'^\d+$');
                                    if (!digitsOnly.hasMatch(v.trim()))
                                      return l.get('invalid_phone');
                                    if (v.trim().length < 8 ||
                                        v.trim().length > 15)
                                      return l.get('invalid_phone');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // ── Password ──────────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('password'), isDark: isDark),
                                const SizedBox(height: 8),
                                AuthSoftTextField(
                                  controller: _passCtrl,
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  isDark: isDark,
                                  obscureText: !_showPass,
                                  accentColor: accent,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPass
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: isDark
                                          ? const Color(0xFF8EB69B)
                                          : const Color(0xFF3D6B58),
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _showPass = !_showPass),
                                  ),
                                  validator: (v) => validatePassword(
                                    v,
                                    l,
                                    email: _emailCtrl.text,
                                    name: _nameCtrl.text,
                                    phone: _phoneCtrl.text,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // ── Customer Address (typeable + GPS auto-detect) ─────────
                                if (_selectedRole == UserRole.customer) ...[
                                  AuthSoftLabel(
                                      label: 'Address', isDark: isDark),
                                  const SizedBox(height: 8),
                                  AuthSoftTextField(
                                    controller: _addressCtrl,
                                    hint: 'Type your address or tap GPS',
                                    icon: Icons.location_on_outlined,
                                    isDark: isDark,
                                    accentColor: accent,
                                    maxLines: 1,
                                    // When user edits manually, clear the previously detected
                                    // city/street so we don't keep stale GPS data.
                                    onChanged: (_) {
                                      if (_detectedCity.isNotEmpty ||
                                          _detectedStreet.isNotEmpty) {
                                        setState(() {
                                          _detectedCity = '';
                                          _detectedStreet = '';
                                        });
                                      }
                                    },
                                    suffixIcon: _fetchingLocation
                                        ? Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: accent),
                                            ),
                                          )
                                        : IconButton(
                                            tooltip: 'Detect my location',
                                            icon: Icon(
                                                Icons.my_location_rounded,
                                                color: accent,
                                                size: 20),
                                            onPressed: _detectAddress,
                                          ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Address is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                const SizedBox(height: 14),

                                // ── CTA Button ────────────────────────────────────────────
                                AuthGradientButton(
                                  label: _selectedRole == UserRole.customer
                                      ? l.get('sign_up')
                                      : l.get('next'),
                                  loading: _loading,
                                  gradientColors: _roleGradient(_selectedRole),
                                  onTap: _loading ? null : _next,
                                  trailingIcon:
                                      _selectedRole != UserRole.customer
                                          ? Icons.arrow_forward_ios_rounded
                                          : null,
                                ),
                                const SizedBox(height: 20),

                                Center(
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                      Text(l.get('have_account'),
                                          style: TextStyle(
                                              color: _kTeal, fontSize: 13)),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: TextButton.styleFrom(
                                              foregroundColor: accent),
                                          child: Text(l.get('sign_in'),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13))),
                                    ])),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Modern Role Selector ─────────────────────────────────────────────────────
class _ModernRoleSelector extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  final AppLocalizations l;
  final bool isDark;
  const _ModernRoleSelector({
    required this.selected,
    required this.onChanged,
    required this.l,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'role': UserRole.customer,
        'label': l.get('customer'),
        'icon': Icons.person_rounded,
        'color': const Color(0xFF052659),
        'gradTop': const Color(0xFF1565C0),
        'gradBot': const Color(0xFF052659),
        'bgLight': const Color(0xFFE8EFF8),
        'bgDark': const Color(0xFF0A1628),
        'emoji': '🛒',
      },
      {
        'role': UserRole.professional,
        'label': l.get('professional'),
        'icon': Icons.build_rounded,
        'color': const Color(0xFF0B2B26),
        'gradTop': const Color(0xFF0D9488),
        'gradBot': const Color(0xFF0B2B26),
        'bgLight': const Color(0xFFE4EFED),
        'bgDark': const Color(0xFF0C1F1C),
        'emoji': '🔧',
      },
      {
        'role': UserRole.contractor,
        'label': l.get('contractor'),
        'icon': Icons.engineering_rounded,
        'color': const Color(0xFF7C3AED),
        'gradTop': const Color(0xFFA855F7),
        'gradBot': const Color(0xFF6D28D9),
        'bgLight': const Color(0xFFF0EBFF),
        'bgDark': const Color(0xFF1E1230),
        'emoji': '🏗️',
      },
    ];

    return Row(
      children: roles.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final role = item['role'] as UserRole;
        final color = item['color'] as Color;
        final gradTop = item['gradTop'] as Color;
        final gradBot = item['gradBot'] as Color;
        final sel = selected == role;
        final baseBg =
            isDark ? item['bgDark'] as Color : item['bgLight'] as Color;
        final unselBg =
            isDark ? const Color(0xFF1A2520) : const Color(0xFFF0F4F8);

        return Expanded(
          child: _Neu3DRoleCard(
            sel: sel,
            isDark: isDark,
            color: color,
            gradTop: gradTop,
            gradBot: gradBot,
            baseBg: baseBg,
            unselBg: unselBg,
            margin: EdgeInsets.only(right: i < roles.length - 1 ? 10 : 0),
            onTap: () => onChanged(role),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Icon container — gradient when selected
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: sel
                      ? LinearGradient(
                          colors: [gradTop, gradBot],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: sel ? null : color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: gradBot.withOpacity(0.50),
                              blurRadius: 10,
                              offset: const Offset(0, 5)),
                        ]
                      : [],
                ),
                child: Icon(item['icon'] as IconData,
                    color: sel ? Colors.white : color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(item['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: sel
                        ? color
                        : (isDark
                            ? const Color(0xFF8EB69B)
                            : const Color(0xFF6B7280)),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (sel) ...[
                const SizedBox(height: 6),
                Container(
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [gradTop, gradBot]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─── 3D Neumorphic Role Card ──────────────────────────────────────────────────
class _Neu3DRoleCard extends StatefulWidget {
  final bool sel;
  final bool isDark;
  final Color color;
  final Color gradTop;
  final Color gradBot;
  final Color baseBg;
  final Color unselBg;
  final EdgeInsets margin;
  final VoidCallback onTap;
  final Widget child;
  const _Neu3DRoleCard({
    required this.sel,
    required this.isDark,
    required this.color,
    required this.gradTop,
    required this.gradBot,
    required this.baseBg,
    required this.unselBg,
    required this.margin,
    required this.onTap,
    required this.child,
  });
  @override
  State<_Neu3DRoleCard> createState() => _Neu3DRoleCardState();
}

class _Neu3DRoleCardState extends State<_Neu3DRoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.sel ? widget.baseBg : widget.unselBg;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: widget.margin,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        transform:
            _pressed ? Matrix4.translationValues(0, 3, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.sel ? widget.color : Colors.transparent,
            width: 2,
          ),
          boxShadow: _pressed
              ? []
              : widget.sel
                  ? [
                      // 3D pressed-inward look when selected
                      BoxShadow(
                          color: widget.gradBot
                              .withOpacity(widget.isDark ? 0.60 : 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6)),
                      BoxShadow(
                          color: widget.gradTop.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                          spreadRadius: -3),
                    ]
                  : widget.isDark
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.55),
                              blurRadius: 10,
                              offset: const Offset(4, 4)),
                          BoxShadow(
                              color: Colors.white.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(-3, -3)),
                        ]
                      : [
                          BoxShadow(
                              color: const Color(0xFFB8C9D8).withOpacity(0.85),
                              blurRadius: 10,
                              offset: const Offset(5, 5)),
                          const BoxShadow(
                              color: Colors.white,
                              blurRadius: 10,
                              offset: Offset(-5, -5)),
                        ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── Professional Details Screen ──────────────────────────────────────────────
class ProfessionalDetailsScreen extends ConsumerStatefulWidget {
  final String name, email, phone, password;
  final UserRole role;
  const ProfessionalDetailsScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });
  @override
  ConsumerState<ProfessionalDetailsScreen> createState() =>
      _ProfessionalDetailsState();
}

class _ProfessionalDetailsState
    extends ConsumerState<ProfessionalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  // Multi-region selection
  List<String> _selectedRegions = [];
  final _customRegionCtrl = TextEditingController();
  List<String> _selectedSpecialties = [];
  bool _loading = false;

  @override
  void dispose() {
    _expCtrl.dispose();
    _descCtrl.dispose();
    _companyCtrl.dispose();
    _customRegionCtrl.dispose();
    super.dispose();
  }

  // ── Region keys ──────────────────────────────────────────────────────────
  static const List<String> _regionKeys = [
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

  // Build display string: "North, Haifa, Tel Aviv"
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

  // Effective work area value saved to model
  String get _workAreaValue {
    if (_selectedRegions.isEmpty) return '';
    return _selectedRegions.map((k) {
      if (k == 'other') return _customRegionCtrl.text.trim();
      return k;
    }).join(',');
  }

  void _showRegionPicker(BuildContext context, AppLocalizations l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _roleAccent(widget.role);
    List<String> sheetSelected = List.from(_selectedRegions);
    final sheetCustomCtrl = TextEditingController(text: _customRegionCtrl.text);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Region Picker',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (ctx, anim, secAnim) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final bg = isDark ? const Color(0xFF162620) : Colors.white;
          final txtColor = isDark ? Colors.white : const Color(0xFF051F20);
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
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(-8, 0)),
                  ],
                ),
                child: SafeArea(
                    child: Column(children: [
                  // ── Header ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withOpacity(0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          const BorderRadius.only(topLeft: Radius.circular(28)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.location_on_outlined,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Work Areas',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3)),
                            Text('Select one or more regions',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.75))),
                          ])),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ]),
                  ),

                  // ── Region list ───────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        ..._regionKeys.map((key) {
                          final isSel = sheetSelected.contains(key);
                          return GestureDetector(
                            onTap: () {
                              setSheet(() {
                                if (isSel) {
                                  sheetSelected.remove(key);
                                  if (key == 'other') sheetCustomCtrl.clear();
                                } else {
                                  sheetSelected.add(key);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 130),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? accentColor.withOpacity(0.12)
                                    : (isDark
                                        ? const Color(0xFF1E3028)
                                        : const Color(0xFFF4FBF5)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: isSel
                                        ? accentColor
                                        : Colors.transparent,
                                    width: 2),
                                boxShadow: isDark
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFFB8D4BC)
                                              .withOpacity(isSel ? 0 : 0.5),
                                          blurRadius: 6,
                                          offset: const Offset(3, 3),
                                        ),
                                        if (!isSel)
                                          const BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 6,
                                              offset: Offset(-3, -3)),
                                      ],
                              ),
                              child: Row(children: [
                                Text(l.get('region_$key'),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isSel ? accentColor : txtColor)),
                                const Spacer(),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: isSel
                                        ? LinearGradient(
                                            colors: [
                                              accentColor.withOpacity(0.8),
                                              accentColor
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSel ? null : Colors.transparent,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: isSel
                                          ? Colors.transparent
                                          : (isDark
                                              ? const Color(0xFF5A8A6E)
                                              : const Color(0xFFB0CCBA)),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSel
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 15)
                                      : null,
                                ),
                              ]),
                            ),
                          );
                        }).toList(),

                        // Custom region input if 'other' selected
                        if (sheetSelected.contains('other')) ...[
                          const SizedBox(height: 4),
                          TextField(
                            controller: sheetCustomCtrl,
                            decoration: InputDecoration(
                              hintText: 'Type your region...',
                              hintStyle: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF5A8A6E)
                                      : const Color(0xFF8EB69B),
                                  fontSize: 14),
                              prefixIcon: Icon(Icons.edit_location_outlined,
                                  color: accentColor, size: 20),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E3028)
                                  : const Color(0xFFF4FBF5),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 13),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: accentColor, width: 2)),
                            ),
                            style: TextStyle(
                                fontSize: 15,
                                color: txtColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ]),
                    ),
                  ),

                  // ── Confirm button ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRegions = List.from(sheetSelected);
                          _customRegionCtrl.text = sheetCustomCtrl.text;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.85),
                              accentColor
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: accentColor.withOpacity(0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: const Center(
                            child: Text('Confirm Selection',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2))),
                      ),
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

  void _showMoreCategories(List<CategoryModel> allCategories) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _roleAccent(widget.role);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bg = isDark ? const Color(0xFF162620) : Colors.white;
          final txtColor = isDark ? Colors.white : const Color(0xFF051F20);
          final allMore = allCategories.skip(6).toList();
          return Container(
            // Cap height so the sheet never covers the full screen,
            // and the Column+Flexible can scroll the chip area.
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFF8EB69B),
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                // Title row
                Row(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.category_outlined,
                          color: accentColor, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(l.get('all_categories'),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: txtColor)),
                        Text('${allMore.length} categories — scroll to see all',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF8EB69B)
                                    : const Color(0xFF5A8A6E))),
                      ])),
                ]),
                const SizedBox(height: 16),
                // Scrollable chip area — Flexible + SingleChildScrollView
                // ensures custom/overflow categories (e.g. dckjdvjd) are always reachable.
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allMore.map((cat) {
                        final key = cat.nameKey;
                        final sel = _selectedSpecialties.contains(key);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (sel)
                                _selectedSpecialties.remove(key);
                              else
                                _selectedSpecialties.add(key);
                            });
                            setSheetState(() {});
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: sel
                                    ? accentColor
                                    : (isDark
                                        ? const Color(0xFF1E3028)
                                        : const Color(0xFFF4FBF5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: sel
                                        ? accentColor
                                        : accentColor.withOpacity(0.2),
                                    width: sel ? 2 : 1)),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(cat.icon,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(_catLabel(key, l),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: sel
                                          ? Colors.white
                                          : (isDark
                                              ? const Color(0xFF8EB69B)
                                              : const Color(0xFF235347)))),
                              if (sel) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14),
                              ],
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Save button — always visible, outside the scroll area
                AuthGradientButton(
                  label: l.get('save'),
                  loading: false,
                  gradientColors: [accentColor.withOpacity(0.8), accentColor],
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRegions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one work area.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (_selectedSpecialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)
              .get('select_specialty_error_inline')),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    ref.read(authProvider.notifier).register(
          fullName: widget.name,
          email: widget.email,
          phone: widget.phone,
          password: widget.password,
          role: widget.role,
          workArea: _workAreaValue,
          experienceYears: int.tryParse(_expCtrl.text),
          specialty: _selectedSpecialties.first,
          specialties: _selectedSpecialties,
          description: _descCtrl.text,
          companyName:
              widget.role == UserRole.contractor ? _companyCtrl.text : null,
        );
    if (mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('registration_success')),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      final user = ref.read(authProvider);
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => routeByRole(user)), (r) => false);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isContractor = widget.role == UserRole.contractor;
    final accentColor = _roleAccent(widget.role);
    final txtPri = isDark ? Colors.white : const Color(0xFF1E1C38);
    final txtSec = isDark ? Colors.white54 : _kDark.withOpacity(0.50);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];
    final isLoadingCategories = categoriesAsync.isLoading;
    debugPrint('REGISTER CATEGORIES COUNT: ${categories.length}');
    debugPrint(
        'REGISTER CATEGORIES IDS: ${categories.map((c) => c.nameKey).toList()}');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1830) : _kLight,
      body: Stack(
        children: [
          // ── Same gradient bg as login ────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1A1830),
                        const Color(0xFF2A1F50),
                        const Color(0xFF1A1830)
                      ]
                    : [_kPurpleB, _kPurpleA, const Color(0xFF93D8F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
              top: -60,
              right: -50,
              child: _AuthGlowBlob(color: _kPink.withOpacity(0.25), size: 200)),
          Positioned(
              bottom: 100,
              left: -60,
              child: _AuthGlowBlob(
                  color: Colors.white.withOpacity(0.07), size: 220)),

          SafeArea(
            child: Column(
              children: [
                // ── Header bar ───────────────────────────────────────────
                // ── Purple gradient header bar ─────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withOpacity(0.80)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: accentColor.withOpacity(0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // San3a wordmark
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text('San',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          const Text('3',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF93D8F8))),
                          const Text('a',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.30)),
                      ),
                      child: Text('Create Account',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1C38)
                          : const Color(0xFFF5F6FF),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                            color: _kPurpleB.withOpacity(0.35),
                            blurRadius: 30,
                            offset: const Offset(0, -6)),
                      ],
                    ),
                    child: Column(children: [
                      Container(
                        height: 5,
                        margin:
                            const EdgeInsets.only(top: 12, left: 80, right: 80),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor,
                              accentColor.withOpacity(0.50)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),

                                // ── Step indicator ──────────────────────────────────────
                                Row(children: [
                                  _StepDot(
                                      active: false,
                                      done: true,
                                      color: accentColor,
                                      label: '1'),
                                  Expanded(
                                      child: Container(
                                          height: 2,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              accentColor,
                                              accentColor.withOpacity(0.3)
                                            ]),
                                          ))),
                                  _StepDot(
                                      active: true,
                                      done: false,
                                      color: accentColor,
                                      label: '2'),
                                ]),
                                const SizedBox(height: 20),

                                // Role badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: accentColor.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            isContractor
                                                ? Icons.engineering_rounded
                                                : Icons.build_rounded,
                                            color: accentColor,
                                            size: 15),
                                        const SizedBox(width: 7),
                                        Text(
                                            isContractor
                                                ? l.get('contractor')
                                                : l.get('professional'),
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: accentColor)),
                                      ]),
                                ),
                                const SizedBox(height: 14),

                                Text(
                                    isContractor
                                        ? 'Contractor Information'
                                        : l.get('professional_info'),
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: txtPri,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 24),

                                // ── Company name (Contractor only) ──────────────────────
                                if (isContractor) ...[
                                  AuthSoftLabel(
                                      label: l.get('company_name'),
                                      isDark: isDark),
                                  const SizedBox(height: 8),
                                  AuthSoftTextField(
                                    controller: _companyCtrl,
                                    hint: l.get('hint_company_name'),
                                    icon: Icons.business_outlined,
                                    isDark: isDark,
                                    accentColor: accentColor,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? l.get('required_company')
                                            : null,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // ── Work Areas — Multi-Region Selector ──────────────────
                                AuthSoftLabel(
                                    label: l.get('work_area'), isDark: isDark),
                                const SizedBox(height: 8),
                                _MultiRegionField(
                                  selectedRegions: _selectedRegions,
                                  display: _regionsDisplay(l),
                                  accentColor: accentColor,
                                  isDark: isDark,
                                  onTap: () => _showRegionPicker(context, l),
                                  hasError: _selectedRegions.isEmpty,
                                ),
                                const SizedBox(height: 18),

                                // ── Experience years ────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('experience_years'),
                                    isDark: isDark),
                                const SizedBox(height: 8),
                                AuthSoftTextField(
                                  controller: _expCtrl,
                                  hint: l.get('hint_example_years'),
                                  icon: Icons.timeline_outlined,
                                  isDark: isDark,
                                  keyboardType: TextInputType.number,
                                  accentColor: accentColor,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return l.get('required_experience');
                                    if (int.tryParse(v.trim()) == null)
                                      return l.get('invalid_experience');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 22),

                                // ── Specialties ─────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('specialty'), isDark: isDark),
                                const SizedBox(height: 6),
                                // DEBUG — temporary visible count
                                Text(
                                  'Categories loaded: ${categories.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.orangeAccent
                                        : Colors.deepOrange,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _SpecialtiesSection(
                                  selectedSpecialties: _selectedSpecialties,
                                  accentColor: accentColor,
                                  isDark: isDark,
                                  l: l,
                                  onChanged: (list) => setState(
                                      () => _selectedSpecialties = list),
                                  onMoreTap: () =>
                                      _showMoreCategories(categories),
                                  categories: categories,
                                  isLoading: isLoadingCategories,
                                ),
                                if (_selectedSpecialties.isEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(l.get('choose_at_least_one'),
                                          style: TextStyle(
                                              fontSize: 11, color: txtSec))),
                                const SizedBox(height: 22),

                                // ── Description ─────────────────────────────────────────
                                AuthSoftLabel(
                                    label: l.get('description'),
                                    isDark: isDark),
                                const SizedBox(height: 8),
                                AuthSoftTextField(
                                  controller: _descCtrl,
                                  hint: l.get('hint_describe_services'),
                                  icon: Icons.description_outlined,
                                  isDark: isDark,
                                  maxLines: 3,
                                  accentColor: accentColor,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? l.get('required_description')
                                          : null,
                                ),
                                const SizedBox(height: 32),

                                // ── Register button ─────────────────────────────────────
                                AuthGradientButton(
                                  label: l.get('sign_up'),
                                  loading: _loading,
                                  gradientColors: _roleGradient(widget.role),
                                  onTap: _loading ? null : _register,
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Multi-Region Field Display ───────────────────────────────────────────────
class _MultiRegionField extends StatelessWidget {
  final List<String> selectedRegions;
  final String display;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;
  final bool hasError;
  const _MultiRegionField({
    required this.selectedRegions,
    required this.display,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF162620) : const Color(0xFFEDF4EE);
    final hintColor =
        isDark ? const Color(0xFF5A8A6E) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selectedRegions.isNotEmpty
                    ? accentColor
                    : accentColor.withOpacity(0.3),
                width: selectedRegions.isNotEmpty ? 1.8 : 1.2)),
        child: Row(children: [
          Icon(Icons.map_outlined,
              color: selectedRegions.isNotEmpty ? accentColor : hintColor,
              size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: selectedRegions.isEmpty
                ? Text('Tap to select work areas...',
                    style: TextStyle(
                        color: hintColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedRegions.map((k) {
                      final label = k == 'other'
                          ? 'Other'
                          : AppLocalizations.of(context).get('region_$k');
                      return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)));
                    }).toList(),
                  ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: selectedRegions.isNotEmpty ? accentColor : hintColor,
              size: 22),
        ]),
      ),
    );
  }
}

// Returns the localised label for a category nameKey.
// Falls back to a human-readable version of the key if no translation exists
// (e.g. "dckjdvjd" → "Dckjdvjd", "test_signup" → "Test Signup").
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

// ─── Specialties chips section ────────────────────────────────────────────────
class _SpecialtiesSection extends StatelessWidget {
  final List<String> selectedSpecialties;
  final Color accentColor;
  final bool isDark;
  final AppLocalizations l;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onMoreTap;
  final List<CategoryModel> categories;
  final bool isLoading;
  const _SpecialtiesSection({
    required this.selectedSpecialties,
    required this.accentColor,
    required this.isDark,
    required this.l,
    required this.onChanged,
    required this.onMoreTap,
    required this.categories,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    // ── Loading state: show placeholder chips ──────────────────────────────
    if (isLoading) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
            6,
            (i) => Container(
                  width: 80 + (i % 3) * 16.0,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF162620)
                        : const Color(0xFFEDF4EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                )),
      );
    }

    // ── Empty state ────────────────────────────────────────────────────────
    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF162620) : const Color(0xFFEDF4EE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
            'No categories available. Please contact admin.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF235347),
            ),
          )),
        ]),
      );
    }

    // ── Normal state ────────────────────────────────────────────────────────
    final mainCats = categories.take(6).toList();
    final moreCats = categories.skip(6).toList();
    final moreKeys = moreCats.map((c) => c.nameKey).toSet();
    final selectedMore =
        selectedSpecialties.where((k) => moreKeys.contains(k)).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...mainCats.map((cat) {
          final key = cat.nameKey;
          final sel = selectedSpecialties.contains(key);
          return GestureDetector(
            onTap: () {
              final updated = List<String>.from(selectedSpecialties);
              if (sel)
                updated.remove(key);
              else
                updated.add(key);
              onChanged(updated);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: sel
                    ? accentColor
                    : (isDark
                        ? const Color(0xFF162620)
                        : const Color(0xFFEDF4EE)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? accentColor : accentColor.withOpacity(0.25),
                    width: sel ? 2 : 1),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                            color: Colors.black.withOpacity(sel ? 0.3 : 0.2),
                            blurRadius: 6,
                            offset: const Offset(2, 2)),
                      ]
                    : [
                        BoxShadow(
                            color: const Color(0xFFB8D4BC).withOpacity(0.6),
                            blurRadius: 6,
                            offset: const Offset(3, 3)),
                        const BoxShadow(
                            color: Colors.white,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cat.icon, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(_catLabel(key, l),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF8EB69B)
                                : const Color(0xFF235347)))),
                if (sel) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13),
                ],
              ]),
            ),
          );
        }),

        // Show selected "more" categories inline so user can deselect them
        ...selectedMore.map((key) {
          final cat = moreCats.firstWhere((c) => c.nameKey == key,
              orElse: () => CategoryModel(
                  id: key, nameKey: key, icon: '✨', providerCount: 0));
          return GestureDetector(
            onTap: () {
              final updated = List<String>.from(selectedSpecialties)
                ..remove(key);
              onChanged(updated);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor, width: 2)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cat.icon, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Text(_catLabel(key, l),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(width: 4),
                const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              ]),
            ),
          );
        }),

        // More button — only show when there are overflow categories
        if (moreCats.isNotEmpty)
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor, width: 1.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 15, color: accentColor),
                const SizedBox(width: 5),
                Text(l.get('more'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor)),
              ]),
            ),
          ),
      ],
    );
  }
}

// ─── Auth Glow Blob (matches login screen blobs) ─────────────────────────────
class _AuthGlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _AuthGlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      );
}

// ─── Step Dot ─────────────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final bool active, done;
  final Color color;
  final String label;
  const _StepDot(
      {required this.active,
      required this.done,
      required this.color,
      required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: (done || active)
            ? LinearGradient(
                colors: done
                    ? [color, color.withOpacity(0.75)]
                    : [color.withOpacity(0.85), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: (done || active)
            ? null
            : (isDark ? Colors.white12 : Colors.grey.shade300),
        shape: BoxShape.circle,
        boxShadow: (done || active)
            ? [
                BoxShadow(
                    color: color.withOpacity(0.50),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: color.withOpacity(0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ]
            : [],
      ),
      child: Center(
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text(label,
                  style: TextStyle(
                      color: active
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.grey.shade500),
                      fontWeight: FontWeight.w800,
                      fontSize: 14))),
    );
  }
}
