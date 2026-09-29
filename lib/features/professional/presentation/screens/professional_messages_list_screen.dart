// ─────────────────────────────────────────────────────────────────────────────
// Professional Messages List — Professional-owned copy of
// ProfessionalMessagesScreenWrapper (lib/features/customer/presentation/
// screens/customer_messages_screen.dart), restyled to the Professional UI
// Kit. Same Firestore reads (currentUserConversationsProvider) and the same
// navigation/callback behavior — visuals only differ. The shared/Customer
// originals stay untouched.
//
// Note: this also fixes a "My Requests" button regression — the shared
// _MyChatRequestsButton this screen used to delegate to (via
// ProfessionalMessagesScreenWrapper -> _MessagesScaffold, both private to
// customer_messages_screen.dart) was repointed during the Customer redesign
// to the Customer-only CustomerChatRequestsScreen. This copy instead uses
// the original, still-unmodified, role-parametrized MyChatRequestsScreen
// (lib/shared/screens/my_chat_requests_screen.dart) with professionalChatTheme.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/shared_widgets.dart' show ProfileAvatarImage;
import '../../../../shared/screens/my_chat_requests_screen.dart';
import '../../../customer/presentation/screens/customer_messages_screen.dart'
    show showConvOptionsDialog;
import '../../../customer/presentation/screens/provider_profile_screen.dart';
import '../theme/professional_design.dart';
import 'professional_chat_screen.dart';

// Maps the plain-string role stored in Firestore's participantRoles back to
// UserRole — mirrors _chatRoleFromString in customer_messages_screen.dart.
UserRole _profChatRoleFromString(String? s) {
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

List<ConversationModel> _profFirestoreDisplayConvs(WidgetRef ref) {
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
      participantIds: [currentUser.id, otherId],
      participantRoles: {otherId: otherRole ?? ''},
    );
  }).toList();
}

void _profOpenUserProfile(BuildContext context, UserModel user) {
  final isProvider =
      user.role == UserRole.professional || user.role == UserRole.contractor;

  if (isProvider) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProviderProfileScreen(provider: user)));
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: ProfessionalColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ProfessionalRadii.sheet)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: ProfessionalColors.border,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: ProfessionalColors.primaryGradient,
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
            style: ProfessionalText.headline),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: ProfessionalColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(ProfessionalRadii.pill)),
          child: const Text('Customer',
              style: TextStyle(
                  fontSize: 12,
                  color: ProfessionalColors.primaryDark,
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
                      color: ProfessionalColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.location_on_outlined,
                      color: ProfessionalColors.primaryDark, size: 18)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('City',
                    style: TextStyle(fontSize: 11, color: ProfessionalColors.textSecondary)),
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
                      color: ProfessionalColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.phone_outlined,
                      color: ProfessionalColors.primaryDark, size: 18)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Phone',
                    style: TextStyle(fontSize: 11, color: ProfessionalColors.textSecondary)),
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

class ProfessionalMessagesListScreen extends ConsumerStatefulWidget {
  const ProfessionalMessagesListScreen({super.key});

  @override
  ConsumerState<ProfessionalMessagesListScreen> createState() =>
      _ProfessionalMessagesListScreenState();
}

class _ProfessionalMessagesListScreenState
    extends ConsumerState<ProfessionalMessagesListScreen> {
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
    final currentUser = ref.watch(authProvider);
    final convs = _profFirestoreDisplayConvs(ref);

    final filtered = _q.isEmpty
        ? convs
        : convs
            .where(
                (c) => c.otherUserName.toLowerCase().contains(_q.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: ProfessionalColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(gradient: ProfessionalColors.primaryGradient),
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
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ),
                _ProfMyChatRequestsButton(),
              ]),
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: ProfessionalColors.card,
              borderRadius: BorderRadius.circular(ProfessionalRadii.pill),
              border: Border.all(color: ProfessionalColors.border.withOpacity(0.4)),
              boxShadow: ProfessionalShadows.soft,
            ),
            child: Row(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.search_rounded,
                      size: 18, color: ProfessionalColors.primary.withOpacity(0.7))),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(fontSize: 14, color: ProfessionalColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).get('search_conversations'),
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _q.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 16, color: ProfessionalColors.primary.withOpacity(0.6)),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() => _q = '');
                            })
                        : null,
                  ),
                ),
              ),
            ]),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? ProfessionalEmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: _q.isEmpty ? l.get('no_messages') : l.get('no_results'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 80,
                    color: ProfessionalColors.border.withOpacity(0.4),
                  ),
                  itemBuilder: (ctx, i) {
                    final conv = filtered[i];
                    return _ProfConvTile(
                      conv: conv,
                      onTap: () {
                        final role = _profChatRoleFromString(currentUser == null
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
                      onAvatarTap: () {
                        final role = _profChatRoleFromString(currentUser == null
                            ? null
                            : conv.otherParticipantRole(currentUser.id));
                        final user = UserModel(
                            id: conv.otherUserId,
                            fullName: conv.otherUserName,
                            email: '',
                            phone: '',
                            city: '',
                            role: role);
                        _profOpenUserProfile(ctx, user);
                      },
                      onLongPress: () =>
                          showConvOptionsDialog(ctx, conv, professionalChatTheme),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _ProfMyChatRequestsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(ProfessionalRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(ProfessionalRadii.pill),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const MyChatRequestsScreen(theme: professionalChatTheme))),
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

class _ProfConvTile extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onAvatarTap;

  const _ProfConvTile({
    required this.conv,
    required this.onTap,
    required this.onLongPress,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: Colors.transparent,
          child: Row(children: [
            GestureDetector(
              onTap: onAvatarTap ?? onTap,
              behavior: HitTestBehavior.opaque,
              child: Stack(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: ProfessionalColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: ProfessionalShadows.soft,
                  ),
                  child: Consumer(builder: (context, ref, _) {
                    final otherUser = conv.otherUserId.isNotEmpty
                        ? ref.watch(userByIdProvider(conv.otherUserId)).valueOrNull
                        : null;
                    return ProfileAvatarImage(
                      imageUrl: otherUser?.avatar,
                      size: 54,
                      fallbackText: conv.otherUserName,
                      fallbackTextStyle: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
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
                            color: ProfessionalColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2)
                            ]),
                      )),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(conv.otherUserName,
                            style: TextStyle(
                              fontWeight: conv.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 15,
                              color: ProfessionalColors.textPrimary,
                            ))),
                    Text(_fmt(conv.lastMessageTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: conv.unreadCount > 0
                              ? ProfessionalColors.primaryDark
                              : Colors.grey.shade400,
                          fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                        )),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    if (conv.isBlocked) ...[
                      Icon(Icons.block_rounded, size: 12, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                        child: Text(conv.isBlocked ? 'Blocked' : conv.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: conv.isBlocked
                                  ? Colors.red.shade400
                                  : conv.unreadCount > 0
                                      ? ProfessionalColors.textPrimary
                                      : Colors.grey.shade500,
                              fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                            ))),
                    if (conv.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: ProfessionalColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${conv.unreadCount}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
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
