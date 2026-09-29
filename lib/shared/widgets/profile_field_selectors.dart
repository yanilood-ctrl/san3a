// ── Shared Profile Edit Field Selectors ───────────────────────────────────────
// Structured Work Area / Working Hours / Response Time / Languages editors
// used by Professional and Contractor profile edit forms. Mirrors the Neo
// (neumorphic) visual language already used in both screens; only the
// `accentColor` differs per role. The Languages UX here is a verbatim port
// of the one manually verified on the Customer profile
// (customer_profile_screen.dart _EditProfileSheetState) — kept public here so
// it can be reused without touching that screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localizations.dart';
import '../models/models.dart' show kCanonicalWorkingDays, kWorkingDayLabels;

// ── Option lists ───────────────────────────────────────────────────────────
const List<String> kMainLanguages = [
  'Arabic',
  'Hebrew',
  'English',
  'French',
  'Russian',
];

const List<String> kBroadLanguages = [
  'Arabic',
  'Hebrew',
  'English',
  'French',
  'Russian',
  'Spanish',
  'German',
  'Italian',
  'Portuguese',
  'Turkish',
  'Chinese (Mandarin)',
  'Japanese',
  'Korean',
  'Hindi',
  'Urdu',
  'Persian (Farsi)',
  'Amharic',
  'Swahili',
  'Dutch',
  'Greek',
  'Polish',
  'Ukrainian',
  'Romanian',
  'Bulgarian',
  'Serbian',
  'Vietnamese',
  'Thai',
  'Indonesian',
  'Malay',
  'Tagalog (Filipino)',
  'Bengali',
  'Punjabi',
  'Tamil',
  'Armenian',
  'Georgian',
  'Azerbaijani',
  'Kurdish',
  'Somali',
  'Hausa',
  'Yoruba',
];

/// Normalizes a raw stored language list so a predefined language (matched
/// case/whitespace-insensitively against [kBroadLanguages], which already
/// includes every [kMainLanguages] entry) always collapses to its one
/// canonical displayed spelling — e.g. "english"/"ENGLISH"/" English " all
/// become "English" — and every entry (predefined or custom) is deduplicated
/// case-insensitively, keeping the first occurrence. A custom language that
/// matches no predefined entry is kept, trimmed, using its own original
/// spelling. Used by [LanguagesField] itself, and safe to reuse anywhere a
/// stored language list needs the same treatment for read-only display
/// (e.g. Admin's read-only Worker details).
List<String> canonicalizeLanguages(List<String> raw) {
  final result = <String>[];
  final seenKeys = <String>{};
  for (final lang in raw) {
    final trimmed = lang.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (!seenKeys.add(key)) continue;
    final canonicalMatch = kBroadLanguages.where((p) => p.toLowerCase() == key);
    result.add(canonicalMatch.isNotEmpty ? canonicalMatch.first : trimmed);
  }
  return result;
}

// Same region keys used at registration (register_screen.dart _regionKeys),
// so professional/contractor edit forms offer the same options as signup.
const List<String> kWorkAreaRegionKeys = [
  'north_country',
  'south_country',
  'west_country',
  'east_country',
  'jerusalem',
  'haifa',
  'tel_aviv',
  'nazareth',
];
const String kWorkAreaOtherKey = 'other';

const List<String> kResponseTimeOptions = [
  'Usually within 15 minutes',
  'Usually within 30 minutes',
  'Usually within an hour',
  'Usually within 2 hours',
  'Usually within 24 hours',
];

// "No specific preferred period — reachable at any hour." Stored in
// `preferredContactHours` exactly like the four time-of-day values, so no
// model, Firestore field or security rule had to change: it is simply one
// more allowed string in the same list.
const String kPreferredContactHoursAnyTime = 'Any Time';

// The Preferred Contact Hours choices, shared by the Customer profile's own
// selector (customer_profile_screen.dart _EditProfileSheetState._allHours)
// and Admin's Customer edit form, so the two can never drift apart.
// 'Any Time' is listed last, after the specific periods it replaces.
const List<String> kPreferredContactHourOptions = [
  'Morning',
  'Afternoon',
  'Evening',
  'Night',
  kPreferredContactHoursAnyTime,
];

/// Applies a tap on [option] to the [current] Preferred Contact Hours
/// selection and returns the new selection.
///
/// Contact hours have always been a multi-select list, and that stays true —
/// but 'Any Time' means "no specific period", so it is mutually exclusive
/// with the four time-of-day values rather than adding to them:
///  * picking 'Any Time' clears every specific period;
///  * picking a specific period clears 'Any Time';
///  * tapping a selected value deselects it, leaving an empty selection
///    (which, as before, simply means the user stated no preference).
///
/// Records saved before 'Any Time' existed hold only the old values and are
/// untouched by this — they keep loading and re-saving exactly as they did.
List<String> togglePreferredContactHour(List<String> current, String option) {
  if (option == kPreferredContactHoursAnyTime) {
    return current.contains(kPreferredContactHoursAnyTime)
        ? <String>[]
        : <String>[kPreferredContactHoursAnyTime];
  }
  final next = current
      .where((h) => h != kPreferredContactHoursAnyTime && h != option)
      .toList();
  if (!current.contains(option)) next.add(option);
  return next;
}

// ── Neo primitives (public port of the Customer profile's private ones) ────
class NeoChipSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final void Function(String) onToggle;
  final Color activeColor;
  // When true, unselected chips are visually dimmed (selection is still
  // tappable — enforcing an actual max-selection limit, if any, is the
  // caller's onToggle responsibility). Mirrors the Customer profile's own
  // Favorite Services selector (customer_profile_screen.dart's private
  // _NeoChipSelector.maxReached); default false leaves every other existing
  // caller's appearance unchanged.
  final bool maxReached;
  const NeoChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.activeColor,
    this.maxReached = false,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = selected.contains(opt);
          final isDisabled = maxReached && !isSelected;
          final darkColor = Color.lerp(activeColor, Colors.black, 0.3)!;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onToggle(opt);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEF5),
                borderRadius: BorderRadius.circular(20),
                gradient: isSelected
                    ? LinearGradient(
                        colors: [activeColor, darkColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: activeColor.withOpacity(0.45),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                        BoxShadow(
                            color: darkColor.withOpacity(0.9),
                            blurRadius: 0,
                            offset: const Offset(0, 3)),
                      ]
                    : const [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 5,
                            offset: Offset(3, 3)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 5,
                            offset: Offset(-3, -3)),
                      ],
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDisabled
                          ? activeColor.withValues(alpha: 0.35)
                          : activeColor),
                ),
              ),
            ),
          );
        }).toList(),
      );
}

class NeoMoreChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const NeoMoreChip(
      {super.key,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5), width: 1.2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      );
}

class NeoCheckRow extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const NeoCheckRow(
      {super.key,
      required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: color, width: 1.4)
                  : Border.all(color: Colors.transparent, width: 1.4),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 4,
                    offset: Offset(2, 2)),
                BoxShadow(
                    color: Colors.white, blurRadius: 4, offset: Offset(-2, -2)),
              ],
            ),
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? color : const Color(0xFF333355)))),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 20,
                color: selected ? color : const Color(0xFFBBBBCC),
              ),
            ]),
          ),
        ),
      );
}

// Generic Neo bottom-sheet chrome (handle + title + close button) shared by
// the "more options" sheets below.
Widget _neoSheetShell({
  required BuildContext context,
  required String title,
  required Widget child,
}) =>
    SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF5),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFBEBECF),
                  blurRadius: 20,
                  offset: Offset(8, 8)),
              BoxShadow(
                  color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.max, children: [
            const SizedBox(height: 14),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFBEBECF),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF333355))),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEEEF5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0xFFBEBECF),
                            blurRadius: 5,
                            offset: Offset(3, 3)),
                        BoxShadow(
                            color: Colors.white,
                            blurRadius: 5,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF7777AA)),
                  ),
                ),
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      ),
    );

class _NeoSaveButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _NeoSaveButton({required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
                colors: [color, Color.lerp(color, Colors.black, 0.3)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: const Center(
              child: Text('Done',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800))),
        ),
      );
}

void _showMoreLanguagesSheet({
  required BuildContext context,
  required List<String> current,
  required Color accentColor,
  required ValueChanged<List<String>> onDone,
}) {
  final selected = List<String>.from(current);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => _neoSheetShell(
        context: ctx,
        title: 'Select Languages',
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: kBroadLanguages.length,
              itemBuilder: (_, i) {
                final lang = kBroadLanguages[i];
                final isSelected = selected.contains(lang);
                return NeoCheckRow(
                  label: lang,
                  selected: isSelected,
                  color: accentColor,
                  onTap: () => setSheetState(() =>
                      isSelected ? selected.remove(lang) : selected.add(lang)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _NeoSaveButton(
              color: accentColor,
              onTap: () {
                onDone(List<String>.from(selected));
                Navigator.pop(ctx);
              },
            ),
          ),
        ]),
      ),
    ),
  );
}

// ── Languages field ─────────────────────────────────────────────────────────
class LanguagesField extends StatefulWidget {
  final List<String> initialValue;
  final Color accentColor;
  const LanguagesField(
      {super.key, required this.initialValue, required this.accentColor});
  @override
  State<LanguagesField> createState() => LanguagesFieldState();
}

class LanguagesFieldState extends State<LanguagesField> {
  late List<String> _languages;

  @override
  void initState() {
    super.initState();
    _languages = canonicalizeLanguages(widget.initialValue);
  }

  List<String> get value => _languages;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeoChipSelector(
            options: {...kMainLanguages, ..._languages}.toList(),
            selected: _languages,
            onToggle: (v) => setState(() => _languages.contains(v)
                ? _languages.remove(v)
                : _languages.add(v)),
            activeColor: widget.accentColor,
          ),
          const SizedBox(height: 10),
          NeoMoreChip(
            label: 'More Languages',
            color: widget.accentColor,
            onTap: () => _showMoreLanguagesSheet(
              context: context,
              current: _languages,
              accentColor: widget.accentColor,
              onDone: (updated) => setState(() => _languages = updated),
            ),
          ),
        ],
      );
}

// ── Response Time field ─────────────────────────────────────────────────────
class ResponseTimeField extends StatefulWidget {
  final String initialValue;
  final Color accentColor;
  const ResponseTimeField(
      {super.key, required this.initialValue, required this.accentColor});
  @override
  State<ResponseTimeField> createState() => ResponseTimeFieldState();
}

class ResponseTimeFieldState extends State<ResponseTimeField> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.trim();
    if (_value.isEmpty) _value = kResponseTimeOptions[2];
  }

  String get value => _value;

  @override
  Widget build(BuildContext context) => NeoChipSelector(
        options: kResponseTimeOptions.contains(_value)
            ? kResponseTimeOptions
            : [...kResponseTimeOptions, _value],
        selected: [_value],
        onToggle: (v) => setState(() => _value = v),
        activeColor: widget.accentColor,
      );
}

// ── Work Area field ──────────────────────────────────────────────────────────
class WorkAreaField extends StatefulWidget {
  final String initialValue;
  final Color accentColor;
  const WorkAreaField(
      {super.key, required this.initialValue, required this.accentColor});
  @override
  State<WorkAreaField> createState() => WorkAreaFieldState();
}

class WorkAreaFieldState extends State<WorkAreaField> {
  late String _selectedKey; // one of kWorkAreaRegionKeys, or kWorkAreaOtherKey
  late TextEditingController _customCtrl;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialValue.trim();
    if (raw.isNotEmpty && kWorkAreaRegionKeys.contains(raw)) {
      _selectedKey = raw;
      _customCtrl = TextEditingController();
    } else if (raw.isNotEmpty) {
      _selectedKey = kWorkAreaOtherKey;
      _customCtrl = TextEditingController(text: raw);
    } else {
      _selectedKey = kWorkAreaOtherKey;
      _customCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  /// Raw region key (e.g. 'haifa') for a predefined region, or the trimmed
  /// custom text when "Other" is selected — same convention `workArea`
  /// already uses (register_screen.dart _workAreaValue) so
  /// AppLocalizations.translateRegion keeps working unchanged.
  String get value => _selectedKey == kWorkAreaOtherKey
      ? _customCtrl.text.trim()
      : _selectedKey;

  String _displayLabel(AppLocalizations l) => _selectedKey == kWorkAreaOtherKey
      ? (_customCtrl.text.trim().isEmpty
          ? l.get('region_other')
          : _customCtrl.text.trim())
      : l.translateRegion(_selectedKey);

  void _openPicker() {
    final l = AppLocalizations.of(context);
    String sheetSelected = _selectedKey;
    final sheetCustomCtrl = TextEditingController(text: _customCtrl.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _neoSheetShell(
          context: ctx,
          title: l.get('choose_region'),
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ...kWorkAreaRegionKeys.map((k) => NeoCheckRow(
                        label: l.translateRegion(k),
                        selected: sheetSelected == k,
                        color: widget.accentColor,
                        onTap: () => setSheetState(() => sheetSelected = k),
                      )),
                  NeoCheckRow(
                    label: l.get('region_other'),
                    selected: sheetSelected == kWorkAreaOtherKey,
                    color: widget.accentColor,
                    onTap: () =>
                        setSheetState(() => sheetSelected = kWorkAreaOtherKey),
                  ),
                  if (sheetSelected == kWorkAreaOtherKey)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
                      child: TextField(
                        controller: sheetCustomCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter your area',
                          filled: true,
                          fillColor: const Color(0xFFEEEEF5),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: widget.accentColor.withOpacity(0.4)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _NeoSaveButton(
                color: widget.accentColor,
                onTap: () {
                  setState(() {
                    _selectedKey = sheetSelected;
                    _customCtrl.text = sheetCustomCtrl.text;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _openPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEF5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFBEBECF), blurRadius: 6, offset: Offset(3, 3)),
            BoxShadow(
                color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          ],
        ),
        child: Row(children: [
          Icon(Icons.map_outlined, color: widget.accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_displayLabel(l),
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF333355)))),
          Icon(Icons.chevron_right_rounded,
              color: widget.accentColor.withOpacity(0.7), size: 20),
        ]),
      ),
    );
  }
}

// ── Working Hours field ─────────────────────────────────────────────────────
class WorkingHoursField extends StatefulWidget {
  final String initialRange;
  final Color accentColor;
  const WorkingHoursField(
      {super.key, required this.initialRange, required this.accentColor});
  @override
  State<WorkingHoursField> createState() => WorkingHoursFieldState();
}

class WorkingHoursFieldState extends State<WorkingHoursField> {
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    final parsed = _parseRange(widget.initialRange);
    _start = parsed[0]!;
    _end = parsed[1]!;
  }

  static TimeOfDay? _parseTime(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final mi = int.tryParse(m.group(2)!);
    if (h == null || mi == null || h > 23 || mi > 59) return null;
    return TimeOfDay(hour: h, minute: mi);
  }

  static List<TimeOfDay?> _parseRange(String raw) {
    final parts = raw.split(RegExp(r'[–-]')).map((s) => s.trim()).toList();
    if (parts.length == 2) {
      final s = _parseTime(parts[0]);
      final e = _parseTime(parts[1]);
      if (s != null && e != null) return [s, e];
    }
    return [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 18, minute: 0)
    ];
  }

  bool get _isValid =>
      (_end.hour * 60 + _end.minute) > (_start.hour * 60 + _start.minute);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _formatted => '${_fmt(_start)} – ${_fmt(_end)}';

  /// Returns the "HH:mm – HH:mm" range if valid, or null (revealing an
  /// inline error) if the end time is not after the start time.
  String? validate() {
    if (!_isValid) {
      setState(() => _showError = true);
      return null;
    }
    return _formatted;
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null)
      setState(() {
        _start = picked;
        _showError = false;
      });
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(context: context, initialTime: _end);
    if (picked != null)
      setState(() {
        _end = picked;
        _showError = false;
      });
  }

  Widget _timeChip(String label, TimeOfDay time, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEF5),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFBEBECF),
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.accentColor)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 16, color: widget.accentColor),
                const SizedBox(width: 6),
                Text(time.format(context),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333355))),
              ]),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _timeChip('Start Time', _start, _pickStart),
            const SizedBox(width: 10),
            _timeChip('End Time', _end, _pickEnd),
          ]),
          const SizedBox(height: 8),
          Text(_formatted,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.accentColor)),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('End time must be after start time',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600)),
            ),
        ],
      );
}

/// Splits a "HH:mm – HH:mm" range (as returned by
/// [WorkingHoursFieldState.validate]) into `[start, end]`. Returns null if
/// the format is unexpected.
List<String>? splitWorkingHoursRange(String range) {
  final parts = range.split(RegExp(r'[–-]')).map((s) => s.trim()).toList();
  return (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty)
      ? parts
      : null;
}

// ── Working Days field ──────────────────────────────────────────────────────
class WorkingDaysField extends StatefulWidget {
  final List<String> initialValue;
  final Color accentColor;
  const WorkingDaysField(
      {super.key, required this.initialValue, required this.accentColor});
  @override
  State<WorkingDaysField> createState() => WorkingDaysFieldState();
}

class WorkingDaysFieldState extends State<WorkingDaysField> {
  late List<String> _days;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _days = widget.initialValue
        .map((d) => d.toLowerCase().trim())
        .where(kCanonicalWorkingDays.contains)
        .toSet()
        .toList();
  }

  /// Canonical lowercase day keys currently selected.
  List<String> get value => _days;

  /// Returns the selected days if at least one is selected, or null
  /// (revealing an inline error) if none are.
  List<String>? validate() {
    if (_days.isEmpty) {
      setState(() => _showError = true);
      return null;
    }
    return _days;
  }

  void _toggle(String day) {
    HapticFeedback.lightImpact();
    setState(() {
      _days.contains(day) ? _days.remove(day) : _days.add(day);
      if (_days.isNotEmpty) _showError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels =
        kCanonicalWorkingDays.map((d) => kWorkingDayLabels[d]!).toList();
    final selectedLabels = _days.map((d) => kWorkingDayLabels[d]!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeoChipSelector(
          options: labels,
          selected: selectedLabels,
          onToggle: (label) {
            final day = kCanonicalWorkingDays
                .firstWhere((d) => kWorkingDayLabels[d] == label);
            _toggle(day);
          },
          activeColor: widget.accentColor,
        ),
        if (_showError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Select at least one working day',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
