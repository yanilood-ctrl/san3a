import 'package:flutter/material.dart';

/// English-only localization. The full AppLocalizations API is preserved
/// so all call sites (l.get(...), translateRegion, translateSpecialty) keep
/// working without any changes.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, String> _en = {
    'app_name': 'San3a',
    'login': 'Login',
    'register': 'Create Account',
    'email': 'Email',
    'password': 'Password',
    'full_name': 'Full Name',
    'phone': 'Phone Number',
    'role': 'Account Type',
    'customer': 'Service Requester',
    'professional': 'Professional',
    'contractor': 'Contractor',
    'no_account': "Don't have an account?",
    'have_account': 'Already have an account?',
    'sign_in': 'Sign In',
    'sign_up': 'Sign Up',
    'language': 'Language',
    'next': 'Next',
    'work_area': 'Work Area',
    'experience_years': 'Years of Experience',
    'specialty': 'Specialty',
    'description': 'Service Description',
    'home': 'Home',
    'messages': 'Messages',
    'orders': 'Orders',
    'profile': 'Profile',
    'search': 'Search for a service or professional...',
    'search_best': 'Find the best professionals near you',
    'categories': 'Categories',
    'more': 'More',
    'recommended': 'Featured Providers',
    'electrician': 'Electrician',
    'carpenter': 'Carpenter',
    'plumber': 'Plumber',
    'painter': 'Painter',
    'mason': 'Mason',
    'gardener': 'Gardener',
    'ac_technician': 'AC Technician',
    'mechanic': 'Mechanic',
    'welder': 'Welder',
    'blacksmith': 'Blacksmith',
    'tailor': 'Tailor',
    'cleaner': 'Cleaner',
    'other_services': 'Other Services',
    'years_exp': 'yrs exp',
    'send_message': 'Send Message',
    'new_order': 'New Order',
    'service_request': 'Service Request',
    'order_title': 'Issue Title',
    'order_desc': 'Issue Description',
    'order_date': 'Service Date',
    'attach_photo': 'Add Photo',
    'send_request': 'Send Request',
    'pending': 'Pending',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'edit_profile': 'Edit Profile',
    'about': 'About App',
    'logout': 'Logout',
    'city': 'City',
    'rating': 'Rating',
    'services': 'Services',
    'team': 'Work Team',
    'hello': 'Hello',
    'required_field': 'This field is required',
    'invalid_email': 'Please enter a valid email (e.g. name@email.com)',
    'password_short': 'Password must be at least 8 characters',
    'password_no_uppercase':
        'Password must contain at least one uppercase letter',
    'password_no_lowercase':
        'Password must contain at least one lowercase letter',
    'password_no_number': 'Password must contain at least one number',
    'password_equals_email': 'Password must not be the same as your email',
    'password_equals_name': 'Password must not be the same as your name',
    'password_equals_phone':
        'Password must not be the same as your phone number',
    'required_name': 'Please enter your full name',
    'required_email': 'Please enter your email address',
    'required_password': 'Please enter your password',
    'required_phone': 'Please enter your phone number',
    'invalid_phone': 'Phone must contain digits only (8–15 digits)',
    'required_work_area': 'Please enter your work area',
    'required_experience': 'Please enter your years of experience',
    'invalid_experience': 'Please enter a valid number for years of experience',
    'required_description': 'Please write a description of your services',
    'required_company': 'Please enter your company name',
    'select_specialty_error_inline':
        'Please select at least one specialty to continue',
    'registration_success': 'Account created successfully! Welcome 🎉',
    'all_categories': 'All Categories',
    'order_sent': 'Request sent successfully',
    'save': 'Save',
    'cancel': 'Cancel',
    'worker_count': 'Workers',
    'no_messages': 'No messages',
    'no_orders': 'No orders',
    'no_orders_section': 'No orders in this section',
    'type_message': 'Type a message...',
    'send': 'Send',
    'create_account_now': 'Create your account now',
    'all': 'All',
    'edit_order': 'Edit Order',
    'photo_optional': 'Photo (Optional)',
    'change_photo': 'Change',
    'add_photo': 'Add Photo',
    'photo': 'Photo',
    'order_photo': 'Order Photo',
    'view_photo': 'View Photo',
    'remove_photo': 'Remove Photo',
    'remove': 'Remove',
    'title': 'Title',
    'cancel_reason': 'Cancellation Reason',
    'enter_cancel_reason': 'Enter cancellation reason',
    'back': 'Back',
    'confirm_cancel': 'Confirm Cancellation',
    'edit': 'Edit',
    'show_more': 'Show More',
    'show_less': 'Show Less',
    'no_results': 'No results found',
    'try_another_search': 'Try a different search term',
    'professional_info': 'Professional Information',
    'company_name': 'Company Name',
    'select_specialty_error': 'Please select at least one specialty',
    'choose_at_least_one': 'Choose at least one specialty',
    'about_provider': 'About Provider',
    'contact_info': 'Contact Information',
    'hint_full_name': 'Full Name',
    'hint_example_years': 'e.g. 5',
    'hint_describe_services': 'Describe your services and experience...',
    'hint_company_name': 'Company Name',
    'choose_region': 'Choose Region',
    'region_north_country': 'North',
    'region_south_country': 'South',
    'region_west_country': 'West',
    'region_east_country': 'East',
    'region_jerusalem': 'Jerusalem',
    'region_haifa': 'Haifa',
    'region_tel_aviv': 'Tel Aviv',
    'region_nazareth': 'Nazareth',
    'region_akka': 'Akka',
    'region_jaffa': 'Jaffa',
    'region_beer_sheva': 'Beer Sheva',
    'region_ramallah': 'Ramallah',
    'region_other': 'Other',
    // Contractor / Professional
    'suppliers': 'Suppliers',
    'workers_suppliers': 'Workers & Suppliers',
    'add': 'Add',
    'add_worker': 'Add Worker',
    'add_first_worker': 'Add First Worker',
    'add_worker_supplier': 'Add Worker / Supplier',
    'edit_data': 'Edit Data',
    'delete': 'Delete',
    'delete_worker': 'Delete Worker',
    'delete_service': 'Delete Service',
    'delete_confirm_worker': 'Remove this worker from the list?',
    'delete_confirm_service': 'Delete this service?',
    'cannot_undo': 'This action cannot be undone.',
    'total': 'Total',
    'available': 'Available',
    'busy': 'Busy',
    'offline': 'Offline',
    'status': 'Status',
    // ── Worker profile fields ────────────────────────────────────────
    'worker_profile': 'Worker Profile',
    'worker_phone': 'Phone',
    'worker_email': 'Email',
    'worker_city': 'City / Work Area',
    'worker_specialty': 'Specialty',
    'worker_completed': 'Completed Jobs',
    'worker_current_jobs': 'Current Jobs',
    'worker_rating': 'Rating',
    'worker_experience': 'Years of Experience',
    'worker_skills': 'Skills',
    'worker_work_hours': 'Work Hours',
    'worker_status': 'Status',
    'worker_available': 'Available',
    'worker_busy': 'Busy',
    'worker_offline': 'Offline',
    'worker_about': 'About',
    'years_short': 'yrs',
    'jobs_short': 'jobs',
    'no_skills_yet': 'No skills added yet',
    'quick_actions': 'Quick Actions',
    'view_full_profile': 'View Full Profile',
    'call_worker': 'Call',
    'message_worker': 'Message',
    'search_name_specialty': 'Search by name, specialty, or phone...',
    'search_customer_service': 'Search by customer name or service...',
    'no_workers_yet': 'No workers yet',
    'add_first_worker_hint': 'Add the first worker to start managing your team',
    'no_results_found': 'No results found',
    'today_schedule': "Today's Schedule",
    'no_tasks_today': 'No tasks today',
    'enjoy_quiet_day': 'Enjoy your quiet day 😊',
    'tasks': 'tasks',
    'upcoming': 'Upcoming',
    'ongoing': 'Ongoing',
    'progress': 'Progress',
    'orders_count': 'Orders',
    'accept': 'Accept',
    'accept_assign': 'Accept & Assign',
    'reject': 'Reject',
    'change': 'Change',
    'view_details': 'View Details',
    'close': 'Close',
    'view': 'View',
    'assign_worker': 'Assign Worker',
    'choose_worker': 'Choose the Right Worker',
    'max_assigned_workers_reached': 'You can assign up to 5 workers per order.',
    'suitable': 'Suitable',
    'notifications': 'Notifications',
    'new_count': 'new',
    'basic_info': 'Basic Information',
    'specialties': 'Specialties',
    'services_prices': 'Services & Prices',
    'additional_info': 'Additional Information',
    'ratings_reviews': 'Ratings & Reviews',
    'no_ratings_yet': 'No ratings yet',
    'ratings_appear_here': 'Customer ratings will appear here',
    'no_services_yet': 'No services added yet',
    'click_to_add': 'Click Add to get started',
    'no_specialties_yet': 'No specialties added yet',
    'service_name': 'Service Name',
    'service_desc': 'Service Description',
    'price_ils': 'Price (₪)',
    'add_service': 'Add Service',
    'add_new_service': 'Add New Service',
    'edit_service': 'Edit Service',
    'edit_specialties': 'Edit Specialties',
    'save_specialties': 'Save Specialties',
    'save_changes': 'Save Changes',
    'edit_profile_title': 'Edit Profile',
    'edit_basic_info': 'Edit Basic Information',
    'edit_additional': 'Edit Additional Info',
    'optional': 'Optional',
    'working_hours': 'Working Hours',
    'response_time': 'Response Time',
    'service_area': 'Service Area',
    'job_type': 'Job Type',
    'individual': 'Individual Professional',
    'company_contractor': 'Company / Contractor',
    'about_me': 'About Me',
    'speed': 'Speed',
    'quality': 'Quality',
    'communication': 'Communication',
    'add_review': 'Add Review',
    'add_review_title': 'Rate Your Experience',
    'your_comment': 'Your Comment',
    'comment_hint': 'Share details of your experience...',
    'send_review': 'Send Review',
    'no_reviews_yet': 'No reviews yet',
    // ── AI Translation (San3a stays English-only; these are the static
    // English UI labels around the optional Translate action itself, never
    // translated content) ──
    'translate': 'Translate',
    'translate_name': 'Translate name',
    'translate_description': 'Translate description',
    // Combined service name+description translation ("Translate service"
    // UX improvement) — old translate_name/translate_description keys above
    // are kept for backward compatibility and may be unused.
    'translate_service': 'Translate service',
    // Review comment translation — reuses the generic arabic_translation /
    // hebrew_translation / hide_translation / retry / already_in_arabic /
    // already_in_hebrew / translation_unavailable / translation_daily_limit
    // keys above; only the entry-button label is review-specific.
    'translate_review': 'Translate review',
    // Chat message translation (translateChatMessage) — reuses the generic
    // arabic_translation / hebrew_translation / english_translation /
    // hide_translation / retry / already_in_arabic / already_in_hebrew /
    // already_in_english / translation_unavailable / translation_daily_limit
    // / translation_text_too_long keys above; only the entry-button label is
    // chat-specific.
    'translate_message': 'Translate message',
    'translate_to': 'Translate to',
    'arabic': 'Arabic',
    'hebrew': 'Hebrew',
    'english': 'English',
    'arabic_translation': 'Arabic translation',
    'hebrew_translation': 'Hebrew translation',
    'english_translation': 'English translation',
    'service_arabic_translation': 'Arabic translation',
    'service_hebrew_translation': 'Hebrew translation',
    'service_english_translation': 'English translation',
    'hide_translation': 'Hide translation',
    'retry': 'Retry',
    'already_in_arabic': 'This content is already in Arabic.',
    'already_in_hebrew': 'This content is already in Hebrew.',
    'already_in_english': 'This content is already in English.',
    'service_already_in_arabic': 'This service is already in Arabic.',
    'service_already_in_hebrew': 'This service is already in Hebrew.',
    'service_already_in_english': 'This service is already in English.',
    'translation_unavailable': 'Translation is unavailable right now.',
    'translation_daily_limit':
        'The translation limit has been reached for now.',
    'translation_text_too_long': 'This text is too long to translate.',
    'review_submitted_successfully': 'Review submitted successfully',
    'review_already_exists':
        'You already reviewed this provider. Your review was updated.',
    'comment_required': 'Please write a comment',
    'already_reviewed': 'You already reviewed this order',
    'ratings': 'Ratings',
    'reviews': 'Reviews',
    'review_management': 'Review Management',
    'review_settings': 'Review Settings',
    'review_criteria': 'Review Criteria',
    'complaint': 'Complaint',
    'name': 'Name',
    'company': 'Company',
    'email_short': 'Email',
    'mobile': 'Phone',
    'city_label': 'City',
    'experience': 'Experience',
    'years': 'yrs',
    'completed_count': 'Completed',
    'all_label': 'All',
    'order_accepted': 'Order accepted',
    'order_completed': 'Order completed!',
    'order_cancelled_msg': 'Order cancelled',
    'worker_assigned': 'Worker assigned and work started',
    'worker_added': 'Worker added successfully',
    'data_updated': 'Data updated',
    'worker_deleted': 'Worker deleted',
    'service_added': 'Service added',
    'service_updated': 'Service updated',
    'service_deleted': 'Service deleted',
    'changes_saved': 'Changes saved',
    'specialties_updated': 'Specialties updated',
    'profile_updated': 'Profile updated',
    'no_workers_add_first': 'No workers — add workers first',
    'search_conversations': 'Search conversations...',
    'urgent': 'Urgent',
    'feature_coming_soon': 'Feature coming soon',
    'favorites': 'Favorites',
    'no_favorites': 'No favorites yet',
    'add_favorites_hint': 'Tap the bookmark icon on a provider to save it here',
    'something_went_wrong': 'Something went wrong. Please try again.',
    'help': 'Help',
    'help_soon': 'Help section coming soon',
    'photo_change_soon': 'Photo change coming soon',
    'app_about_text':
        'San3a connects service seekers with skilled professionals and contractors. Find the right expert for any job, quickly and reliably.',
    // Complaint keys
    'order_complaint': 'Order Complaint',
    'select_order': 'Select Order',
    'complaint_reason': 'Complaint Reason',
    'complaint_details': 'Complaint Details',
    'complaint_hint': 'Describe the issue in detail...',
    'complaint_required': 'Please describe the issue',
    'send_complaint': 'Submit Complaint',
    'complaint_sent': 'Complaint submitted successfully',
    'select_reason_error': 'Please select a reason',
    'select_order_error': 'Please select an order',
    'reason_bad_behavior': 'Unprofessional Behavior',
    'reason_late': 'Late Arrival',
    'reason_bad_quality': 'Poor Quality Work',
    'reason_fraud': 'Fraud or Deception',
    'reason_mismatch': 'Service Mismatch',
    'reason_other': 'Other',
    'my_complaints_title': 'My Complaints',
    'complaint_open': 'Open',
    'complaint_in_review': 'In Review',
    'complaint_resolved': 'Resolved',
    // Complaints Center (Firestore)
    'complaints': 'Complaints',
    'my_complaints': 'My Complaints',
    'submit_complaint': 'Submit Complaint',
    'complaint_title': 'Complaint Title',
    'complaint_description': 'Complaint Description',
    'describe_issue': 'Describe the issue',
    'no_pending_complaints': 'No pending complaints',
    'no_resolved_complaints': 'No resolved complaints',
    'no_complaints_yet': 'No complaints yet',
    'complaint_submitted_successfully': 'Complaint submitted successfully',
    'complaint_updated_successfully': 'Complaint updated successfully',
    'complaint_deleted_successfully': 'Complaint deleted successfully',
    'open': 'Open',
    'in_review': 'In Review',
    'resolved': 'Resolved',
    'rejected': 'Rejected',
    'priority': 'Priority',
    'admin_note': 'Admin Note',
    'open_related_page': 'Open Related Page',
    'no_related_page_available': 'No related page available',
    'provider_report': 'Provider Report',
    'customer_report': 'Customer Report',
    'order_problem': 'Order Problem',
    'service_problem': 'Service Problem',
    'general_complaint': 'General Complaint',
    'review_report': 'Review Report',
    // Edit order dialog
    'order_request_title': 'Issue Title',
    'enter_order_title': 'Enter issue title',
    'order_request_desc': 'Issue Description',
    'enter_order_desc': 'Describe the issue',
    'area_or_city': 'Area / City',
    'enter_area': 'Enter your area',
    'order_service_time': 'Service Time',
    'priority_label': 'Priority',
    'priority_normal': 'Normal',
    'priority_urgent': 'Urgent',
    'selected_service_display': 'Selected Service',
    'order_updated': 'Order updated successfully',
    // Messages options
    'delete_conversation': 'Delete Conversation',
    'block_user': 'Block User',
    'unblock_user': 'Unblock User',
    'report_user': 'Report User',
    'report_sent': 'Report submitted successfully',
    // Location / city edit
    'enter_city': 'City',
    'city_hint': 'e.g. Haifa',
    'city_required': 'Please enter your city',
    'street_number': 'Street Number',
    'street_hint': 'e.g. 12',
    'street_required': 'Please enter your street number',
    'location_saved': 'Location saved',
    'edit_city': 'Edit',
    // All Categories - Request Category
    'request_category_btn':
        "Can\'t find the category you need? Request a new category",
    'request_category_title': 'Request a New Category',
    'category_name_label': 'Category Name',
    'category_name_hint': 'e.g. Interior Design',
    'category_name_required': 'Please enter a category name',
    'category_desc_label': 'Description (Optional)',
    'category_desc_hint': 'Describe what this category covers...',
    'category_request_sent': 'Your request has been submitted. Thank you!',
    'submit_request': 'Submit Request',
    // Chat
    'delete_message': 'Delete Message',
    'edit_message': 'Edit Message',
    'message_deleted': 'This message was deleted',
    'delete_message_confirm': 'Are you sure you want to delete this message?',
    'edit_message_hint': 'Edit your message...',
    'start_conversation': 'Start the conversation',
    'send_first_message': 'Say hello to get started!',
    'online_now': 'Online',
    'last_seen': 'Last seen recently',
    // Admin Notifications
    'no_notifications': 'No notifications yet',
    'mark_as_read': 'Mark as read',
    'notifications_title': 'Notifications',
    'categories_available': '{count} categories available',
    // Notifications (Phase 9A)
    'notification': 'Notification',
    'no_notifications_yet': 'No notifications yet',
    'mark_all_read': 'Mark all read',
    'unread': 'Unread',
    'read': 'Read',
    'general': 'General',
    'broadcast': 'Broadcast',
    'order_update': 'Order Update',
    'review': 'Review',
    'system': 'System',
    'category_request': 'Category Request',
    'broadcast_message': 'Broadcast Message',
    'send_broadcast_message': 'Send Broadcast Message',
    'target_audience': 'Target Audience',
    'all_users': 'All Users',
    'customers_only': 'Customers Only',
    'professionals_only': 'Professionals Only',
    'contractors_only': 'Contractors Only',
    'broadcast_sent_successfully': 'Broadcast sent successfully',
    // AI Service Assistant (Phase 2 — mock-backed callable integration)
    'ai_assistant_home_title': 'Find the Right Provider with AI',
    'ai_assistant_home_subtitle': 'Describe your problem, get instant guidance',
    'ai_assistant_title': 'AI Service Assistant',
    'ai_assistant_intro':
        "Describe your problem in your own words and we'll suggest the right category and provider type for you.",
    'ai_assistant_problem_label': 'Describe your problem',
    'ai_assistant_problem_hint':
        'e.g. My AC makes a strange noise and does not cool well...',
    'ai_assistant_analyze': 'Analyze',
    'ai_assistant_analyzing': 'Analyzing',
    'ai_assistant_retry': 'Retry',
    'ai_assistant_mock_result': 'Mock result',
    'ai_assistant_mock_result_hint':
        'This is test data from a mock backend, not a real AI model yet.',
    'ai_assistant_suggested_category': 'Suggested category',
    'ai_assistant_suggested_provider_type': 'Suggested provider type',
    'ai_assistant_suggested_title': 'Suggested title',
    'ai_assistant_description': 'Organized description',
    'ai_assistant_keywords': 'Keywords',
    'ai_assistant_follow_up_questions': 'Follow-up questions',
    'ai_assistant_error_input_too_short':
        'Please describe your problem in at least 10 characters.',
    'ai_assistant_error_input_too_long':
        'Please shorten your description to 1000 characters or fewer.',
    'ai_assistant_error_unauthenticated':
        'Please sign in to use the AI assistant.',
    'ai_assistant_error_session_mismatch':
        'Your session changed. Please wait or sign in again.',
    'ai_assistant_error_invalid_argument':
        'Please check your description and try again.',
    'ai_assistant_error_unavailable':
        'The assistant service is unavailable right now. Check your local service and try again.',
    'ai_assistant_error_invalid_response':
        'We received an unexpected response. Please try again.',
    'ai_assistant_error_cooldown': 'Please wait a moment before trying again.',
    'ai_assistant_error_user_daily_limit':
        "You have reached today's AI Assistant limit.",
    'ai_assistant_error_global_daily_limit':
        'The AI Assistant has reached its daily service limit. Try again tomorrow.',
    'ai_assistant_error_provider_quota':
        'The AI Assistant has temporarily reached its service capacity. Please try again later.',
    'ai_assistant_suggested_providers': 'Suggested Providers',
    'ai_assistant_suggested_providers_error':
        'Unable to load suggested providers right now.',
    'ai_assistant_suggested_providers_empty':
        'No available providers currently match this suggestion.',
    'ai_assistant_refinement_answer_label': 'Your answer',
    'ai_assistant_refine_analysis': 'Refine Analysis',
    'ai_assistant_refining': 'Refining…',
    'ai_assistant_refinement_error': 'Unable to refine the analysis right now.',
    'ai_assistant_refinement_incomplete':
        'Answer all questions before refining.',
    'ai_assistant_refinement_answer_too_long': 'This answer is too long.',
    // AI Service Assistant — Phase 6B (structured touch-choice follow-ups)
    'ai_assistant_select_an_answer': 'Select an answer',
    // AI Service Assistant — Phase 1 preference form (Redesign)
    'ai_assistant_provider_preference': 'Provider preference',
    'ai_assistant_provider_both': 'Both',
    'ai_assistant_provider_professional': 'Professional',
    'ai_assistant_provider_contractor': 'Contractor',
    'ai_assistant_location_preference': 'Location preference',
    'ai_assistant_location_same_city': 'Same city as me',
    'ai_assistant_location_any': 'Does not matter',
    'ai_assistant_location_city_missing':
        'Add your city in Profile to use this option.',
    'ai_assistant_budget_preference': 'Budget preference',
    'ai_assistant_budget_any': 'Price does not matter',
    'ai_assistant_budget_specific': 'Specific budget',
    'ai_assistant_budget_amount': 'Budget amount',
    'ai_assistant_budget_invalid':
        'Enter a valid budget amount greater than zero.',
    'ai_assistant_additional_notes': 'Additional notes',
    'ai_assistant_additional_notes_hint':
        'Add any optional requirements or details...',
    'ai_assistant_no_providers_matching_preferences':
        'No providers match your selected preference.',
    // AI Service Assistant — Phase 4 (simplified result UI)
    'ai_assistant_why_category': 'Why this Category?',
    'ai_assistant_matching_providers': 'Matching Providers',
    'ai_assistant_more_details': 'More details',
    // AI Service Assistant — Phase 5 (provider selection + Create Service Request)
    'ai_assistant_select_provider': 'Select',
    'ai_assistant_provider_selected': 'Selected',
    'ai_assistant_select_provider_to_continue':
        'Select a provider to continue.',
    'ai_assistant_create_service_request': 'Create Service Request',

    // ─── Professional AI Job Assistant ─────────────────────────────────────
    // English-only, same limitation as the rest of this file (see class doc
    // comment above) — no _ar/_he maps exist yet.
    'professional_ai_assistant_menu_label': 'AI Job Assistant',
    'professional_ai_assistant_title': 'AI Job Assistant',
    'professional_ai_select_order': 'Select an Order',
    'professional_ai_no_eligible_orders':
        'No eligible orders right now. Pending or in-progress orders you own will appear here.',
    'professional_ai_orders_error': 'Unable to load your orders right now.',
    'professional_ai_message_intent': 'Message Intent',
    'professional_ai_intent_confirm_appointment': 'Confirm Appointment',
    'professional_ai_intent_request_more_info': 'Request More Info',
    'professional_ai_intent_request_photos': 'Request Photos',
    // Response Language selector — controls only the language the
    // Professional AI generates its result in (the existing `locale`
    // request field: en/ar/he). These labels stay English because the
    // app currently forces English UI localization; no _ar/_he map is
    // added for them.
    'professional_ai_response_language': 'Response Language',
    'professional_ai_language_english': 'English',
    'professional_ai_language_arabic': 'Arabic',
    'professional_ai_language_hebrew': 'Hebrew',
    'professional_ai_language_request_note':
        'Each analysis uses one AI request.',
    'professional_ai_analyze': 'Analyze',
    'professional_ai_analyzing': 'Analyzing…',
    'professional_ai_summary': 'Summary',
    'professional_ai_questions': 'Questions to Ask',
    'professional_ai_tools_and_materials': 'Tools and Materials',
    'professional_ai_suggested_steps': 'Suggested Steps',
    'professional_ai_safety_warnings': 'Safety Warnings',
    'professional_ai_customer_message': 'Customer Message',
    'professional_ai_copy_message': 'Copy Message',
    'professional_ai_message_copied': 'Message copied to clipboard.',
    'professional_ai_error_professional_only':
        'This feature is available to Professional accounts only.',
    'professional_ai_error_order_not_found':
        'This order could not be found or is not available for this feature.',
    'professional_ai_error_cooldown':
        'Please wait a moment before trying again.',
    'professional_ai_error_user_daily_limit':
        "You have reached today's AI Job Assistant limit.",
    'professional_ai_error_global_daily_limit':
        'The AI Job Assistant has reached its daily service limit. Try again tomorrow.',
    'professional_ai_error_provider_quota':
        'The AI Job Assistant has temporarily reached its service capacity. Please try again later.',
    'professional_ai_error_unavailable':
        'The AI Job Assistant service is unavailable right now. Please try again.',
    'professional_ai_error_unknown': 'Something went wrong. Please try again.',

    // ─── Professional AI Job Assistant — daily order plan ──────────────────
    // English-only, same limitation as the rest of this file — no _ar/_he
    // maps exist yet.
    'professional_ai_today_plan': "Today's Order Plan",
    'professional_ai_other_eligible_orders': 'Other Eligible Orders',
    'professional_ai_no_orders_today': 'No orders scheduled for today.',
    'professional_ai_reason_earliest':
        'Scheduled first because it has the earliest appointment today.',
    'professional_ai_reason_urgent': 'Scheduled at {time} and marked urgent.',
    'professional_ai_reason_in_progress':
        'Already in progress at this appointment time.',
    'professional_ai_reason_after_earlier':
        'Placed after earlier appointments today.',
    'professional_ai_schedule_proximity_warning':
        'This appointment is very close to another order. The available '
            'data is not enough to confirm an actual overlap.',

    // ─── Professional AI Job Assistant — Open Chat draft ────────────────────
    // English-only, same limitation as the rest of this file — no _ar/_he
    // maps exist yet.
    'professional_ai_open_chat': 'Open Chat',
    'professional_ai_opening_chat': 'Opening…',
    'professional_ai_chat_customer_unavailable':
        'This order does not have a valid customer to chat with right now.',
    'professional_ai_chat_order_changed':
        'This order has changed. Please re-select the order and run Analyze '
            'again.',

    // ─── Contractor AI Crew & Order Planner ─────────────────────────────────
    // English-only, same limitation as the rest of this file (see class doc
    // comment above) — no _ar/_he maps exist yet. Wholly independent from
    // the Professional AI Job Assistant keys above — never shared, never
    // modified together.
    'contractor_ai_planner_menu_label': 'AI Crew & Order Planner',
    'contractor_ai_planner_title': 'AI Crew & Order Planner',
    'contractor_ai_select_order': 'Select an Order',
    'contractor_ai_no_eligible_orders':
        'No eligible orders right now. Pending or in-progress orders you '
            'own will appear here.',
    'contractor_ai_orders_error': 'Unable to load your orders right now.',
    'contractor_ai_untitled_order': 'Order',
    'contractor_ai_order_no_longer_available':
        'The previously selected order is no longer available. Please '
            'select another order.',
    'contractor_ai_planning_intent': 'Planning Intent',
    'contractor_ai_intent_prepare_job': 'Prepare Job',
    'contractor_ai_intent_plan_crew': 'Plan Crew',
    'contractor_ai_intent_request_customer_info': 'Request Customer Info',
    // Response Language selector — controls only the language the
    // Contractor AI generates its result in (the existing `locale`
    // request field: en/ar/he). These labels stay English because the
    // app currently forces English UI localization; no _ar/_he map is
    // added for them.
    'contractor_ai_response_language': 'Response Language',
    'contractor_ai_language_english': 'English',
    'contractor_ai_language_arabic': 'Arabic',
    'contractor_ai_language_hebrew': 'Hebrew',
    'contractor_ai_language_request_note': 'Each analysis uses one AI request.',
    'contractor_ai_analyze': 'Analyze',
    'contractor_ai_analyzing': 'Analyzing…',
    'contractor_ai_summary': 'Summary',
    'contractor_ai_recommended_crew_size': 'Recommended Crew Size',
    'contractor_ai_recommended_crew_size_advisory':
        'An advisory estimate only — you decide the final crew.',
    'contractor_ai_crew_guidance': 'Crew Guidance',
    'contractor_ai_questions': 'Questions to Ask',
    'contractor_ai_tools_and_materials': 'Tools and Materials',
    'contractor_ai_suggested_steps': 'Suggested Steps',
    'contractor_ai_coordination_notes': 'Coordination Notes',
    'contractor_ai_safety_warnings': 'Safety Warnings',
    'contractor_ai_customer_message': 'Customer Message',
    'contractor_ai_copy_message': 'Copy Message',
    'contractor_ai_message_copied': 'Message copied to clipboard.',
    'contractor_ai_open_order_assignment': 'Open Order & Assign Workers',
    'contractor_ai_manual_assignment_caption':
        'Worker assignment remains manual in Order Details.',
    'contractor_ai_assignment_data_changed':
        'Worker assignments may have changed. Analyze again for an updated '
            'plan.',
    'contractor_ai_open_chat': 'Open Chat',
    'contractor_ai_chat_order_changed':
        'This order or plan is no longer current. Please select it again.',
    'contractor_ai_chat_customer_unavailable':
        'This order has no customer to message.',
    'contractor_ai_recommended_workers': 'Recommended Workers',
    'contractor_ai_stale_worker_warning':
        'Some recommended workers are no longer available in your worker '
            'list and are not shown.',
    'contractor_ai_worker_unnamed': 'Worker',
    'contractor_ai_worker_status_available': 'Available',
    'contractor_ai_worker_status_busy': 'Busy',
    'contractor_ai_worker_status_offline': 'Offline',
    'contractor_ai_worker_active_workload': '{count} active order(s)',
    'contractor_ai_worker_already_assigned': 'Already assigned',
    'contractor_ai_worker_specialty_match': 'Specialty match',
    'contractor_ai_worker_schedule_proximity_warning':
        'Close to another appointment',
    'contractor_ai_hours_within': 'Within usual hours',
    'contractor_ai_hours_outside': 'Outside usual hours',
    'contractor_ai_hours_unknown': 'Working hours unknown',
    'contractor_ai_reason_already_assigned':
        'Already assigned to this order.',
    'contractor_ai_reason_specialty_match':
        "Specialty matches this order's category.",
    'contractor_ai_reason_busy': 'Currently marked busy.',
    'contractor_ai_reason_offline': 'Currently marked offline.',
    'contractor_ai_reason_active_workload':
        'Currently has {count} other active order(s).',
    'contractor_ai_reason_schedule_proximity':
        'Has another appointment close to this one.',
    'contractor_ai_reason_hours_within': 'Usually works during this time.',
    'contractor_ai_reason_hours_outside':
        'Usually does not work during this time.',
    'contractor_ai_reason_hours_unknown': 'Usual working hours are unknown.',
    'contractor_ai_error_contractor_only':
        'This feature is available to Contractor accounts only.',
    'contractor_ai_error_order_not_found':
        'This order could not be found or is not available for this '
            'feature.',
    'contractor_ai_error_invalid_planning_state':
        'This order is not currently eligible for AI planning.',
    'contractor_ai_error_cooldown':
        'Please wait a moment before trying again.',
    'contractor_ai_error_user_daily_limit':
        "You have reached today's AI Crew & Order Planner limit.",
    'contractor_ai_error_global_daily_limit':
        'The AI Crew & Order Planner has reached its daily service limit. '
            'Try again tomorrow.',
    'contractor_ai_error_provider_quota':
        'The AI Crew & Order Planner has temporarily reached its service '
            'capacity. Please try again later.',
    'contractor_ai_error_unavailable':
        'The AI Crew & Order Planner service is unavailable right now. '
            'Please try again.',
    'contractor_ai_error_invalid_response':
        'The AI Crew & Order Planner returned an unexpected response. '
            'Please try again.',
    'contractor_ai_error_unknown': 'Something went wrong. Please try again.',
  };

  String get(String key) => _en[key] ?? key;

  String translateRegion(String raw) {
    final key = 'region_$raw';
    return _en[key] ?? raw;
  }

  String translateSpecialty(String key) => _en[key] ?? key;
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      true; // accept any locale, always return English

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(const Locale('en'));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
