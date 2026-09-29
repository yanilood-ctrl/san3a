// Contractor Chat Screen — independent chat code for the contractor role.
// Shares only the visual ChatTheme; behavior (block, send, edit, etc.) is local.
import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/chat_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/providers/app_providers.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/helpers/phone_call_helper.dart';
import '../../../../shared/widgets/chat_message_translate_action.dart';
import '../../../customer/presentation/screens/customer_messages_screen.dart'
    show showReportDialog, showAdminChatRequestSheet;
import '../theme/contractor_design.dart';

// ─── Contractor Chat Screen ──────────────────────────────────────────────────────────────
class ContractorChatScreen extends ConsumerStatefulWidget {
  final UserModel otherUser;
  // Optional prefilled draft for the message input — e.g. the Contractor AI
  // Crew & Order Planner's generated customer message. Purely a starting
  // value for the existing, fully-editable message field: never sent
  // automatically, never persisted, and ignored entirely when null, empty,
  // or whitespace-only. Every existing caller that omits this argument
  // keeps its exact current behavior.
  final String? initialDraftText;
  const ContractorChatScreen({
    super.key,
    required this.otherUser,
    this.initialDraftText,
  });
  @override
  ConsumerState<ContractorChatScreen> createState() =>
      _ContractorChatScreenState();
}

class _ContractorChatScreenState extends ConsumerState<ContractorChatScreen>
    with TickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  String? _editingMessageId;
  bool _showTyping = false;
  bool _showEmoji = false;

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String?
      _recordingPath; // mobile temp file path; null on Web (record returns a blob: URL instead)
  bool _sendingVoice =
      false; // Phase 6F: Firebase Storage voice upload in flight
  // Voice messages sent by this screen, merged into the rendered list until
  // the Firestore stream re-emits with the same id — see _stopAndSend.
  final List<MessageModel> _optimisticMessages = [];
  // Web-safe image state: bytes for display (all platforms), path for mobile send
  Uint8List? _pendingImageBytes;
  String? _pendingImagePath; // null on Web
  bool _uploadingImage =
      false; // Phase 6E: Firebase Storage image upload in flight

  late AnimationController _typingCtrl;
  late Animation<double> _dot1, _dot2, _dot3;

  @override
  void initState() {
    super.initState();
    // One-time-only prefill of the existing message field from an optional
    // AI-generated draft — never re-applied on rebuild, so once the
    // Contractor edits or clears the field it never comes back. The
    // controller is always freshly empty at this point (nothing else
    // populates it in initState), so no other "meaningful initial text"
    // source can be clobbered here.
    final draft = widget.initialDraftText?.trim();
    if (draft != null && draft.isNotEmpty) {
      _msgCtrl.text = draft;
      _msgCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: draft.length));
    }
    _typingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _dot1 = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _typingCtrl, curve: const Interval(0.0, 0.6)));
    _dot2 = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _typingCtrl, curve: const Interval(0.2, 0.8)));
    _dot3 = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _typingCtrl, curve: const Interval(0.4, 1.0)));
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) setState(() => _showEmoji = false);
    });
    // Ensure conversation entry exists so blockUser/unblockUser can find it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(conversationsProvider.notifier)
          .startConversation(widget.otherUser);
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingCtrl.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // Phase 6E: pick + upload an image straight to Firebase Storage / Firestore.
  // Both attach-sheet sources go through here: Gallery picks an existing
  // image, Camera launches the device camera. Everything after the pick —
  // block check, upload, Firestore write, error handling — is identical for
  // the two sources, so there is exactly one send path.
  Future<void> _sendImageFromSource(ImageSource src) async {
    if (_uploadingImage) return;
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    final conversationId =
        getConversationId(currentUser.id, widget.otherUser.id);
    final firestoreConv =
        ref.read(conversationByIdProvider(conversationId)).valueOrNull;
    if (firestoreConv?.isBlocked ?? false) {
      if (mounted)
        _showTopSnack(context, 'This conversation is blocked.',
            color: AppColors.error);
      return;
    }

    XFile? xfile;
    try {
      xfile = await ImagePicker().pickImage(source: src, imageQuality: 80);
    } catch (_) {
      if (mounted)
        _showTopSnack(context, 'Could not access media. Check permissions.',
            color: AppColors.error);
      return;
    }
    if (xfile == null) return;

    setState(() => _uploadingImage = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ok = await sendImageMessageToUser(
        senderId: currentUser.id,
        senderName: currentUser.fullName,
        senderRole: currentUser.role.name,
        receiverId: widget.otherUser.id,
        receiverName: widget.otherUser.fullName,
        receiverRole: widget.otherUser.role.name,
        imageBytes: bytes,
        fileName: xfile.name,
      );
      if (!mounted) return;
      _showTopSnack(
        context,
        ok
            ? 'Image sent successfully'
            : 'Failed to send image. Please try again.',
        color: ok ? Colors.green.shade700 : AppColors.error,
      );
      if (ok) _scrollToBottom();
    } catch (e) {
      debugPrint('CHAT_IMAGE_SEND_ERROR: $e');
      if (mounted)
        _showTopSnack(context, 'Failed to send image. Please try again.',
            color: AppColors.error);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // Resets unreadCount + isRead for the current user on this conversation.
  // Safe to call repeatedly — no-ops once everything is already read.
  void _markAsRead() {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    final conversationId =
        getConversationId(currentUser.id, widget.otherUser.id);
    markConversationAsReadInFirestore(
        conversationId: conversationId, currentUserId: currentUser.id);
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _pendingImageBytes == null) return;
    if (_pendingImageBytes != null) {
      ref.read(conversationsProvider.notifier).sendMediaMessage(
            widget.otherUser.id,
            type: MessageType.image,
            text: text.isEmpty ? 'Photo' : text,
            mediaPath:
                _pendingImagePath ?? '', // empty on Web (display via bytes)
            mediaBytes: _pendingImageBytes,
          );
      setState(() {
        _pendingImageBytes = null;
        _pendingImagePath = null;
      });
      _msgCtrl.clear();
      _scrollToBottom();
      return;
    }
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    if (text.isEmpty) {
      _showTopSnack(context, 'Please enter a message.', color: AppColors.error);
      return;
    }
    if (_editingMessageId != null) {
      final conversationId =
          getConversationId(currentUser.id, widget.otherUser.id);
      bool ok = false;
      try {
        ok = await editTextMessageInFirestore(
          conversationId: conversationId,
          messageId: _editingMessageId!,
          currentUserId: currentUser.id,
          newText: text,
        );
      } catch (e) {
        debugPrint('CHAT_EDIT_ERROR: $e');
        ok = false;
      }
      if (!mounted) return;
      _showTopSnack(
        context,
        ok
            ? 'Message updated successfully'
            : 'Failed to update message. Please try again.',
        color: ok ? Colors.green.shade700 : AppColors.error,
      );
      setState(() => _editingMessageId = null);
      _msgCtrl.clear();
      _scrollToBottom();
      return;
    }
    final sent = await sendTextMessageToUser(
      senderId: currentUser.id,
      senderName: currentUser.fullName,
      senderRole: currentUser.role.name,
      receiverId: widget.otherUser.id,
      receiverName: widget.otherUser.fullName,
      receiverRole: widget.otherUser.role.name,
      text: text,
    );
    if (!mounted) return;
    if (!sent) {
      _showTopSnack(context, 'This conversation is blocked.',
          color: AppColors.error);
      return;
    }
    setState(() => _showTyping = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showTyping = false);
    });
    _msgCtrl.clear();
    _scrollToBottom();
  }

  Future<void> _handleBlock(String conversationId) async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    try {
      await blockConversationInFirestore(
          conversationId: conversationId, currentUserId: currentUser.id);
      if (mounted)
        _showTopSnack(context, 'User blocked successfully',
            color: Colors.orange);
    } catch (e) {
      debugPrint('CHAT_BLOCK_ERROR: $e');
      if (mounted)
        _showTopSnack(
            context, 'Failed to update block status. Please try again.',
            color: AppColors.error);
    }
  }

  Future<void> _handleUnblock(String conversationId) async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    try {
      await unblockConversationInFirestore(
          conversationId: conversationId, currentUserId: currentUser.id);
      if (mounted)
        _showTopSnack(context, 'User unblocked successfully',
            color: Colors.green.shade700);
    } catch (e) {
      debugPrint('CHAT_UNBLOCK_ERROR: $e');
      if (mounted)
        _showTopSnack(
            context, 'Failed to update block status. Please try again.',
            color: AppColors.error);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _toggleEmoji() {
    if (_showEmoji)
      _focusNode.requestFocus();
    else
      _focusNode.unfocus();
    setState(() => _showEmoji = !_showEmoji);
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _msgCtrl.text;
    final sel = _msgCtrl.selection;
    final newText = sel.isValid
        ? text.replaceRange(sel.start, sel.end, emoji.emoji)
        : text + emoji.emoji;
    _msgCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: (sel.isValid ? sel.start : text.length) + emoji.emoji.length),
    );
  }

  void _showAttachSheet(BuildContext ctx, ChatTheme theme) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (dCtx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6EFE6),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFD9C6B2), blurRadius: 20, offset: Offset(8, 8)),
            BoxShadow(
                color: Colors.white, blurRadius: 20, offset: Offset(-8, -8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD9C6B2),
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                    color: Colors.white, blurRadius: 2, offset: Offset(-1, -1)),
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 2,
                    offset: Offset(1, 1)),
              ],
            ),
          )),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF6EFE6),
                boxShadow: [
                  BoxShadow(
                      color: Color(0xFFD9C6B2),
                      blurRadius: 8,
                      offset: Offset(4, 4)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 8,
                      offset: Offset(-4, -4)),
                ],
              ),
              child: Icon(Icons.share_rounded, color: theme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Text('Share Content',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2B1B12))),
          ]),
          const SizedBox(height: 22),
          Row(children: [
            _AttOpt(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: theme.primary,
                onTap: () {
                  Navigator.pop(dCtx);
                  _sendImageFromSource(ImageSource.gallery);
                }),
            const SizedBox(width: 12),
            _AttOpt(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: theme.primaryDark,
                onTap: () {
                  Navigator.pop(dCtx);
                  _sendImageFromSource(ImageSource.camera);
                }),
            const SizedBox(width: 12),
            _AttOpt(
                icon: Icons.mic_rounded,
                label: 'Voice',
                color: const Color(0xFFE53935),
                onTap: () {
                  Navigator.pop(dCtx);
                  _startRecording();
                }),
          ]),
          const SizedBox(height: 16),
          _NeoCancelBtn(onTap: () => Navigator.pop(dCtx), label: 'Cancel'),
        ]),
      ),
    );
  }

  void _showTopSnack(BuildContext ctx, String message, {Color? color}) {
    const theme = contractorChatTheme;
    final bg = color ?? theme.primary;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
        ]),
        backgroundColor: bg,
        // Fixed, not floating: a floating SnackBar shown while this pushed
        // route still shares a ScaffoldMessenger with the home screen's
        // custom-bottomNavigationBar Scaffold underneath triggers "Floating
        // SnackBar presented off screen" — margin is dropped since it's only
        // valid for floating behavior.
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  void _showBlockConfirmFromChat(
      BuildContext ctx, String name, String conversationId) {
    // Use the widget's own stable context so dialog works after overlay dismissal
    final safeCtx = mounted ? context : ctx;
    showDialog(
      context: safeCtx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Block $name?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(
            'You won\'t be able to send or receive messages from $name.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _handleBlock(conversationId);
            },
            child: const Text('Block',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showQuickReplies(BuildContext ctx, ChatTheme theme) {
    final myRole = ref.read(authProvider)?.role.name;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dCtx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                offset: const Offset(0, -8))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 18),
              // Header card (like "Request a New Category" info box)
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: theme.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(Icons.quickreply_rounded,
                      color: theme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Quick Replies',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B1B12))),
                      const SizedBox(height: 2),
                      Text('Tap to insert into message',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ])),
              ]),
              const SizedBox(height: 16),
              // Info banner (like the category info box)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.primaryLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.primary.withOpacity(0.15)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: theme.primary, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        'Select a quick reply below to insert it directly into your message field.',
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.primary.withOpacity(0.8),
                            height: 1.4),
                      )),
                    ]),
              ),
              const SizedBox(height: 18),
              // Quick replies list (styled like form fields in category request)
              Consumer(builder: (context, qrRef, _) {
                final repliesAsync = qrRef.watch(quickRepliesProvider);
                return repliesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.4))),
                  ),
                  error: (e, st) {
                    debugPrint(
                        'QUICK_REPLIES_LOAD_ERROR [ContractorChatScreen]: $e');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                          child: Text('Failed to load quick replies',
                              style: TextStyle(
                                  color: Colors.red.shade400, fontSize: 14))),
                    );
                  },
                  data: (list) {
                    final replies = list
                        .where((r) => r.visibleToRole(myRole))
                        .map((r) => r.text)
                        .toList();
                    if (replies.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                            child: Text('No quick replies available',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14))),
                      );
                    }
                    return Column(
                        children: replies
                            .map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _QRTile(
                                    text: r,
                                    theme: theme,
                                    onTap: () {
                                      Navigator.pop(dCtx);
                                      _msgCtrl.text = r;
                                      _msgCtrl.selection =
                                          TextSelection.fromPosition(
                                              TextPosition(offset: r.length));
                                      _focusNode.requestFocus();
                                    },
                                  ),
                                ))
                            .toList());
                  },
                );
              }),
              const SizedBox(height: 4),
              // Close button styled like "Submit Request"
              GestureDetector(
                onTap: () => Navigator.pop(dCtx),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryDark, theme.primary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: theme.primaryDark.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Center(
                      child: Text('Close',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3))),
                ),
              ),
            ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final xfile =
          await ImagePicker().pickImage(source: src, imageQuality: 80);
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        setState(() {
          _pendingImageBytes = bytes;
          _pendingImagePath = kIsWeb ? null : xfile.path;
        });
      }
    } catch (_) {
      if (mounted)
        _showTopSnack(context, 'Could not access media. Check permissions.',
            color: AppColors.error);
    }
  }

  // Phase 6F fix: record_web's startStream() is unimplemented (throws
  // UnimplementedError unconditionally — see record_web's
  // MediaRecorderDelegate.startStream), which was the exact cause of
  // "Could not start recording." on Web. start()/stop() IS implemented on
  // Web: it records via MediaRecorder and stop() resolves to a blob: URL
  // string instead of a file path, so bytes are fetched via http.get
  // instead of File.readAsBytes in _stopAndSend.
  Future<void> _startRecording() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;
    final conversationId =
        getConversationId(currentUser.id, widget.otherUser.id);
    final firestoreConv =
        ref.read(conversationByIdProvider(conversationId)).valueOrNull;
    if (firestoreConv?.isBlocked ?? false) {
      if (mounted)
        _showTopSnack(context, 'This conversation is blocked.',
            color: AppColors.error);
      return;
    }
    try {
      final granted = await _recorder.hasPermission();
      debugPrint('CHAT_RECORD_PERMISSION hasPermission=$granted');
      if (!granted) {
        if (mounted)
          _showTopSnack(context, 'Microphone permission denied.',
              color: AppColors.error);
        return;
      }
      if (kIsWeb) {
        // path is required by the API but ignored by record_web's browser
        // MediaRecorder backend — the actual audio comes back as a blob URL
        // from stop().
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus),
            path: 'voice_recording');
        _recordingPath = null;
      } else {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path);
        _recordingPath = path;
      }
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e, st) {
      debugPrint('CHAT_RECORD_START_ERROR error=$e stack=$st');
      if (mounted)
        _showTopSnack(context, 'Could not start recording.',
            color: AppColors.error);
    }
  }

  Future<void> _stopAndSend() async {
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    Uint8List? bytes;
    var fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    var contentType = 'audio/mp4';
    try {
      final result = await _recorder.stop();
      if (kIsWeb) {
        // On Web, result is a blob: URL (created by record_web via
        // URL.createObjectURL) — fetch its bytes over http, not File I/O.
        if (result != null) {
          final response = await http.get(Uri.parse(result));
          bytes = response.bodyBytes;
        }
        fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
        contentType = 'audio/webm';
      } else if (result != null) {
        bytes = await File(result).readAsBytes();
        try {
          File(result).deleteSync();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('CHAT_VOICE_SEND_ERROR: $e');
      debugPrint('CHAT_VOICE_SEND_ERROR_STACK: $st');
    }
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordingPath = null;
    });

    if (bytes == null || bytes.isEmpty || seconds <= 0) return;

    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    setState(() => _sendingVoice = true);
    try {
      final sentMsg = await sendVoiceMessageToUser(
        senderId: currentUser.id,
        senderName: currentUser.fullName,
        senderRole: currentUser.role.name,
        receiverId: widget.otherUser.id,
        receiverName: widget.otherUser.fullName,
        receiverRole: widget.otherUser.role.name,
        audioBytes: bytes,
        fileName: fileName,
        durationSec: seconds,
        contentType: contentType,
      );
      final ok = sentMsg != null;
      if (!mounted) return;
      if (ok) {
        // Render immediately instead of waiting for the messages stream to
        // re-emit — see the note on sendVoiceMessageToUser.
        setState(() => _optimisticMessages.add(sentMsg));
      }
      _showTopSnack(
        context,
        ok
            ? 'Voice message sent successfully'
            : 'Failed to send voice message. Please try again.',
        color: ok ? Colors.green.shade700 : AppColors.error,
      );
      if (ok) _scrollToBottom();
    } catch (e) {
      debugPrint('VOICE_MESSAGE_SEND_ERROR: $e');
      if (mounted)
        _showTopSnack(
            context, 'Failed to send voice message. Please try again.',
            color: AppColors.error);
    } finally {
      if (mounted) setState(() => _sendingVoice = false);
    }
  }

  void _cancelRec() async {
    _recordTimer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (!kIsWeb && _recordingPath != null) {
      try {
        File(_recordingPath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordingPath = null;
    });
  }

  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMessageId = msg.id;
      _msgCtrl.text = msg.text;
      _msgCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: msg.text.length));
    });
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() => _editingMessageId = null);
    _msgCtrl.clear();
  }

  void _confirmDelete(BuildContext ctx, MessageModel msg) {
    final l = AppLocalizations.of(ctx);
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(l.get('delete_message'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              content: Text(l.get('delete_message_confirm')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l.get('cancel'))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final currentUser = ref.read(authProvider);
                    if (currentUser == null) return;
                    final conversationId =
                        getConversationId(currentUser.id, widget.otherUser.id);
                    bool ok = false;
                    try {
                      ok = await deleteMessageInFirestore(
                        conversationId: conversationId,
                        messageId: msg.id,
                        currentUserId: currentUser.id,
                      );
                    } catch (e) {
                      debugPrint('CHAT_DELETE_ERROR: $e');
                      ok = false;
                    }
                    if (!mounted) return;
                    _showTopSnack(
                      context,
                      ok
                          ? 'Message deleted successfully'
                          : 'Failed to delete message. Please try again.',
                      color: ok ? Colors.green.shade700 : AppColors.error,
                    );
                  },
                  child: const Text('Delete'),
                ),
              ],
            ));
  }

  void _showHeaderMenu(BuildContext ctx, ChatTheme theme) {
    final name = widget.otherUser.fullName;
    // Prefer the live Firestore profile for the phone (kept in sync), and
    // fall back to the UserModel passed into this screen while it loads.
    final otherPhone = () {
      final liveUser = widget.otherUser.id.isNotEmpty
          ? ref.read(userByIdProvider(widget.otherUser.id)).valueOrNull
          : null;
      return liveUser?.phone ?? widget.otherUser.phone;
    }();

    showGeneralDialog(
      context: context, // use widget's own stable context, not Builder ctx
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dCtx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(children: [
          Positioned.fill(
              child: GestureDetector(
            onTap: () => Navigator.pop(dCtx),
            child: Container(color: Colors.transparent),
          )),
          Positioned(
            top: 72,
            right: 16,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.5, -0.3), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                opacity: anim,
                child: _ChatMenuPanel(
                  name: name,
                  theme: theme,
                  otherPhone: otherPhone,
                  // Read fresh blocked state each time panel renders (Firestore-backed, Phase 6C)
                  isBlocked: () {
                    final currentUser = ref.read(authProvider);
                    if (currentUser == null) return false;
                    final conversationId =
                        getConversationId(currentUser.id, widget.otherUser.id);
                    return ref
                            .read(conversationByIdProvider(conversationId))
                            .valueOrNull
                            ?.isBlocked ??
                        false;
                  }(),
                  blockedByMe: () {
                    final currentUser = ref.read(authProvider);
                    if (currentUser == null) return false;
                    final conversationId =
                        getConversationId(currentUser.id, widget.otherUser.id);
                    final conv = ref
                        .read(conversationByIdProvider(conversationId))
                        .valueOrNull;
                    return conv?.blockedBy == currentUser.id;
                  }(),
                  onBlock: () {
                    Navigator.pop(dCtx);
                    final currentUser = ref.read(authProvider);
                    if (currentUser == null) return;
                    final conversationId =
                        getConversationId(currentUser.id, widget.otherUser.id);
                    // Use postFrameCallback to ensure overlay is fully dismissed before showing dialog
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _showBlockConfirmFromChat(context, name, conversationId);
                    });
                  },
                  onUnblock: () {
                    Navigator.pop(dCtx);
                    final currentUser = ref.read(authProvider);
                    if (currentUser == null) return;
                    final conversationId =
                        getConversationId(currentUser.id, widget.otherUser.id);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _handleUnblock(conversationId);
                    });
                  },
                  onCall: () {
                    Navigator.pop(dCtx);
                    // Use the parent chat screen's own stable context (not
                    // the popup's), and wait for it to fully dismiss first.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      launchPhoneCall(context, otherPhone);
                    });
                  },
                  onAdminChat: () {
                    Navigator.pop(dCtx);
                    final c = ref
                        .read(conversationsProvider)
                        .firstWhere((c) => c.otherUserId == widget.otherUser.id,
                            orElse: () => ConversationModel(
                                  otherUserId: widget.otherUser.id,
                                  otherUserName: widget.otherUser.fullName,
                                  lastMessage: '',
                                  lastMessageTime: DateTime.now(),
                                  unreadCount: 0,
                                  isOnline: false,
                                ));
                    showAdminChatRequestSheet(context, c, ref,
                        reportedUserRole: widget.otherUser.role.name);
                  },
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider);
    final theme = contractorChatTheme;
    final convs = ref.watch(conversationsProvider);
    final conv =
        convs.firstWhereOrNull((c) => c.otherUserId == widget.otherUser.id);
    // widget.otherUser is frequently a throwaway UserModel built inline from
    // just an id/name at the call site (never carries a real avatar) — its id
    // is always correct, so re-resolve the live profile by id to get the
    // real photo without touching every call site.
    final liveOtherUser = widget.otherUser.id.isNotEmpty
        ? ref.watch(userByIdProvider(widget.otherUser.id)).valueOrNull
        : null;
    final otherAvatarUrl = liveOtherUser?.avatar ?? widget.otherUser.avatar;

    final conversationId = currentUser == null
        ? ''
        : getConversationId(currentUser.id, widget.otherUser.id);
    // Block state (Phase 6C) comes from Firestore, not the legacy local provider.
    final firestoreConv =
        ref.watch(conversationByIdProvider(conversationId)).valueOrNull;
    final isBlocked = firestoreConv?.isBlocked ?? false;
    final blockedByMe =
        currentUser != null && firestoreConv?.blockedBy == currentUser.id;
    // Hotfix (chat-production-before): only start the messages/adminWarnings
    // listeners (via chatTimelineForConversationProvider) once the parent
    // conversation document is known to exist. Both are subcollection
    // queries under conversations/{conversationId}; firestore.rules denies
    // them outright for a conversation that doesn't exist yet (the same
    // isParticipant()-on-a-null-resource issue as a direct conversation
    // read), so opening a brand-new chat used to fail with permission-denied
    // before the very first message was ever sent. conversationByIdProvider
    // (above) is itself now safe for a nonexistent conversation and doubles
    // as the "does it exist yet" signal: once the first message creates the
    // conversation, that provider's own listener picks it up and
    // firestoreConv flips non-null, which naturally starts the real timeline
    // listener below on the next build — no extra plumbing needed.
    final conversationExists = firestoreConv != null;

    // Phase 4D2: combined chronological timeline (normal messages + this
    // user's targeted Admin Warnings), not messagesForConversationProvider
    // directly — see chatTimelineForConversationProvider.
    final messagesAsync = conversationExists
        ? ref.watch(chatTimelineForConversationProvider(conversationId))
        : const AsyncValue<List<MessageModel>>.data(<MessageModel>[]);
    final streamMessages = messagesAsync.valueOrNull ?? const <MessageModel>[];
    // Merge in voice messages this screen just sent so they render right
    // away — dropped automatically once the stream carries the same id.
    final messages = _optimisticMessages.isEmpty
        ? streamMessages
        : (<MessageModel>[
            ...streamMessages,
            ..._optimisticMessages
                .where((om) => !streamMessages.any((sm) => sm.id == om.id)),
          ]..sort((a, b) => a.sentAt.compareTo(b.sentAt)));
    final messagesLoading = messagesAsync.isLoading && messages.isEmpty;
    final messagesError = messagesAsync.hasError && messages.isEmpty;

    // Mark newly-arrived incoming messages as read while this screen stays
    // open. Guarded on the last message being unread-and-mine-to-read so this
    // doesn't fire (or loop) on every emission — once marked, isRead flips to
    // true and the guard stops matching.
    // Gated on conversationExists — see the note above; nothing to
    // reconcile/mark-read/scroll for before the conversation exists, and
    // watching this provider before then is exactly what used to trigger a
    // denied query.
    if (conversationExists) {
      ref.listen<AsyncValue<List<MessageModel>>>(
          chatTimelineForConversationProvider(conversationId), (prev, next) {
        final list = next.valueOrNull;
        if (list != null && _optimisticMessages.isNotEmpty) {
          final ids = list.map((m) => m.id).toSet();
          _optimisticMessages.removeWhere((m) => ids.contains(m.id));
        }
        if (currentUser == null || list == null || list.isEmpty) return;
        final last = list.last;
        if (last.receiverId == currentUser.id && !last.isRead) {
          _markAsRead();
        }
        // Phase 6E: auto-scroll when a new message (e.g. an incoming image)
        // arrives while the screen is already open, so it isn't rendered
        // off-screen below the fold.
        final prevCount = prev?.valueOrNull?.length ?? 0;
        if (list.length > prevCount) {
          _scrollToBottom();
        }
      });
    }

    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showEmoji) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? AppColors.darkBackground : theme.bgPage,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [theme.primaryDark, theme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              boxShadow: [
                BoxShadow(
                    color: theme.primaryDark.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3))
              ],
            ),
            child: SafeArea(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context)),
                _AvatarCircle(
                    name: widget.otherUser.fullName,
                    theme: theme,
                    size: 40,
                    showOnline: conv?.isOnline ?? false,
                    imageUrl: otherAvatarUrl),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(widget.otherUser.fullName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      Row(children: [
                        Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: conv?.isOnline == true
                                    ? const Color(0xFF00D97E)
                                    : Colors.white38,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                            conv?.isOnline == true
                                ? l.get('online_now')
                                : l.get('last_seen'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ]),
                    ])),
                Builder(
                    builder: (ctx) =>
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          // Quick Replies — dark neomorphic square button
                          _ChatSquareBtn(
                            icon: Icons.quickreply_rounded,
                            onPressed: () => _showQuickReplies(ctx, theme),
                          ),
                          const SizedBox(width: 8),
                          // 3 dots menu — exact orders style
                          _ChatThreeDotsBtn(
                            onPressed: () => _showHeaderMenu(ctx, theme),
                          ),
                          const SizedBox(width: 6),
                        ])),
              ]),
            )),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(children: [
            Expanded(
              child: messagesLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messagesError
                      ? Center(
                          child: Text('Could not load messages.',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13)))
                      : messages.isEmpty
                          ? _EmptyChat(theme: theme)
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 12),
                              itemCount:
                                  messages.length + (_showTyping ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                if (_showTyping && i == messages.length) {
                                  return _TypingDots(
                                      theme: theme,
                                      dot1: _dot1,
                                      dot2: _dot2,
                                      dot3: _dot3,
                                      name: widget.otherUser.fullName,
                                      avatarUrl: otherAvatarUrl);
                                }
                                final msg = messages[i];
                                final isMine = currentUser != null &&
                                    msg.senderId == currentUser.id;
                                return _Bubble(
                                  msg: msg,
                                  isMine: isMine,
                                  theme: theme,
                                  isDark: isDark,
                                  conversationId: conversationId,
                                  otherName: widget.otherUser.fullName,
                                  otherAvatarUrl: otherAvatarUrl,
                                  onEdit: isMine &&
                                          !msg.isDeleted &&
                                          msg.type == MessageType.text
                                      ? () {
                                          if (isBlocked) {
                                            _showTopSnack(context,
                                                'This conversation is blocked.',
                                                color: AppColors.error);
                                            return;
                                          }
                                          _startEdit(msg);
                                        }
                                      : null,
                                  onDelete: isMine && !msg.isDeleted
                                      ? () {
                                          if (isBlocked) {
                                            _showTopSnack(context,
                                                'This conversation is blocked.',
                                                color: AppColors.error);
                                            return;
                                          }
                                          _confirmDelete(context, msg);
                                        }
                                      : null,
                                );
                              },
                            ),
            ),

            // Phase 6E: image upload in progress
            if (_uploadingImage)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.primaryLight.withOpacity(0.5),
                child: Row(children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.primary)),
                  const SizedBox(width: 10),
                  Text('Sending image...',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.primary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),

            // Phase 6F: voice upload in progress
            if (_sendingVoice)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.primaryLight.withOpacity(0.5),
                child: Row(children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.primary)),
                  const SizedBox(width: 10),
                  Text('Sending voice message...',
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.primary,
                          fontWeight: FontWeight.w600)),
                ]),
              ),

            // Image preview
            if (_pendingImageBytes != null)
              _ImgPreview(
                  imageBytes: _pendingImageBytes!,
                  theme: theme,
                  onRemove: () => setState(() {
                        _pendingImageBytes = null;
                        _pendingImagePath = null;
                      })),

            if (isBlocked)
              _BlockedBanner(
                name: widget.otherUser.fullName,
                blockedByMe: blockedByMe,
                onUnblock:
                    blockedByMe ? () => _handleUnblock(conversationId) : null,
              )
            else if (_isRecording)
              _RecBar(
                  theme: theme,
                  seconds: _recordSeconds,
                  onCancel: _cancelRec,
                  onSend: _stopAndSend)
            else ...[
              if (_editingMessageId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: theme.primaryLight.withOpacity(0.5),
                      border: Border(
                          top: BorderSide(
                              color: theme.inputBorder.withOpacity(0.3)))),
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 16, color: theme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Editing message',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.primary,
                                fontWeight: FontWeight.w600))),
                    GestureDetector(
                        onTap: _cancelEdit,
                        child: Icon(Icons.close_rounded,
                            size: 18, color: theme.primary)),
                  ]),
                ),
              Builder(
                  builder: (ctx) => _Input(
                        ctrl: _msgCtrl,
                        focusNode: _focusNode,
                        theme: theme,
                        isDark: isDark,
                        isEditing: _editingMessageId != null,
                        showEmoji: _showEmoji,
                        hasPendingImage: _pendingImageBytes != null,
                        onSend: _send,
                        onToggleEmoji: _toggleEmoji,
                        onAttach: () => _showAttachSheet(ctx, theme),
                        hint: _editingMessageId != null
                            ? l.get('edit_message_hint')
                            : l.get('type_message'),
                      )),
            ],

            if (_showEmoji)
              SizedBox(
                  height: 280,
                  child: EmojiPicker(
                    onEmojiSelected: _onEmojiSelected,
                    onBackspacePressed: () {
                      final t = _msgCtrl.text;
                      if (t.isNotEmpty) {
                        _msgCtrl.text = t.characters.skipLast(1).toString();
                        _msgCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: _msgCtrl.text.length));
                      }
                    },
                    config: Config(
                      height: 280,
                      emojiViewConfig: EmojiViewConfig(
                        emojiSizeMax: 28,
                        backgroundColor: Colors.white,
                        buttonMode: ButtonMode.MATERIAL,
                        noRecents: Text('No recents',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ),
                      skinToneConfig: const SkinToneConfig(enabled: true),
                      categoryViewConfig: CategoryViewConfig(
                        initCategory: Category.RECENT,
                        backgroundColor: Colors.white,
                        indicatorColor: theme.primary,
                        iconColor: Colors.grey,
                        iconColorSelected: theme.primary,
                        backspaceColor: theme.primary,
                        tabIndicatorAnimDuration: kTabScrollDuration,
                        categoryIcons: const CategoryIcons(),
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                          backgroundColor: Colors.white,
                          buttonColor: theme.primary),
                      searchViewConfig: SearchViewConfig(
                          backgroundColor: Colors.white,
                          buttonIconColor: theme.primary),
                    ),
                  )),
          ]),
        ),
      ),
    );
  }
}

// ─── Chat Three Dots Button (Orders-style dark neomorphic) ────────────────────
class _ChatThreeDotsBtn extends StatefulWidget {
  final VoidCallback onPressed;
  const _ChatThreeDotsBtn({required this.onPressed});
  @override
  State<_ChatThreeDotsBtn> createState() => _ChatThreeDotsBtnState();
}

class _ChatThreeDotsBtnState extends State<_ChatThreeDotsBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF8F4620),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(3, 3)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(-2, -2)),
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      )),
            ),
          ),
        ),
      );
}

// ─── Chat Square App Bar Button (Orders-style for quickreply) ─────────────────
class _ChatSquareBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ChatSquareBtn({required this.icon, required this.onPressed});
  @override
  State<_ChatSquareBtn> createState() => _ChatSquareBtnState();
}

class _ChatSquareBtnState extends State<_ChatSquareBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _ctrl.forward();
        },
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _ctrl.value, child: child),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF8F4620),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(3, 3)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(-2, -2)),
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: Icon(widget.icon, color: Colors.white, size: 18),
          ),
        ),
      );
}

// ─── Chat Menu Panel (overlay like _NeoOrderMenuPanel) ────────────────────────
class _ChatMenuPanel extends StatefulWidget {
  final String name;
  final ChatTheme theme;
  final bool isBlocked;
  final bool blockedByMe;
  final String? otherPhone;
  final VoidCallback onBlock;
  final VoidCallback onUnblock;
  final VoidCallback onCall;
  final VoidCallback onAdminChat;
  const _ChatMenuPanel({
    required this.name,
    required this.theme,
    required this.isBlocked,
    required this.blockedByMe,
    required this.otherPhone,
    required this.onBlock,
    required this.onUnblock,
    required this.onCall,
    required this.onAdminChat,
  });
  @override
  State<_ChatMenuPanel> createState() => _ChatMenuPanelState();
}

class _ChatMenuPanelState extends State<_ChatMenuPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 360))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      // Not blocked → offer Block. Blocked by me → offer Unblock. Blocked by
      // the other user → omit this item entirely (nothing to do here).
      if (!widget.isBlocked)
        _ChatMenuItem(
          icon: Icons.block_rounded,
          label: 'Block',
          color: const Color(0xFFF59E0B),
          onTap: widget.onBlock,
        )
      else if (widget.blockedByMe)
        _ChatMenuItem(
          icon: Icons.lock_open_rounded,
          label: 'Unblock',
          color: const Color(0xFF10B981),
          onTap: widget.onUnblock,
        ),
      // Only offered on a normal (unblocked) conversation with a real,
      // dialable phone number for the other participant.
      if (!widget.isBlocked && normalizedTelNumber(widget.otherPhone) != null)
        _ChatMenuItem(
          icon: Icons.call_rounded,
          label: 'Call',
          color: widget.theme.primary,
          onTap: widget.onCall,
        ),
      _ChatMenuItem(
        icon: Icons.support_agent_rounded,
        label: 'Admin',
        color: const Color(0xFF7B2FBE),
        onTap: widget.onAdminChat,
      ),
    ];

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: const Color(0xFFF6EFE6),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFFD9C6B2), blurRadius: 16, offset: Offset(6, 6)),
          BoxShadow(
              color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final n = items.length;
          final anim = CurvedAnimation(
            parent: _ctrl,
            curve: Interval(
                (i / n).clamp(0.0, 1.0), ((i + 1) / n).clamp(0.0, 1.0),
                curve: Curves.easeOutBack),
          );
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) => Opacity(
              opacity: anim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                  scale: 0.6 + 0.4 * anim.value.clamp(0.0, 1.0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: item.onTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF6EFE6),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 6,
                          offset: Offset(3, 3)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-3, -3)),
                    ],
                  ),
                  child: Icon(item.icon, color: item.color, size: 22),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChatMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ChatMenuItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}

// ─── Quick Reply Tile (styled like category form field) ───────────────────────
class _QRTile extends StatefulWidget {
  final String text;
  final ChatTheme theme;
  final VoidCallback onTap;
  const _QRTile({required this.text, required this.theme, required this.onTap});
  @override
  State<_QRTile> createState() => _QRTileState();
}

class _QRTileState extends State<_QRTile> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.02 * _c.value, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: widget.theme.primaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: widget.theme.primary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.text,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B1B12)))),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.theme.primary.withOpacity(0.5), size: 13),
            ]),
          ),
        ),
      );
}

// ─── Input Bar ────────────────────────────────────────────────────────────────
class _Input extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final ChatTheme theme;
  final bool isDark, isEditing, showEmoji, hasPendingImage;
  final VoidCallback onSend, onToggleEmoji, onAttach;
  final String hint;

  const _Input(
      {required this.ctrl,
      required this.focusNode,
      required this.theme,
      required this.isDark,
      required this.isEditing,
      required this.showEmoji,
      required this.hasPendingImage,
      required this.onSend,
      required this.onToggleEmoji,
      required this.onAttach,
      required this.hint});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
              top: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : theme.inputBorder.withOpacity(0.2))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
            top: false,
            child: Row(children: [
              GestureDetector(
                  onTap: onToggleEmoji,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6EFE6),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: showEmoji
                            ? [
                                BoxShadow(
                                    color: theme.primary.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2)),
                                const BoxShadow(
                                    color: Color(0xFFD9C6B2),
                                    blurRadius: 4,
                                    offset: Offset(2, 2)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
                                    offset: Offset(-2, -2)),
                              ]
                            : [
                                const BoxShadow(
                                    color: Color(0xFFD9C6B2),
                                    blurRadius: 6,
                                    offset: Offset(3, 3)),
                                const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 6,
                                    offset: Offset(-3, -3)),
                                BoxShadow(
                                    color: const Color(0xFFD9C6B2),
                                    blurRadius: 0,
                                    offset: const Offset(0, 3)),
                              ],
                        border: Border.all(
                            color: showEmoji
                                ? theme.primary.withOpacity(0.4)
                                : Colors.transparent,
                            width: 1.2),
                      ),
                      child: Icon(
                          showEmoji
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: showEmoji
                              ? theme.primary
                              : const Color(0xFF6B7280),
                          size: 20))),
              const SizedBox(width: 8),
              Expanded(
                  child: Container(
                constraints:
                    const BoxConstraints(minHeight: 44, maxHeight: 120),
                decoration: BoxDecoration(
                    color: const Color(0xFFF6EFE6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: (isEditing || hasPendingImage)
                            ? theme.primary
                            : Colors.transparent,
                        width: (isEditing || hasPendingImage) ? 2 : 0),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 8,
                          offset: Offset(4, 4)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 8,
                          offset: Offset(-4, -4)),
                    ]),
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: Color(0xFF1A1A1A)),
                    decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(
                            color: Color(0xFFAAAAAA), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                  )),
                  _NeoAttachBtn(onTap: onAttach, theme: theme),
                  const SizedBox(width: 6),
                ]),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: onSend,
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: isEditing
                                  ? [AppColors.accent, AppColors.accentDark]
                                  : [theme.primary, theme.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: theme.primaryDark.withOpacity(0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                            BoxShadow(
                                color: theme.primary.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                            const BoxShadow(
                                color: Colors.white,
                                blurRadius: 4,
                                offset: Offset(-2, -2)),
                          ]),
                      child: Stack(children: [
                        Positioned(
                          top: 4,
                          left: 6,
                          child: Container(
                            width: 22,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Center(
                            child: Icon(
                                isEditing
                                    ? Icons.check_rounded
                                    : Icons.send_rounded,
                                color: Colors.white,
                                size: 20)),
                      ]))),
            ])),
      );
}

// ─── Attachment Sheet (kept for reference, now using dialog) ──────────────────

class _AttOpt extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttOpt(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  State<_AttOpt> createState() => _AttOptState();
}

class _AttOptState extends State<_AttOpt> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expanded(
          child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.05 * _c.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(22),
              border:
                  Border.all(color: widget.color.withOpacity(0.18), width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 0,
                    offset: Offset(0, 4)),
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 8,
                    offset: Offset(4, 4)),
                BoxShadow(
                    color: Colors.white, blurRadius: 8, offset: Offset(-4, -4)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF6EFE6),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFFD9C6B2),
                          blurRadius: 6,
                          offset: Offset(3, 3)),
                      BoxShadow(
                          color: Colors.white,
                          blurRadius: 6,
                          offset: Offset(-3, -3)),
                    ],
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 26)),
              const SizedBox(height: 10),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: widget.color)),
            ]),
          ),
        ),
      ));
}

// ─── Image Preview ────────────────────────────────────────────────────────────
class _ImgPreview extends StatelessWidget {
  final Uint8List imageBytes;
  final ChatTheme theme;
  final VoidCallback onRemove;
  const _ImgPreview(
      {required this.imageBytes, required this.theme, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: theme.primaryLight.withOpacity(0.4),
            border: Border(
                top: BorderSide(color: theme.inputBorder.withOpacity(0.3)))),
        child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(imageBytes,
                  width: 60, height: 60, fit: BoxFit.cover)),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Image ready to send',
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.primary,
                      fontWeight: FontWeight.w600))),
          GestureDetector(
              onTap: onRemove,
              child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.error, size: 16))),
        ]),
      );
}

// ─── Recording Bar ────────────────────────────────────────────────────────────
class _RecBar extends StatelessWidget {
  final ChatTheme theme;
  final int seconds;
  final VoidCallback onCancel, onSend;
  const _RecBar(
      {required this.theme,
      required this.seconds,
      required this.onCancel,
      required this.onSend});

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                top: BorderSide(color: theme.inputBorder.withOpacity(0.2))),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2))
            ]),
        child: SafeArea(
            top: false,
            child: Row(children: [
              GestureDetector(
                  onTap: onCancel,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.shade200)),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFE53935), size: 22))),
              const SizedBox(width: 12),
              Expanded(
                  child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [
                  const SizedBox(width: 14),
                  _PulseRed(),
                  const SizedBox(width: 10),
                  Text('Recording...',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_fmt(seconds),
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 14),
                ]),
              )),
              const SizedBox(width: 12),
              GestureDetector(
                  onTap: onSend,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [theme.primary, theme.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: theme.primaryDark.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20))),
            ])),
      );
}

class _PulseRed extends StatefulWidget {
  @override
  State<_PulseRed> createState() => _PulseRedState();
}

class _PulseRedState extends State<_PulseRed>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.3, end: 1.0).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(_a.value),
              shape: BoxShape.circle)));
}

// ─── Chat Bubble ──────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMine;
  final ChatTheme theme;
  final bool isDark;
  // The real conversation id already owned by the screen (same id used by
  // messagesForConversationProvider / editTextMessageInFirestore /
  // deleteMessageInFirestore) — passed straight through from build(), never
  // recomputed from senderId/receiverId here.
  final String conversationId;
  final String otherName;
  final String? otherAvatarUrl;
  final VoidCallback? onEdit, onDelete;

  const _Bubble(
      {required this.msg,
      required this.isMine,
      required this.theme,
      required this.isDark,
      required this.conversationId,
      required this.otherName,
      this.otherAvatarUrl,
      this.onEdit,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Distinct full-width moderation card — never a normal left/right
    // bubble, never editable/deletable, never treated as image/voice.
    if (msg.type == MessageType.adminWarning) {
      return _AdminWarningCard(msg: msg);
    }
    final del = msg.isDeleted;
    final bg = isMine
        ? (del ? Colors.grey.shade400 : theme.bubbleSent)
        : (isDark ? AppColors.darkSurfaceVariant : theme.bubbleReceived);
    final tc = isMine
        ? (del ? Colors.white60 : Colors.white)
        : (isDark ? AppColors.darkTextPrimary : const Color(0xFF1A1A1A));

    // Phase 6E fix: prefer imageUrl, fall back to mediaUrl — must check
    // isEmpty (not just null) on both sides since `??` alone would keep an
    // empty string instead of falling through to the other field.
    final resolvedImageUrl = (msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
        ? msg.imageUrl!
        : ((msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty)
            ? msg.mediaUrl!
            : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _AvatarCircle(
                name: otherName,
                theme: theme,
                size: 30,
                imageUrl: otherAvatarUrl),
            const SizedBox(width: 6)
          ],
          GestureDetector(
            onLongPress: (onEdit != null || onDelete != null)
                ? () => _menu(context)
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.70),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMine ? 20 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 20)),
                    boxShadow: [
                      BoxShadow(
                          color: (isMine ? theme.primaryDark : Colors.black)
                              .withOpacity(0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                    border: isMine
                        ? null
                        : Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : theme.inputBorder.withOpacity(0.25),
                            width: 1)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!del && msg.type == MessageType.image)
                        _ImgBubble(
                          path: msg.mediaPath ?? '',
                          imageUrl: resolvedImageUrl.isEmpty
                              ? null
                              : resolvedImageUrl,
                          text: (msg.text.isEmpty ||
                                  msg.text == 'Photo' ||
                                  msg.text == '[Image]')
                              ? null
                              : msg.text,
                          tc: tc,
                          mediaBytes: msg.mediaBytes,
                        )
                      else if (!del && msg.type == MessageType.voice)
                        _VoiceBubble(msg: msg, theme: theme, isMine: isMine)
                      else
                        Text(
                            del
                                ? AppLocalizations.of(context)
                                    .get('message_deleted')
                                : msg.text,
                            style: TextStyle(
                                color: tc,
                                fontSize: 14,
                                height: 1.45,
                                fontStyle:
                                    del ? FontStyle.italic : FontStyle.normal)),
                      // Incoming, non-deleted, non-empty text messages only —
                      // never the current user's own bubble, never an
                      // image/voice/adminWarning message (adminWarning
                      // already returned via _AdminWarningCard above). Never
                      // redesigns the bubble: same Column, same spacing
                      // pattern as the "Edited" label below.
                      if (!isMine &&
                          msg.type == MessageType.text &&
                          !del &&
                          msg.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ChatMessageTranslateAction(
                          conversationId: conversationId,
                          messageId: msg.id,
                          sourceText: msg.text,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        if (msg.isEdited &&
                            !del &&
                            msg.type == MessageType.text) ...[
                          Text('Edited',
                              style: TextStyle(
                                  fontSize: 9,
                                  color:
                                      isMine ? Colors.white60 : Colors.grey)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                            '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                fontSize: 10,
                                color: isMine
                                    ? Colors.white60
                                    : Colors.grey.shade500)),
                        if (isMine) ...[
                          const SizedBox(width: 4),
                          Icon(
                              msg.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 12,
                              color: Colors.white60)
                        ],
                      ]),
                    ]),
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 36),
        ],
      ),
    );
  }

  void _menu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (dCtx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                offset: const Offset(0, -8))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 18),
              // Header
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: theme.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      color: theme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Message Options',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.primary)),
                      const SizedBox(height: 2),
                      Text('Choose an action for this message',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ])),
              ]),
              const SizedBox(height: 20),
              if (onEdit != null) ...[
                _MsgOptionTile(
                  icon: Icons.edit_rounded,
                  label: AppLocalizations.of(ctx).get('edit_message'),
                  color: theme.primary,
                  bgColor: theme.primaryLight,
                  onTap: () {
                    Navigator.pop(dCtx);
                    onEdit?.call();
                  },
                ),
                const SizedBox(height: 10),
              ],
              if (onDelete != null) ...[
                _MsgOptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: AppLocalizations.of(ctx).get('delete_message'),
                  color: AppColors.error,
                  bgColor: Colors.red.shade50,
                  onTap: () {
                    Navigator.pop(dCtx);
                    onDelete?.call();
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Close button — styled like "Submit Request"
              GestureDetector(
                onTap: () => Navigator.pop(dCtx),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.primaryDark, theme.primary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: theme.primaryDark.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Center(
                      child: Text('Close',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3))),
                ),
              ),
            ]),
      ),
    );
  }
}

// ─── Admin Warning Card ─────────────────────────────────────────────────────
// Distinct moderation card for MessageType.adminWarning — full-width, amber-
// tinted, no avatar, no read checkmarks, no long-press edit/delete menu.
// Phase 4D2: Firestore Rules themselves now guarantee this user is an
// authorized recipient — adminWarningsForConversationProvider's
// where('targetUserIds', arrayContains: uid) query can only ever return
// warnings targeting this uid (see firestore.rules' adminWarnings match
// block) — so no client-side filter is needed to decide whether to render
// this card; never shown as an image/voice bubble.
class _AdminWarningCard extends StatelessWidget {
  final MessageModel msg;
  const _AdminWarningCard({required this.msg});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.18),
                    shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 15, color: Color(0xFFB45309)),
              ),
              const SizedBox(width: 8),
              const Text('Admin Warning',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309))),
            ]),
            const SizedBox(height: 8),
            Text(msg.text,
                style: const TextStyle(
                    fontSize: 14, height: 1.45, color: Color(0xFF7C2D12))),
            const SizedBox(height: 6),
            Text(
                '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB45309))),
          ]),
        ),
      );
}

class _ImgBubble extends StatelessWidget {
  final String path;
  final String? text;
  final Color tc;
  final Uint8List? mediaBytes; // non-null on Web
  final String? imageUrl; // Phase 6E: Firebase Storage download URL
  const _ImgBubble(
      {required this.path,
      this.text,
      required this.tc,
      this.mediaBytes,
      this.imageUrl});
  @override
  Widget build(BuildContext context) {
    Widget imgWidget;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imgWidget = Image.network(imageUrl!,
          width: 200,
          height: 180,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: 200,
                  height: 180,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: tc))),
          errorBuilder: (_, error, __) {
            debugPrint('CHAT_IMAGE_NETWORK_ERROR url=$imageUrl error=$error');
            return _networkErrorImg();
          });
    } else if (mediaBytes != null) {
      imgWidget = Image.memory(mediaBytes!,
          width: 200,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _brokenImg());
    } else if (!kIsWeb && path.isNotEmpty) {
      imgWidget = Image.file(File(path),
          width: 200,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _brokenImg());
    } else {
      imgWidget = _brokenImg();
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: imgWidget),
          if (text != null) ...[
            const SizedBox(height: 6),
            Text(text!, style: TextStyle(color: tc, fontSize: 14, height: 1.45))
          ],
        ]);
  }

  // No imageUrl/mediaBytes/mediaPath at all — nothing to attempt loading.
  Widget _brokenImg() => Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
          color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 30),
        const SizedBox(height: 4),
        Text('Image unavailable',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ]));

  // A URL was present but Image.network's errorBuilder fired — distinct
  // message from _brokenImg so logs/UI make clear this is a load failure,
  // not a missing-URL case.
  Widget _networkErrorImg() => Container(
      width: 200,
      height: 100,
      decoration: BoxDecoration(
          color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, color: Colors.grey, size: 30),
        const SizedBox(height: 4),
        Text('Failed to load image',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ]));
}

class _VoiceBubble extends StatefulWidget {
  final MessageModel msg;
  final ChatTheme theme;
  final bool isMine;
  const _VoiceBubble(
      {required this.msg, required this.theme, required this.isMine});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  double _progress = 0.0;
  bool _failed = false;
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(int? s) {
    if (s == null) return '0:00';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // Phase 6F: prefer the Storage download URL (voiceUrl, then audioUrl/
  // mediaUrl aliases); falls back to a local mediaPath for any legacy
  // locally-recorded message that never got uploaded.
  String? get _resolvedUrl {
    final m = widget.msg;
    if (m.voiceUrl != null && m.voiceUrl!.isNotEmpty) return m.voiceUrl;
    if (m.audioUrl != null && m.audioUrl!.isNotEmpty) return m.audioUrl;
    if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) return m.mediaUrl;
    return null;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    final url = _resolvedUrl;
    final p = widget.msg.mediaPath;
    if (url == null && (p == null || p.isEmpty)) return;
    setState(() => _failed = false);
    try {
      if (url != null) {
        await _player.setUrl(url);
      } else {
        await _player.setFilePath(p!);
      }
      _player.play();
      setState(() => _playing = true);
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted)
          setState(() {
            _playing = false;
            _progress = 0;
          });
      });
      _player.positionStream.listen((pos) {
        final dur = _player.duration;
        if (dur != null && dur.inMilliseconds > 0 && mounted)
          setState(() => _progress = pos.inMilliseconds / dur.inMilliseconds);
      });
    } catch (e) {
      debugPrint('CHAT_VOICE_PLAY_ERROR: $e');
      if (mounted)
        setState(() {
          _playing = false;
          _failed = true;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ic = widget.isMine ? Colors.white : widget.theme.primary;
    final fc =
        widget.isMine ? Colors.white.withOpacity(0.8) : widget.theme.primary;
    final tk = widget.isMine
        ? Colors.white.withOpacity(0.3)
        : widget.theme.inputBorder.withOpacity(0.4);
    final hasSource = _resolvedUrl != null ||
        (widget.msg.mediaPath != null && widget.msg.mediaPath!.isNotEmpty);

    if (!hasSource) {
      return SizedBox(
          width: 200,
          child: Row(children: [
            Icon(Icons.mic_off_rounded, color: ic.withOpacity(0.7), size: 20),
            const SizedBox(width: 8),
            Text('Voice unavailable',
                style: TextStyle(fontSize: 12, color: ic.withOpacity(0.8))),
          ]));
    }

    return SizedBox(
        width: 200,
        child: Row(children: [
          GestureDetector(
              onTap: _toggle,
              child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: widget.isMine
                          ? Colors.white.withOpacity(0.2)
                          : widget.theme.primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: ic,
                      size: 22))),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (_failed)
                  Text('Failed to play voice message',
                      style: TextStyle(
                          fontSize: 11,
                          color: ic.withOpacity(0.9),
                          fontWeight: FontWeight.w600))
                else ...[
                  ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: tk,
                          valueColor: AlwaysStoppedAnimation(fc),
                          minHeight: 4)),
                  const SizedBox(height: 4),
                  Text(_fmt(widget.msg.voiceDurationSec),
                      style: TextStyle(
                          fontSize: 11,
                          color: ic.withOpacity(0.8),
                          fontWeight: FontWeight.w600)),
                ],
              ])),
        ]));
  }
}

// ─── Typing Dots ──────────────────────────────────────────────────────────────
class _TypingDots extends StatelessWidget {
  final ChatTheme theme;
  final Animation<double> dot1, dot2, dot3;
  final String name;
  final String? avatarUrl;
  const _TypingDots(
      {required this.theme,
      required this.dot1,
      required this.dot2,
      required this.dot3,
      required this.name,
      this.avatarUrl});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _AvatarCircle(name: name, theme: theme, size: 30, imageUrl: avatarUrl),
        const SizedBox(width: 6),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: theme.bubbleReceived,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _TDot(a: dot1, c: theme.primary),
              const SizedBox(width: 4),
              _TDot(a: dot2, c: theme.primary),
              const SizedBox(width: 4),
              _TDot(a: dot3, c: theme.primary),
            ])),
      ]));
}

class _TDot extends StatelessWidget {
  final Animation<double> a;
  final Color c;
  const _TDot({required this.a, required this.c});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: a,
      builder: (_, __) => Transform.translate(
          offset: Offset(0, -4 * a.value),
          child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                  color: c.withOpacity(0.7 + 0.3 * a.value),
                  shape: BoxShape.circle))));
}

// ─── Neomorphic Menu Tile ─────────────────────────────────────────────────────
class _NeoMenuTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NeoMenuTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  State<_NeoMenuTile> createState() => _NeoMenuTileState();
}

class _NeoMenuTileState extends State<_NeoMenuTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.03 * _c.value, child: child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(18),
              border:
                  Border.all(color: widget.color.withOpacity(0.20), width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF6EFE6),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFFD9C6B2),
                        blurRadius: 5,
                        offset: Offset(2, 2)),
                    BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-2, -2)),
                  ],
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(widget.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.color))),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.color.withOpacity(0.5), size: 14),
            ]),
          ),
        ),
      );
}

// ─── Neomorphic Cancel Button ─────────────────────────────────────────────────
class _NeoCancelBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NeoCancelBtn({required this.label, required this.onTap});
  @override
  State<_NeoCancelBtn> createState() => _NeoCancelBtnState();
}

class _NeoCancelBtnState extends State<_NeoCancelBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.04 * _c.value, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6EFE6),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 0,
                    offset: Offset(0, 3)),
                BoxShadow(
                    color: Color(0xFFD9C6B2),
                    blurRadius: 6,
                    offset: Offset(3, 3)),
                BoxShadow(
                    color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
              ],
            ),
            child: Center(
                child: Text(widget.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A4335)))),
          ),
        ),
      );
}

// ─── Neomorphic App Bar Button ────────────────────────────────────────────────
class _NeoAppBarBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _NeoAppBarBtn({required this.icon, required this.onPressed});
  @override
  State<_NeoAppBarBtn> createState() => _NeoAppBarBtnState();
}

class _NeoAppBarBtnState extends State<_NeoAppBarBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.08 * _c.value, child: child),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(2, 3)),
                BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(-2, -2)),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 19),
          ),
        ),
      );
}

// ─── Neomorphic Attach Button (inline in input bar) ───────────────────────────
class _NeoAttachBtn extends StatefulWidget {
  final VoidCallback onTap;
  final ChatTheme theme;
  const _NeoAttachBtn({required this.onTap, required this.theme});
  @override
  State<_NeoAttachBtn> createState() => _NeoAttachBtnState();
}

class _NeoAttachBtnState extends State<_NeoAttachBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5, right: 5),
        child: GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            _c.forward();
          },
          onTapUp: (_) {
            _c.reverse();
            widget.onTap();
          },
          onTapCancel: () => _c.reverse(),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - 0.1 * _c.value, child: child),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF6EFE6),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFFD9C6B2),
                      blurRadius: 0,
                      offset: Offset(0, 2)),
                  BoxShadow(
                      color: Color(0xFFD9C6B2),
                      blurRadius: 5,
                      offset: Offset(2, 2)),
                  BoxShadow(
                      color: Colors.white,
                      blurRadius: 5,
                      offset: Offset(-2, -2)),
                ],
                border: Border.all(
                    color: widget.theme.primary.withOpacity(0.2), width: 1),
              ),
              child: Icon(Icons.attach_file_rounded,
                  size: 18, color: widget.theme.primary),
            ),
          ),
        ),
      );
}

// ─── Avatar Circle (3D Professional) ──────────────────────────────────────────
class _AvatarCircle extends StatelessWidget {
  final String name;
  final ChatTheme theme;
  final double size;
  final bool showOnline;
  final String? imageUrl;
  const _AvatarCircle(
      {required this.name,
      required this.theme,
      required this.size,
      this.showOnline = false,
      this.imageUrl});

  Widget _initials() => Stack(children: [
        Positioned(
          top: size * 0.08,
          left: size * 0.18,
          child: Container(
            width: size * 0.38,
            height: size * 0.22,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(size),
            ),
          ),
        ),
        Center(
            child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.38,
            shadows: [
              Shadow(
                  color: Colors.black.withOpacity(0.25),
                  offset: const Offset(0, 1.5),
                  blurRadius: 3)
            ],
          ),
        )),
      ]);

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.avatarGradientStart.withOpacity(0.6),
              theme.avatarGradientEnd.withOpacity(0.2)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: theme.primaryDark.withOpacity(0.35),
                blurRadius: size * 0.35,
                offset: Offset(0, size * 0.1)),
            BoxShadow(
                color: theme.primary.withOpacity(0.2),
                blurRadius: size * 0.2,
                spreadRadius: 1),
          ],
        ),
      ),
      Positioned(
        left: 2,
        top: 2,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.avatarGradientStart,
                theme.avatarGradientEnd,
                theme.primaryDark
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.55, 1.0],
            ),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withOpacity(0.45), width: 1.8),
            boxShadow: [
              BoxShadow(
                  color: theme.primaryDark.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(2, 4)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(-2, -2)),
            ],
          ),
          child: hasPhoto
              ? ClipOval(
                  child: Image.network(
                    url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : _initials(),
                    errorBuilder: (context, error, stack) => _initials(),
                  ),
                )
              : _initials(),
        ),
      ),
      if (showOnline)
        Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: const Color(0xFF00D97E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00D97E).withOpacity(0.5),
                      blurRadius: 4)
                ],
              ),
            )),
    ]);
  }
}

// ─── Empty Chat ───────────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  final ChatTheme theme;
  const _EmptyChat({required this.theme});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  theme.avatarGradientStart,
                  theme.avatarGradientEnd
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 32)),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context).get('start_conversation'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(AppLocalizations.of(context).get('send_first_message'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ]));
}

// ─── Message Option Tile (same style as category form tiles) ──────────────────
class _MsgOptionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _MsgOptionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bgColor,
      required this.onTap});
  @override
  State<_MsgOptionTile> createState() => _MsgOptionTileState();
}

class _MsgOptionTileState extends State<_MsgOptionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onTapUp: (_) {
          _c.reverse();
          widget.onTap();
        },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - 0.02 * _c.value, child: child),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.color.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: widget.bgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(widget.label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.color))),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.color.withOpacity(0.5), size: 14),
            ]),
          ),
        ),
      );
}

// ─── Menu Option ──────────────────────────────────────────────────────────────
class _MenuOpt extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuOpt(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
      onTap: onTap,
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
      title: Text(label,
          style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: color.withOpacity(0.4), size: 18));
}

// ─── Popup Action (for centered message menu) ─────────────────────────────────
class _PopupAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _PopupAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bgColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: color.withOpacity(0.4), size: 18),
            ]),
          ),
        ),
      );
}

// ── Blocked Banner ─────────────────────────────────────────────────────────────
class _BlockedBanner extends StatelessWidget {
  final String name;
  final bool blockedByMe;
  final VoidCallback? onUnblock;
  const _BlockedBanner(
      {required this.name, required this.blockedByMe, this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(top: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.block_rounded, color: Colors.orange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              blockedByMe ? 'You blocked $name' : "You can't send messages",
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              blockedByMe
                  ? 'Unblock to send messages.'
                  : 'You can\'t send messages in this conversation.',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ]),
        ),
        if (blockedByMe && onUnblock != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUnblock,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Unblock',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
