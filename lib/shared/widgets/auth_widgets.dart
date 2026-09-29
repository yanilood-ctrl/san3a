import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localizations.dart';

class AuthSoftLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const AuthSoftLabel({super.key, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFF8EB69B) : const Color(0xFF374151),
      ),
    );
  }
}

class AuthSoftTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Color accentColor;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const AuthSoftTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.accentColor,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
    this.maxLines = 1,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  State<AuthSoftTextField> createState() => _AuthSoftTextFieldState();
}

class _AuthSoftTextFieldState extends State<AuthSoftTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF162620) : const Color(0xFFF0F4F8);
    final txtColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final hintColor = widget.isDark ? const Color(0xFF5A8A6E) : const Color(0xFF6B7280);

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _focused ? widget.accentColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: widget.isDark
              ? [
            BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 10,
                offset: const Offset(4, 4)),
            BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(-3, -3)),
          ]
              : [
            BoxShadow(
                color: const Color(0xFFB8D4BC).withOpacity(0.9),
                blurRadius: 10,
                offset: const Offset(5, 5)),
            const BoxShadow(
                color: Colors.white,
                blurRadius: 10,
                offset: Offset(-5, -5)),
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLines: widget.maxLines,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: txtColor),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
                color: hintColor, fontSize: 14, fontWeight: FontWeight.w400),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 10),
              child: Icon(widget.icon,
                  color: _focused ? widget.accentColor : hintColor, size: 20),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.maxLines > 1 ? 14 : 18,
            ),
            errorStyle: const TextStyle(fontSize: 11, height: 1.2),
          ),
        ),
      ),
    );
  }
}

class AuthGradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  const AuthGradientButton({
    super.key,
    required this.label,
    required this.loading,
    required this.gradientColors,
    this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          )
              : null,
          color: onTap == null ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: onTap != null
              ? [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ]
              : [],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                )),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(trailingIcon, color: Colors.white, size: 18),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Region Selector — fully localized ────────────────────────────────────────
// When user picks "other", a text field appears for custom English input.
// onChanged receives:
//   - the region key  (e.g. 'jerusalem') for normal selections
//   - the typed text  (e.g. 'Galilee')   when "other" is chosen
class RegionSelector extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool isDark;
  final Color accentColor;
  final String? Function(String?)? validator;

  const RegionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.isDark,
    required this.accentColor,
    this.validator,
  });

  // Keys only — labels come from AppLocalizations at runtime.
  // NOTE: 'other' is the last item; selecting it reveals a custom text field.
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

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  // Tracks the *key* chosen in the picker (always one of _regionKeys or null).
  String? _pickedKey;
  // Controller for the custom text field shown when _pickedKey == 'other'.
  final _customCtrl = TextEditingController();
  bool _customFocused = false;

  @override
  void initState() {
    super.initState();
    // If the parent pre-populates with a key we recognise, restore it.
    if (widget.selected != null &&
        RegionSelector._regionKeys.contains(widget.selected)) {
      _pickedKey = widget.selected;
    } else if (widget.selected != null && widget.selected!.isNotEmpty) {
      // Pre-populated with a custom string → treat as "other" + typed text.
      _pickedKey = 'other';
      _customCtrl.text = widget.selected!;
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  bool get _isOther => _pickedKey == 'other';

  // The effective value surfaced to the parent / FormField validator.
  String? get _effectiveValue {
    if (_pickedKey == null) return null;
    if (_isOther) {
      final t = _customCtrl.text.trim();
      return t.isEmpty ? null : t;
    }
    return _pickedKey;
  }

  void _notifyParent() => widget.onChanged(_effectiveValue);

  void _showPicker(BuildContext context, AppLocalizations l) {
    final isDarkCtx = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDarkCtx ? const Color(0xFF162620) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8EB69B),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title row
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on_outlined,
                    color: widget.accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l.get('choose_region'),
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: isDarkCtx ? Colors.white : const Color(0xFF051F20),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            // Region list — scrollable
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: RegionSelector._regionKeys.map((key) {
                    final isSel = _pickedKey == key;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _pickedKey = key;
                          if (key != 'other') _customCtrl.clear();
                        });
                        _notifyParent();
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSel
                              ? widget.accentColor.withOpacity(0.12)
                              : (isDarkCtx
                              ? const Color(0xFF1E3028)
                              : const Color(0xFFF4FBF5)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? widget.accentColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              l.get('region_$key'),
                              style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: isSel
                                    ? widget.accentColor
                                    : (isDarkCtx
                                    ? Colors.white
                                    : const Color(0xFF051F20)),
                              ),
                            ),
                          ),
                          if (isSel)
                            Icon(Icons.check_circle_rounded,
                                color: widget.accentColor, size: 20),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bg = widget.isDark ? const Color(0xFF162620) : const Color(0xFFEDF4EE);
    final txtColor = widget.isDark ? Colors.white : const Color(0xFF051F20);
    final hintColor = widget.isDark ? const Color(0xFF5A8A6E) : const Color(0xFF8EB69B);
    final hasSel = _pickedKey != null;
    final selLabel = hasSel
        ? (_isOther ? l.get('region_other') : l.get('region_$_pickedKey'))
        : null;

    return FormField<String>(
      validator: (_) => widget.validator?.call(_effectiveValue),
      // Force the FormField to re-validate when state changes
      key: ValueKey('$_pickedKey|${_customCtrl.text}'),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dropdown trigger ──────────────────────────────────────────
          GestureDetector(
            onTap: () => _showPicker(context, l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: state.hasError
                      ? const Color(0xFFE53935)
                      : (hasSel ? widget.accentColor : Colors.transparent),
                  width: 2,
                ),
                boxShadow: widget.isDark
                    ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(4, 4)),
                  BoxShadow(
                      color: Colors.white.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(-3, -3)),
                ]
                    : [
                  BoxShadow(
                      color: const Color(0xFFB8D4BC).withOpacity(0.9),
                      blurRadius: 10,
                      offset: const Offset(5, 5)),
                  const BoxShadow(
                      color: Colors.white,
                      blurRadius: 10,
                      offset: Offset(-5, -5)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(children: [
                Icon(Icons.location_on_outlined,
                    color: hasSel ? widget.accentColor : hintColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selLabel ?? l.get('choose_region'),
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: hasSel ? txtColor : hintColor,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: hasSel ? widget.accentColor : hintColor, size: 22),
              ]),
            ),
          ),

          // ── "Other" custom text field ─────────────────────────────────
          if (_isOther) ...[
            const SizedBox(height: 12),
            Focus(
              onFocusChange: (f) => setState(() => _customFocused = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _customFocused ? widget.accentColor : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: widget.isDark
                      ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 10,
                        offset: const Offset(4, 4)),
                    BoxShadow(
                        color: Colors.white.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(-3, -3)),
                  ]
                      : [
                    BoxShadow(
                        color: const Color(0xFFB8D4BC).withOpacity(0.9),
                        blurRadius: 10,
                        offset: const Offset(5, 5)),
                    const BoxShadow(
                        color: Colors.white,
                        blurRadius: 10,
                        offset: Offset(-5, -5)),
                  ],
                ),
                child: TextFormField(
                  controller: _customCtrl,
                  onChanged: (v) {
                    setState(() {});
                    _notifyParent();
                  },
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: txtColor),
                  decoration: InputDecoration(
                    hintText: 'Type your work area in English',
                    hintStyle: TextStyle(
                        color: hintColor, fontSize: 14, fontWeight: FontWeight.w400),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 10),
                      child: Icon(Icons.edit_location_alt_outlined,
                          color: _customFocused ? widget.accentColor : hintColor,
                          size: 20),
                    ),
                    prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    errorStyle: const TextStyle(fontSize: 11, height: 1.2),
                  ),
                  // English letters and spaces only
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Please enter your work area.';
                    final englishOnly = RegExp(r'^[a-zA-Z ]+$');
                    if (!englishOnly.hasMatch(t)) {
                      return 'Please enter your work area in English letters only.';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],

          // ── Dropdown error ────────────────────────────────────────────
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                state.errorText!,
                style: const TextStyle(color: Color(0xFFE53935), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}