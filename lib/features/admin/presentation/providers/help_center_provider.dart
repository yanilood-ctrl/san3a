import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/models.dart';

// ─── FAQ Item ─────────────────────────────────────────────────────────────────
// `role == null` means the FAQ is common and shown to every role; otherwise it
// is shown only to the matching role.
class FaqItem {
  final String id;
  String question;
  String answer;
  final UserRole? role;
  FaqItem(
      {required this.id,
      required this.question,
      required this.answer,
      this.role});
  FaqItem copyWith({String? question, String? answer}) => FaqItem(
      id: id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      role: role);
}

// ─── Help Center Content ──────────────────────────────────────────────────────
class HelpCenterContent {
  final String aboutText;
  final String supportHours;
  final String supportEmail;
  final String supportPhone;
  final String customerHelp;
  final String professionalHelp;
  final String contractorHelp;
  final List<FaqItem> faqs;

  const HelpCenterContent({
    required this.aboutText,
    required this.supportHours,
    required this.supportEmail,
    required this.supportPhone,
    required this.customerHelp,
    required this.professionalHelp,
    required this.contractorHelp,
    required this.faqs,
  });

  HelpCenterContent copyWith({
    String? aboutText,
    String? supportHours,
    String? supportEmail,
    String? supportPhone,
    String? customerHelp,
    String? professionalHelp,
    String? contractorHelp,
    List<FaqItem>? faqs,
  }) =>
      HelpCenterContent(
        aboutText: aboutText ?? this.aboutText,
        supportHours: supportHours ?? this.supportHours,
        supportEmail: supportEmail ?? this.supportEmail,
        supportPhone: supportPhone ?? this.supportPhone,
        customerHelp: customerHelp ?? this.customerHelp,
        professionalHelp: professionalHelp ?? this.professionalHelp,
        contractorHelp: contractorHelp ?? this.contractorHelp,
        faqs: faqs ?? this.faqs,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class HelpCenterNotifier extends StateNotifier<HelpCenterContent> {
  HelpCenterNotifier()
      : super(HelpCenterContent(
          aboutText:
              'San3a is a smart platform that connects customers with skilled '
              'professionals and contractors for a wide range of home and '
              'business services.\n\n'
              'Whether you need plumbing, electrical work, carpentry, painting, '
              'or any other service — San3a makes it easy to find trusted '
              'providers, place orders, track progress, and communicate in real time.',
          supportHours: 'Support team is available Sunday–Thursday, 9 AM–6 PM.',
          supportEmail: 'support@san3a.app',
          supportPhone: '+972-XX-XXXXXXX',
          customerHelp: 'As a Customer you can:\n'
              '• Browse service categories and find professionals\n'
              '• Create service requests with details and photos\n'
              '• Track your orders in real time\n'
              '• Chat directly with providers\n'
              '• Add providers to favorites\n'
              '• Submit complaints if needed',
          professionalHelp: 'As a Professional you can:\n'
              '• View and manage incoming service requests\n'
              '• Accept or decline requests\n'
              '• Manage your offered services and pricing\n'
              '• Edit your profile, specialties, and work area\n'
              '• Chat with customers anytime\n'
              '• View your ratings and reviews',
          contractorHelp: 'As a Contractor you can:\n'
              '• Manage and track all service requests\n'
              '• Manage your team of workers\n'
              '• Track schedules and project timelines\n'
              '• Manage the services your company offers\n'
              '• Chat with customers anytime\n'
              '• View your company profile and ratings',
          faqs: [
            // ── Common — shown to every role ──────────────────────────────
            FaqItem(
              id: 'f_common_profile',
              question: 'How do I edit my profile?',
              answer:
                  'Open Profile, choose "Edit Profile", update the available '
                  'information, then save your changes.',
            ),
            FaqItem(
              id: 'f_common_complaint',
              question: 'How do I send a complaint?',
              answer: 'Open "My Complaints", create a new complaint, choose '
                  'the appropriate reason, provide the details, and submit it.',
            ),
            FaqItem(
              id: 'f_common_notifications',
              question: 'How do notifications work?',
              answer: 'The Notifications section shows important updates '
                  'about your orders, complaints, reviews, category requests, '
                  'and other relevant account activity.',
            ),
            FaqItem(
              id: 'f_common_translate',
              question: 'How do I translate supported content?',
              answer: 'The San3a app interface is English-only. Some supported '
                  'content may show a translate action that can display it in '
                  'Arabic or Hebrew — this does not change the app\'s interface language.',
            ),

            // ── Customer-specific ────────────────────────────────────────
            FaqItem(
              id: 'f_customer_request',
              role: UserRole.customer,
              question: 'How do I create a service request?',
              answer:
                  'Browse categories or providers, or use the available request '
                  'flow, then select the services you need, enter the details, '
                  'area, and preferred date, and submit your request.',
            ),
            FaqItem(
              id: 'f_customer_edit_cancel',
              role: UserRole.customer,
              question: 'How do I edit or cancel an order?',
              answer: 'Open the order from your orders list. The actions '
                  'available to edit or cancel it depend on the order\'s '
                  'current status.',
            ),
            FaqItem(
              id: 'f_customer_contact',
              role: UserRole.customer,
              question: 'How do I contact a service provider?',
              answer: 'Open the provider\'s profile, or an active order or '
                  'conversation, and use the available chat or call action.',
            ),
            FaqItem(
              id: 'f_customer_favorites',
              role: UserRole.customer,
              question: 'How do I add a provider to favorites?',
              answer: 'Use the favorite action on a supported provider card '
                  'or profile to add or remove it from your favorites.',
            ),
            FaqItem(
              id: 'f_customer_review',
              role: UserRole.customer,
              question: 'How do I leave a review?',
              answer: 'Reviews are available through the completed-service or '
                  'provider flow, where supported.',
            ),

            // ── Professional-specific ────────────────────────────────────
            FaqItem(
              id: 'f_professional_services',
              role: UserRole.professional,
              question: 'How do I manage my services and prices?',
              answer: 'Open your Profile and use the Services section to add, '
                  'edit, or remove the services you offer and set their prices.',
            ),
            FaqItem(
              id: 'f_professional_specialties',
              role: UserRole.professional,
              question: 'How do I update my specialties and work area?',
              answer: 'Open Profile → Edit Profile to update your specialties '
                  'and work area.',
            ),
            FaqItem(
              id: 'f_professional_availability',
              role: UserRole.professional,
              question: 'How do I set my availability and working hours?',
              answer: 'Open Profile → Edit Profile to set your working days '
                  'and working hours.',
            ),
            FaqItem(
              id: 'f_professional_accept',
              role: UserRole.professional,
              question: 'How do I accept or reject a service request?',
              answer: 'Open the request from your orders list and use the '
                  'Accept or Reject action shown for pending requests.',
            ),
            FaqItem(
              id: 'f_professional_complete',
              role: UserRole.professional,
              question: 'How do I complete an order?',
              answer: 'Open the in-progress order and use the Complete action '
                  'once the work is finished.',
            ),
            FaqItem(
              id: 'f_professional_chat',
              role: UserRole.professional,
              question: 'How do I communicate with a customer?',
              answer: 'Use the Chat action on the order to message the '
                  'customer directly.',
            ),

            // ── Contractor-specific ───────────────────────────────────────
            FaqItem(
              id: 'f_contractor_worker_add',
              role: UserRole.contractor,
              question: 'How do I add or edit a worker?',
              answer: 'Open your Workers section from Profile to add a new '
                  'worker or edit an existing worker\'s details.',
            ),
            FaqItem(
              id: 'f_contractor_worker_assign',
              role: UserRole.contractor,
              question: 'How do I assign workers to an order?',
              answer: 'Open the order details and use the worker assignment '
                  'action to assign one or more workers to it.',
            ),
            FaqItem(
              id: 'f_contractor_worker_missing',
              role: UserRole.contractor,
              question: 'Why does a worker not appear in the assignment list?',
              answer: 'The assignment list is filtered to workers whose '
                  'specialties match the specialties required by the '
                  'selected services on the order.',
            ),
            FaqItem(
              id: 'f_contractor_worker_change',
              role: UserRole.contractor,
              question: 'How do I change workers during an in-progress order?',
              answer: 'Open the order details and update the worker '
                  'assignment to swap or remove workers as needed.',
            ),
            FaqItem(
              id: 'f_contractor_return_pending',
              role: UserRole.contractor,
              question: 'How do I return an order to Pending?',
              answer: 'Open the order details and use "Unassign All & Return '
                  'to Pending" to unassign all workers and move the order '
                  'back to Pending.',
            ),
            FaqItem(
              id: 'f_contractor_services',
              role: UserRole.contractor,
              question: 'How do I manage my company services and specialties?',
              answer: 'Open your Profile to manage the services and '
                  'specialties your company offers.',
            ),
            FaqItem(
              id: 'f_contractor_chat',
              role: UserRole.contractor,
              question: 'How do I communicate with a customer?',
              answer: 'Use the Chat action on the order to message the '
                  'customer directly.',
            ),
          ],
        ));

  void updateAbout(String text) => state = state.copyWith(aboutText: text);

  void updateSupportHours(String text) =>
      state = state.copyWith(supportHours: text);

  void updateSupportEmail(String email) =>
      state = state.copyWith(supportEmail: email);

  void updateSupportPhone(String phone) =>
      state = state.copyWith(supportPhone: phone);

  void updateCustomerHelp(String text) =>
      state = state.copyWith(customerHelp: text);

  void updateProfessionalHelp(String text) =>
      state = state.copyWith(professionalHelp: text);

  void updateContractorHelp(String text) =>
      state = state.copyWith(contractorHelp: text);

  void addFaq(FaqItem faq) =>
      state = state.copyWith(faqs: [...state.faqs, faq]);

  void updateFaq(FaqItem updated) => state = state.copyWith(
      faqs: state.faqs.map((f) => f.id == updated.id ? updated : f).toList());

  void deleteFaq(String id) => state =
      state.copyWith(faqs: state.faqs.where((f) => f.id != id).toList());
}

final helpCenterProvider =
    StateNotifierProvider<HelpCenterNotifier, HelpCenterContent>(
  (ref) => HelpCenterNotifier(),
);
