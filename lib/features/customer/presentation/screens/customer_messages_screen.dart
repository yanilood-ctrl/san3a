import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/chat_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../theme/customer_design.dart';
import 'customer_chat_screen.dart';
import 'provider_profile_screen.dart';
import '../../../contractor/presentation/screens/contractor_chat_screen.dart';
import '../../../professional/presentation/screens/professional_chat_screen.dart';
import 'customer_chat_requests_screen.dart';

class CustomerMessagesScreen extends ConsumerStatefulWidget {
  const CustomerMessagesScreen({super.key});
  @override
  ConsumerState<CustomerMessagesScreen> createState() =>
      _CustomerMessagesScreenState();
}

class _CustomerMessagesScreenState
    extends ConsumerState<CustomerMessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = customerChatTheme;

    final currentUser = ref.watch(authProvider);

    final firestoreConvsAsync = ref.watch(currentUserConversationsProvider);
    final firestoreConvs =
        firestoreConvsAsync.valueOrNull ?? const <ConversationModel>[];

    // Derive "the other participant" per conversation from participantIds /
    // participantNames — Firestore conversations aren't keyed by a single
    // otherUserId like the legacy local model. Block state (Phase 6C-2) comes
    // straight from Firestore's isBlocked/blockedBy — no legacy fallback.
    final convs = currentUser == null
        ? const <ConversationModel>[]
        : firestoreConvs.map((c) {
            final otherId = c.otherParticipantId(currentUser.id);
            final otherName = c.otherParticipantName(currentUser.id);
            return ConversationModel(
              id: c.id,
              otherUserId: otherId,
              otherUserName: otherName,
              lastMessage: c.lastMessage,
              lastMessageTime: c.lastMessageTime,
              unreadCount: c.unreadCountFor(currentUser.id),
              isBlocked: c.isBlocked,
              blockedBy: c.blockedBy,
            );
          }).toList();

    // Blocked conversations stay in this list (Phase 6C-2 removed the
    // separate Blocked Users entry point) — the tile shows a blocked marker.
    final filtered = _query.isEmpty
        ? convs
        : convs
            .where((c) =>
                c.otherUserName.toLowerCase().contains(_query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : theme.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          // Same dark-to-Customer-blue gradient identity as the Customer
          // Home header (customer_feed_screen.dart) — reused verbatim.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                CustomerColors.darkest,
                Color(0xFF0A1F4E),
                CustomerColors.dark
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                  color: Color(0x40021024),
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Text(l.get('messages'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3)),
                ),
                _MyChatRequestsButton(theme: theme),
              ]),
            ),
          ),
        ),
      ),
      body: Column(children: [
        _ChatSearchBar(
            theme: theme,
            isDark: isDark,
            ctrl: _searchCtrl,
            query: _query,
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            }),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyConvState(theme: theme, isEmpty: _query.isEmpty, l: l)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 80,
                    color: isDark
                        ? AppColors.darkBorder
                        : theme.primaryLight.withOpacity(0.6),
                  ),
                  itemBuilder: (ctx, i) {
                    final conv = filtered[i];
                    if (conv.unreadCount > 0) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(conversationsProvider.notifier)
                            .markAsRead(conv.otherUserId);
                      });
                    }
                    return _ConvTile(
                        conv: conv,
                        theme: theme,
                        isDark: isDark,
                        onTap: () {
                          final provider = ref
                              .read(providersProvider)
                              .firstWhere((p) => p.id == conv.otherUserId,
                                  orElse: () => UserModel(
                                      id: conv.otherUserId,
                                      fullName: conv.otherUserName,
                                      email: '',
                                      phone: '',
                                      city: '',
                                      role: UserRole.professional));
                          Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerChatScreen(otherUser: provider)));
                        },
                        onAvatarTap: () {
                          final provider = ref
                              .read(providersProvider)
                              .firstWhere((p) => p.id == conv.otherUserId,
                                  orElse: () => UserModel(
                                      id: conv.otherUserId,
                                      fullName: conv.otherUserName,
                                      email: '',
                                      phone: '',
                                      city: '',
                                      role: UserRole.professional));
                          _openUserProfile(ctx, provider, theme);
                        },
                        onLongPress: () => _showOptions(ctx, conv));
                  },
                ),
        ),
      ]),
    );
  }

  void _showOptions(BuildContext context, ConversationModel conv) {
    showConvOptionsDialog(context, conv, customerChatTheme);
  }
}

// Maps the plain-string role stored in Firestore's participantRoles back to
// UserRole — mirrors UserModel's private _roleFromString (not reusable here).
UserRole _chatRoleFromString(String? s) {
  switch (s) {
    case 'professional':
      return UserRole.professional;
    case 'contractor':
      return UserRole.contractor;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.customer;
  }
}

// Shared by the professional/contractor Messages wrappers below: builds the
// Firestore-backed display list (name/last message/unread/block state all
// come straight from currentUserConversationsProvider — Phase 6C-2 removed
// the legacy local-provider fallback for isBlocked/blockedBy).
List<ConversationModel> _firestoreDisplayConvs(WidgetRef ref) {
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) return const <ConversationModel>[];

  final firestoreConvsAsync = ref.watch(currentUserConversationsProvider);
  final firestoreConvs =
      firestoreConvsAsync.valueOrNull ?? const <ConversationModel>[];

  return firestoreConvs.map((c) {
    final otherId = c.otherParticipantId(currentUser.id);
    final otherName = c.otherParticipantName(currentUser.id);
    final otherRole = c.otherParticipantRole(currentUser.id);
    return ConversationModel(
      id: c.id,
      otherUserId: otherId,
      otherUserName: otherName,
      lastMessage: c.lastMessage,
      lastMessageTime: c.lastMessageTime,
      unreadCount: c.unreadCountFor(currentUser.id),
      isBlocked: c.isBlocked,
      blockedBy: c.blockedBy,
      // Stashed so onTap/onAvatarTap below can recover the real role via
      // conv.otherParticipantRole(currentUser.id).
      participantIds: [currentUser.id, otherId],
      participantRoles: {otherId: otherRole ?? ''},
    );
  }).toList();
}

// ─── Professional Messages Screen ────────────────────────────────────────────
class ProfessionalMessagesScreenWrapper extends ConsumerStatefulWidget {
  const ProfessionalMessagesScreenWrapper({super.key});
  @override
  ConsumerState<ProfessionalMessagesScreenWrapper> createState() =>
      _ProfMsgState();
}

class _ProfMsgState extends ConsumerState<ProfessionalMessagesScreenWrapper> {
  final _ctrl = TextEditingController();
  String _q = '';
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = ChatTheme.professional;

    final currentUser = ref.watch(authProvider);
    final convs = _firestoreDisplayConvs(ref);

    final filtered = _q.isEmpty
        ? convs
        : convs
            .where(
                (c) => c.otherUserName.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return _MessagesScaffold(
      l: l,
      isDark: isDark,
      theme: theme,
      filtered: filtered,
      ctrl: _ctrl,
      query: _q,
      onChanged: (v) => setState(() => _q = v),
      onClear: () {
        _ctrl.clear();
        setState(() => _q = '');
      },
      onTap: (ctx, conv) {
        final role = _chatRoleFromString(currentUser == null
            ? null
            : conv.otherParticipantRole(currentUser.id));
        final user = UserModel(
            id: conv.otherUserId,
            fullName: conv.otherUserName,
            email: '',
            phone: '',
            city: '',
            role: role);
        ref.read(conversationsProvider.notifier).startConversation(user);
        Navigator.push(
            ctx,
            MaterialPageRoute(
                builder: (_) => ProfessionalChatScreen(otherUser: user)));
      },
      onAvatarTap: (ctx, conv) {
        final role = _chatRoleFromString(currentUser == null
            ? null
            : conv.otherParticipantRole(currentUser.id));
        final user = UserModel(
            id: conv.otherUserId,
            fullName: conv.otherUserName,
            email: '',
            phone: '',
            city: '',
            role: role);
        _openUserProfile(ctx, user, ChatTheme.professional);
      },
      onOptions: (ctx, conv) =>
          showConvOptionsDialog(ctx, conv, ChatTheme.professional),
    );
  }
}

// ─── Contractor Messages Screen ───────────────────────────────────────────────
class ContractorMessagesScreenWrapper extends ConsumerStatefulWidget {
  const ContractorMessagesScreenWrapper({super.key});
  @override
  ConsumerState<ContractorMessagesScreenWrapper> createState() =>
      _ContrMsgState();
}

class _ContrMsgState extends ConsumerState<ContractorMessagesScreenWrapper> {
  final _ctrl = TextEditingController();
  String _q = '';
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = ChatTheme.contractor;

    final currentUser = ref.watch(authProvider);
    final convs = _firestoreDisplayConvs(ref);

    final filtered = _q.isEmpty
        ? convs
        : convs
            .where(
                (c) => c.otherUserName.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return _MessagesScaffold(
      l: l,
      isDark: isDark,
      theme: theme,
      filtered: filtered,
      ctrl: _ctrl,
      query: _q,
      onChanged: (v) => setState(() => _q = v),
      onClear: () {
        _ctrl.clear();
        setState(() => _q = '');
      },
      onTap: (ctx, conv) {
        final role = _chatRoleFromString(currentUser == null
            ? null
            : conv.otherParticipantRole(currentUser.id));
        final user = UserModel(
            id: conv.otherUserId,
            fullName: conv.otherUserName,
            email: '',
            phone: '',
            city: '',
            role: role);
        ref.read(conversationsProvider.notifier).startConversation(user);
        Navigator.push(
            ctx,
            MaterialPageRoute(
                builder: (_) => ContractorChatScreen(otherUser: user)));
      },
      onAvatarTap: (ctx, conv) {
        final role = _chatRoleFromString(currentUser == null
            ? null
            : conv.otherParticipantRole(currentUser.id));
        final user = UserModel(
            id: conv.otherUserId,
            fullName: conv.otherUserName,
            email: '',
            phone: '',
            city: '',
            role: role);
        _openUserProfile(ctx, user, ChatTheme.contractor);
      },
      onOptions: (ctx, conv) =>
          showConvOptionsDialog(ctx, conv, ChatTheme.contractor),
    );
  }
}

// ─── Shared Messages Scaffold ─────────────────────────────────────────────────
class _MessagesScaffold extends ConsumerWidget {
  final AppLocalizations l;
  final bool isDark;
  final ChatTheme theme;
  final List<ConversationModel> filtered;
  final TextEditingController ctrl;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final void Function(BuildContext, ConversationModel) onTap;
  final void Function(BuildContext, ConversationModel) onOptions;
  final void Function(BuildContext, ConversationModel)? onAvatarTap;

  const _MessagesScaffold({
    required this.l,
    required this.isDark,
    required this.theme,
    required this.filtered,
    required this.ctrl,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.onTap,
    required this.onOptions,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : theme.bgPage,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryDark, theme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Text(l.get('messages'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3)),
                ),
                _MyChatRequestsButton(theme: theme),
              ]),
            )),
          ),
        ),
        body: Column(children: [
          _ChatSearchBar(
              theme: theme,
              isDark: isDark,
              ctrl: ctrl,
              query: query,
              onChanged: onChanged,
              onClear: onClear),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyConvState(theme: theme, isEmpty: query.isEmpty, l: l)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 80,
                      color: isDark
                          ? AppColors.darkBorder
                          : theme.primaryLight.withOpacity(0.6),
                    ),
                    itemBuilder: (ctx, i) => _ConvTile(
                      conv: filtered[i],
                      theme: theme,
                      isDark: isDark,
                      onTap: () => onTap(ctx, filtered[i]),
                      onAvatarTap: onAvatarTap != null
                          ? () => onAvatarTap!(ctx, filtered[i])
                          : null,
                      onLongPress: () => onOptions(ctx, filtered[i]),
                    ),
                  ),
          ),
        ]),
      );
}

// ─── My Chat Requests button — opens the shared user-side tracking page ─────
class _MyChatRequestsButton extends StatelessWidget {
  final ChatTheme theme;
  const _MyChatRequestsButton({required this.theme});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CustomerChatRequestsScreen())),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.assignment_outlined, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('My Requests',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────
class _ChatSearchBar extends StatelessWidget {
  final ChatTheme theme;
  final bool isDark;
  final TextEditingController ctrl;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ChatSearchBar(
      {required this.theme,
      required this.isDark,
      required this.ctrl,
      required this.query,
      required this.onChanged,
      required this.onClear});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : theme.searchBg,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : theme.inputBorder.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: theme.primaryDark.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.search_rounded,
                    size: 18, color: theme.primary.withOpacity(0.7))),
            Expanded(
              child: TextField(
                controller: ctrl,
                onChanged: onChanged,
                style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : const Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.of(context).get('search_conversations'),
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                      fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 16, color: theme.primary.withOpacity(0.6)),
                          onPressed: onClear)
                      : null,
                ),
              ),
            ),
          ]),
        ),
      );
}

class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final ChatTheme theme;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onAvatarTap;

  const _ConvTile(
      {required this.conv,
      required this.theme,
      required this.isDark,
      required this.onTap,
      required this.onLongPress,
      this.onAvatarTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: Colors.transparent,
          child: Row(children: [
            // Avatar (tap → profile)
            GestureDetector(
              onTap: onAvatarTap ?? onTap,
              behavior: HitTestBehavior.opaque,
              child: Stack(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.avatarGradientStart,
                        theme.avatarGradientEnd
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: theme.primaryDark.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Consumer(builder: (context, ref, _) {
                    final otherUser = conv.otherUserId.isNotEmpty
                        ? ref
                            .watch(userByIdProvider(conv.otherUserId))
                            .valueOrNull
                        : null;
                    return ProfileAvatarImage(
                      imageUrl: otherUser?.avatar,
                      size: 54,
                      fallbackText: conv.otherUserName,
                      fallbackTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20),
                    );
                  }),
                ),
                if (conv.isOnline)
                  Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: const BoxDecoration(
                            color: Color(0xFF00D97E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 0,
                                  spreadRadius: 2)
                            ]),
                      )),
              ]),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(conv.otherUserName,
                            style: TextStyle(
                              fontWeight: conv.unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 15,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF1A1A1A),
                            ))),
                    Text(_fmt(conv.lastMessageTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: conv.unreadCount > 0
                              ? theme.primary
                              : Colors.grey.shade400,
                          fontWeight: conv.unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    if (conv.isBlocked) ...[
                      Icon(Icons.block_rounded,
                          size: 12, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                        child:
                            Text(conv.isBlocked ? 'Blocked' : conv.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: conv.isBlocked
                                      ? Colors.red.shade400
                                      : conv.unreadCount > 0
                                          ? (isDark
                                              ? AppColors.darkTextPrimary
                                              : const Color(0xFF333333))
                                          : Colors.grey.shade500,
                                  fontWeight: conv.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ))),
                    if (conv.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                theme.avatarGradientStart,
                                theme.avatarGradientEnd
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${conv.unreadCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                  ]),
                ])),
          ]),
        ),
      );

  String _fmt(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

// ─── Blocked Users Screen ─────────────────────────────────────────────────────
// Shows everyone the current user has blocked (Firestore-backed, Phase
// 6C-2). No longer reachable from the Messages page header — the top-right
// icon that linked here was removed — but kept around and Firestore-wired in
// case a future entry point is added.
class BlockedUsersScreen extends ConsumerWidget {
  final ChatTheme theme;
  const BlockedUsersScreen({super.key, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider);
    final firestoreConvs =
        ref.watch(currentUserConversationsProvider).valueOrNull ??
            const <ConversationModel>[];
    final blocked = currentUser == null
        ? const <ConversationModel>[]
        : firestoreConvs
            .where((c) => c.isBlocked && c.blockedBy == currentUser.id)
            .map((c) {
            final otherId = c.otherParticipantId(currentUser.id);
            final otherName = c.otherParticipantName(currentUser.id);
            return ConversationModel(
              id: c.id,
              otherUserId: otherId,
              otherUserName: otherName,
              lastMessage: c.lastMessage,
              lastMessageTime: c.lastMessageTime,
              isBlocked: c.isBlocked,
              blockedBy: c.blockedBy,
            );
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : theme.bgPage,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryDark, theme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Text('Blocked Users',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3)),
              ]),
            ),
          ),
        ),
      ),
      body: blocked.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: theme.primaryLight.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.block_rounded,
                        color: theme.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('No blocked users',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text('Users you block will appear here.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: blocked.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final conv = blocked[i];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : theme.primaryLight.withOpacity(0.6)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.avatarGradientStart.withOpacity(0.7),
                              theme.avatarGradientEnd.withOpacity(0.7)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Consumer(builder: (context, ref, _) {
                          final otherUser = conv.otherUserId.isNotEmpty
                              ? ref
                                  .watch(userByIdProvider(conv.otherUserId))
                                  .valueOrNull
                              : null;
                          return ProfileAvatarImage(
                            imageUrl: otherUser?.avatar,
                            size: 46,
                            fallbackText: conv.otherUserName,
                            fallbackTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          );
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(conv.otherUserName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : const Color(0xFF1A1A1A))),
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.block_rounded,
                                  size: 12, color: Colors.red.shade400),
                              const SizedBox(width: 4),
                              Text('Blocked',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ])),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _confirmUnblock(ctx, ref, conv),
                        child: const Text('Unblock',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  void _confirmUnblock(
      BuildContext context, WidgetRef ref, ConversationModel conv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Unblock ${conv.otherUserName}?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(
            'You will be able to send and receive messages from ${conv.otherUserName} again.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _unblockConversation(context, ref, conv);
            },
            child: const Text('Unblock',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Conversation Options Dialog ───────────────────────────────────────────────
void showConvOptionsDialog(
    BuildContext context, ConversationModel conv, ChatTheme theme) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _ConvOptionsDialog(conv: conv, theme: theme),
  );
}

class _ConvOptionsDialog extends ConsumerStatefulWidget {
  final ConversationModel conv;
  final ChatTheme theme;
  const _ConvOptionsDialog({required this.conv, required this.theme});
  @override
  ConsumerState<_ConvOptionsDialog> createState() => _ConvOptionsDialogState();
}

class _ConvOptionsDialogState extends ConsumerState<_ConvOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final isBlocked = widget.conv.isBlocked;
    final blockedByMe =
        currentUser != null && widget.conv.blockedBy == currentUser.id;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 32,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        widget.theme.avatarGradientStart,
                        widget.theme.avatarGradientEnd
                      ]),
                      borderRadius: BorderRadius.circular(13)),
                  child: Center(
                      child: Text(
                          widget.conv.otherUserName.isNotEmpty
                              ? widget.conv.otherUserName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.conv.otherUserName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text('Conversation options',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ])),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Block / Unblock — Firestore-backed (Phase 6C-2) ──
          if (!isBlocked)
            _DialogOption(
              icon: Icons.block_rounded,
              label: AppLocalizations.of(context).get('block_user'),
              iconBg: Colors.orange.shade50,
              iconColor: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirm(context, widget.conv, ref);
              },
            )
          else if (blockedByMe)
            _DialogOption(
              icon: Icons.lock_open_rounded,
              label: 'Unblock User',
              iconBg: Colors.orange.shade50,
              iconColor: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _unblockConversation(context, ref, widget.conv);
              },
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.block_rounded,
                        color: Colors.grey.shade400, size: 18)),
                const SizedBox(width: 14),
                Expanded(
                    child: Text('You were blocked by this user.',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500))),
              ]),
            ),
          Divider(height: 1, indent: 56, color: Colors.grey.shade100),

          // ── Request to Chat with Admin ──
          _DialogOption(
            icon: Icons.support_agent_rounded,
            label: 'Request to Chat with Admin',
            iconBg: const Color(0xFF7B2FBE).withOpacity(0.08),
            iconColor: const Color(0xFF7B2FBE),
            labelColor: const Color(0xFF7B2FBE),
            onTap: () {
              Navigator.pop(context);
              showAdminChatRequestSheet(context, widget.conv, ref);
            },
          ),

          // Cancel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('cancel'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Block Confirm ─────────────────────────────────────────────────────────────
void _showBlockConfirm(
    BuildContext context, ConversationModel conv, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Block ${conv.otherUserName}?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(
          'You won\'t be able to send or receive messages from ${conv.otherUserName}.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel',
              style:
                  TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () {
            Navigator.pop(ctx);
            _blockConversation(context, ref, conv);
          },
          child: const Text('Block',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

// ── Firestore Block / Unblock actions (Phase 6C-2) — shared by the long-press
// options dialog and BlockedUsersScreen so both use the same error handling
// and messaging.
Future<void> _blockConversation(
    BuildContext context, WidgetRef ref, ConversationModel conv) async {
  final currentUser = ref.read(authProvider);
  if (currentUser == null) return;
  try {
    await blockConversationInFirestore(
        conversationId: conv.id, currentUserId: currentUser.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('User blocked successfully'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  } catch (e) {
    debugPrint('CHAT_BLOCK_ERROR: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Failed to update block status. Please try again.'),
        backgroundColor: CustomerColors.error,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

Future<void> _unblockConversation(
    BuildContext context, WidgetRef ref, ConversationModel conv) async {
  final currentUser = ref.read(authProvider);
  if (currentUser == null) return;
  try {
    await unblockConversationInFirestore(
        conversationId: conv.id, currentUserId: currentUser.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('User unblocked successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  } catch (e) {
    debugPrint('CHAT_UNBLOCK_ERROR: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Failed to update block status. Please try again.'),
        backgroundColor: CustomerColors.error,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

// ── Report Dialog → يحوّل للشكاوي ────────────────────────────────────────────
class _ReportDialog extends ConsumerStatefulWidget {
  final ConversationModel conv;
  const _ReportDialog({required this.conv});
  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  int _selected = -1;
  final _reasons = [
    'Inappropriate behavior',
    'Offensive language',
    'Harassment',
    'Spam or scam',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.flag_rounded,
                    color: CustomerColors.error, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Report User',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1A1A2E))),
                  Text('Report ${widget.conv.otherUserName}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ])),
          ]),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 8),
          ..._reasons.asMap().entries.map((e) => InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selected = e.key),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _selected == e.key
                                ? CustomerColors.error
                                : Colors.grey.shade400,
                            width: 2),
                        color: _selected == e.key
                            ? CustomerColors.error
                            : Colors.transparent,
                      ),
                      child: _selected == e.key
                          ? const Icon(Icons.circle,
                              size: 10, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(e.value,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1A1A2E))),
                  ]),
                ),
              )),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected >= 0
                    ? CustomerColors.error
                    : Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _selected < 0
                  ? null
                  : () {
                      // أنشئ شكوى وأضفها لـ complaintsProvider
                      final currentUser = ref.read(authProvider);
                      final complaint = ComplaintModel(
                        id: 'cmp_${DateTime.now().millisecondsSinceEpoch}',
                        userId: currentUser?.id ?? 'current_user',
                        userName: currentUser?.fullName ?? 'User',
                        type: ComplaintType.provider,
                        targetId: widget.conv.otherUserId,
                        targetName: widget.conv.otherUserName,
                        reason: _reasons[_selected],
                        description: 'User reported from chat conversation.',
                        priority: ComplaintPriority.medium,
                        createdAt: DateTime.now(),
                      );
                      ref
                          .read(complaintsProvider.notifier)
                          .addComplaint(complaint);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text(
                            'Report submitted. Admin will review it.'),
                        backgroundColor: CustomerColors.error,
                        behavior: SnackBarBehavior.fixed,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
              child: const Text('Submit Report',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    );
  }
}

void showReportDialog(
    BuildContext context, ConversationModel conv, WidgetRef ref) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _ReportDialog(conv: conv),
  );
}

// ── Request to Chat with Admin — Bottom Sheet ─────────────────────────────────
void showAdminChatRequestSheet(
    BuildContext context, ConversationModel conv, WidgetRef ref,
    {String? reportedUserRole}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AdminChatRequestSheet(
        conv: conv, ref: ref, reportedUserRole: reportedUserRole),
  );
}

class _AdminChatRequestSheet extends StatefulWidget {
  final ConversationModel conv;
  final WidgetRef ref;
  final String? reportedUserRole;
  const _AdminChatRequestSheet(
      {required this.conv, required this.ref, this.reportedUserRole});
  @override
  State<_AdminChatRequestSheet> createState() => _AdminChatRequestSheetState();
}

class _AdminChatRequestSheetState extends State<_AdminChatRequestSheet> {
  int _selectedType = -1;
  final _descCtrl = TextEditingController();

  final _types = [
    _RequestType(
        icon: Icons.edit_outlined,
        label: 'Edit a Message',
        color: Color(0xFF3B82F6)),
    _RequestType(
        icon: Icons.delete_outline,
        label: 'Delete a Message',
        color: CustomerColors.error),
    _RequestType(
        icon: Icons.report_gmailerrorred_outlined,
        label: 'Inappropriate Messages',
        color: Colors.orange),
    _RequestType(
        icon: Icons.help_outline_rounded,
        label: 'Other Issue',
        color: Color(0xFF7B2FBE)),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: const Color(0xFF7B2FBE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.support_agent_rounded,
                  color: Color(0xFF7B2FBE), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Request Admin Help',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E))),
                  Text('Regarding: ${widget.conv.otherUserName}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ])),
          ]),
        ),
        Divider(color: Colors.grey.shade100, height: 20),

        // Issue type selection
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('What do you need help with?',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            ..._types.asMap().entries.map((e) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedType = e.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedType == e.key
                          ? e.value.color.withOpacity(0.07)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedType == e.key
                            ? e.value.color
                            : Colors.grey.shade200,
                        width: _selectedType == e.key ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: e.value.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child:
                            Icon(e.value.icon, color: e.value.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(e.value.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedType == e.key
                                      ? e.value.color
                                      : const Color(0xFF1A1A2E)))),
                      if (_selectedType == e.key)
                        Icon(Icons.check_circle_rounded,
                            color: e.value.color, size: 18),
                    ]),
                  ),
                )),
          ]),
        ),

        // Description field
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: TextField(
            controller: _descCtrl,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe the issue (optional)...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF7B2FBE), width: 1.5)),
            ),
          ),
        ),

        // Buttons
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Row(children: [
            Expanded(
                child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton.icon(
              onPressed: _selectedType < 0
                  ? null
                  : () async {
                      final currentUser = widget.ref.read(authProvider);
                      if (currentUser == null) return;
                      final issueLabel = _types[_selectedType].label;
                      final desc = _descCtrl.text.trim();
                      final conversationId = getConversationId(
                          currentUser.id, widget.conv.otherUserId);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      try {
                        await createChatReportInFirestore(
                          conversationId: conversationId,
                          reporterId: currentUser.id,
                          reporterName: currentUser.fullName,
                          reporterRole: currentUser.role.name,
                          reportedUserId: widget.conv.otherUserId,
                          reportedUserName: widget.conv.otherUserName,
                          reportedUserRole: widget.reportedUserRole,
                          reason: issueLabel,
                          description: desc.isEmpty ? null : desc,
                        );
                        messenger.showSnackBar(const SnackBar(
                          content: Text('Your request was sent to the admin.'),
                          backgroundColor: Color(0xFF7B2FBE),
                          behavior: SnackBarBehavior.fixed,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12))),
                        ));
                      } catch (e) {
                        messenger.showSnackBar(const SnackBar(
                          content:
                              Text('Failed to send request. Please try again.'),
                          backgroundColor: CustomerColors.error,
                          behavior: SnackBarBehavior.fixed,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12))),
                        ));
                      }
                    },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Request',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType >= 0
                    ? const Color(0xFF7B2FBE)
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _RequestType {
  final IconData icon;
  final String label;
  final Color color;
  const _RequestType(
      {required this.icon, required this.label, required this.color});
}

class _DialogOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBg, iconColor;
  final Color? labelColor;
  final VoidCallback onTap;
  const _DialogOption({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18)),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? const Color(0xFF1A1A2E))),
          ]),
        ),
      );
}

class _EmptyConvState extends StatelessWidget {
  final ChatTheme theme;
  final bool isEmpty;
  final AppLocalizations l;
  const _EmptyConvState(
      {required this.theme, required this.isEmpty, required this.l});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.primaryLight,
                  theme.primaryLight.withOpacity(0.5)
                ]),
                shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: theme.primary)),
        const SizedBox(height: 16),
        Text(isEmpty ? l.get('no_messages') : l.get('no_results'),
            style: TextStyle(
                color: theme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ]));
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
//
// Opens a profile view for the tapped user. For provider-type users (professional /
// contractor / supplier / worker) we route to the full ProviderProfileScreen which
// already supports any UserModel. For customers (when a contractor/professional taps
// their avatar) we show a compact bottom sheet with their name + city, since the
// project does not expose a dedicated "customer-profile-as-seen-by-others" screen.
void _openUserProfile(BuildContext context, UserModel user, ChatTheme theme) {
  final isProvider =
      user.role == UserRole.professional || user.role == UserRole.contractor;

  if (isProvider) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(provider: user)));
    return;
  }

  // Customer "view profile" -> compact bottom sheet
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.primaryLight,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [theme.avatarGradientStart, theme.avatarGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
          child: Consumer(builder: (context, ref, _) {
            final liveUser = user.id.isNotEmpty
                ? ref.watch(userByIdProvider(user.id)).valueOrNull
                : null;
            return ProfileAvatarImage(
              imageUrl: liveUser?.avatar ?? user.avatar,
              size: 80,
              fallbackText: user.fullName,
              fallbackTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(user.fullName.isNotEmpty ? user.fullName : 'Customer',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20)),
          child: Text('Customer',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.primary,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 18),
        if (user.city.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.location_on_outlined,
                      color: theme.primary, size: 18)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('City',
                    style: TextStyle(
                        fontSize: 11, color: theme.primary.withOpacity(0.7))),
                Text(user.city,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        if (user.phone.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.phone_outlined,
                      color: theme.primary, size: 18)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Phone',
                    style: TextStyle(
                        fontSize: 11, color: theme.primary.withOpacity(0.7))),
                Text(user.phone,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
      ]),
    ),
  );
}
