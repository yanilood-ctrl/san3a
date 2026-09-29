// ─────────────────────────────────────────────────────────────────────────────
// Chat Theme — shared visual theme constants used by all chat screens.
// Behavior (blocking, sending, etc.) lives inside each role's own chat file.
// Editing colors here updates all three chats visually.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../shared/models/models.dart';

class ChatTheme {
  final Color primary, primaryDark, primaryLight, bubbleSent, bubbleReceived;
  final Color headerBg, inputBorder, searchBg, unreadBadge;
  final Color avatarGradientStart, avatarGradientEnd, bgPage;

  const ChatTheme({
    required this.primary, required this.primaryDark, required this.primaryLight,
    required this.bubbleSent, required this.bubbleReceived, required this.headerBg,
    required this.inputBorder, required this.searchBg, required this.unreadBadge,
    required this.avatarGradientStart, required this.avatarGradientEnd, required this.bgPage,
  });

  static const customer = ChatTheme(
    primary: Color(0xFF052659), primaryDark: Color(0xFF021024), primaryLight: Color(0xFFC1E8FF),
    bubbleSent: Color(0xFF052659), bubbleReceived: Color(0xFFF0F6FF),
    headerBg: Color(0xFF021024), inputBorder: Color(0xFF7DA0CA), searchBg: Color(0xFFEEF5FF),
    unreadBadge: Color(0xFF052659), avatarGradientStart: Color(0xFF052659),
    avatarGradientEnd: Color(0xFF5483B3), bgPage: Color(0xFFF0F6FF),
  );
  static const professional = ChatTheme(
    primary: Color(0xFF235347), primaryDark: Color(0xFF051F20), primaryLight: Color(0xFFDAF1DE),
    bubbleSent: Color(0xFF163832), bubbleReceived: Color(0xFFF0FAF2),
    headerBg: Color(0xFF051F20), inputBorder: Color(0xFF8EB69B), searchBg: Color(0xFFEDF7EF),
    unreadBadge: Color(0xFF235347), avatarGradientStart: Color(0xFF051F20),
    avatarGradientEnd: Color(0xFF235347), bgPage: Color(0xFFF2FAF4),
  );
  static const contractor = ChatTheme(
    primary: Color(0xFF8C6E63), primaryDark: Color(0xFF3E2522), primaryLight: Color(0xFFFFF2DF),
    bubbleSent: Color(0xFF3E2522), bubbleReceived: Color(0xFFFFF8F0),
    headerBg: Color(0xFF3E2522), inputBorder: Color(0xFFD3A376), searchBg: Color(0xFFFFF8F0),
    unreadBadge: Color(0xFF8C6E63), avatarGradientStart: Color(0xFF3E2522),
    avatarGradientEnd: Color(0xFF8C6E63), bgPage: Color(0xFFFFF8F0),
  );

  static ChatTheme forRole(UserRole role) {
    switch (role) {
      case UserRole.professional: return professional;
      case UserRole.contractor:   return contractor;
      default:                    return customer;
    }
  }
}