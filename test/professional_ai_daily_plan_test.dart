import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/features/professional_ai_assistant/models/professional_ai_analysis_result.dart';
import 'package:san3a/features/professional_ai_assistant/presentation/providers/professional_ai_assistant_provider.dart';
import 'package:san3a/features/professional_ai_assistant/professional_ai_daily_plan.dart';
import 'package:san3a/shared/models/models.dart';

// Pure unit tests for the deterministic Professional AI daily-plan sorting/
// proximity logic — no Firestore/Riverpod/widget wiring involved, matching
// the existing conversation_pending_gate_test.dart pattern for testing a
// standalone pure function directly.

OrderModel _order({
  required String id,
  required DateTime serviceDate,
  OrderPriority priority = OrderPriority.normal,
  OrderStatus status = OrderStatus.pending,
  DateTime? createdAt,
}) =>
    OrderModel(
      id: id,
      customerId: 'customer-1',
      providerId: 'provider-1',
      providerName: 'Provider',
      title: 'Test order $id',
      description: 'Test description',
      area: 'Test area',
      serviceDate: serviceDate,
      status: status,
      priority: priority,
      createdAt: createdAt ?? DateTime(2024, 1, 1),
    );

void main() {
  group('isProfessionalAiOrderToday', () {
    test('same year/month/day is today regardless of time', () {
      final now = DateTime(2026, 7, 27, 8, 0);
      expect(
        isProfessionalAiOrderToday(DateTime(2026, 7, 27, 23, 59), now),
        isTrue,
      );
    });

    test('a different day is not today', () {
      final now = DateTime(2026, 7, 27, 8, 0);
      expect(
        isProfessionalAiOrderToday(DateTime(2026, 7, 28, 0, 1), now),
        isFalse,
      );
      expect(
        isProfessionalAiOrderToday(DateTime(2026, 7, 26, 23, 59), now),
        isFalse,
      );
    });
  });

  group('buildProfessionalAiDailyPlan sorting', () {
    test('earlier appointment sorts first', () {
      final early = _order(id: 'a', serviceDate: DateTime(2026, 7, 27, 9, 0));
      final late = _order(id: 'b', serviceDate: DateTime(2026, 7, 27, 14, 0));

      final plan = buildProfessionalAiDailyPlan([late, early]);

      expect(plan[0].order.id, 'a');
      expect(plan[0].position, 1);
      expect(plan[1].order.id, 'b');
      expect(plan[1].position, 2);
    });

    test('urgent wins when the appointment minute is equal', () {
      final normalOrder = _order(
        id: 'normal',
        serviceDate: DateTime(2026, 7, 27, 11, 30),
        priority: OrderPriority.normal,
      );
      final urgentOrder = _order(
        id: 'urgent',
        serviceDate: DateTime(2026, 7, 27, 11, 30),
        priority: OrderPriority.urgent,
      );

      final plan = buildProfessionalAiDailyPlan([normalOrder, urgentOrder]);

      expect(plan[0].order.id, 'urgent');
      expect(plan[1].order.id, 'normal');
    });

    test('inProgress wins when time and priority are equal', () {
      final pendingOrder = _order(
        id: 'pending',
        serviceDate: DateTime(2026, 7, 27, 11, 30),
        status: OrderStatus.pending,
      );
      final inProgressOrder = _order(
        id: 'inProgress',
        serviceDate: DateTime(2026, 7, 27, 11, 30),
        status: OrderStatus.inProgress,
      );

      final plan =
          buildProfessionalAiDailyPlan([pendingOrder, inProgressOrder]);

      expect(plan[0].order.id, 'inProgress');
      expect(plan[1].order.id, 'pending');
    });

    test('stable tie-break using createdAt then order id', () {
      final sameTime = DateTime(2026, 7, 27, 11, 30);
      final createdLater = _order(
        id: 'z-created-later',
        serviceDate: sameTime,
        createdAt: DateTime(2026, 1, 2),
      );
      final createdEarlier = _order(
        id: 'a-created-earlier',
        serviceDate: sameTime,
        createdAt: DateTime(2026, 1, 1),
      );
      // Same serviceDate, priority, status, AND createdAt — only the
      // lexicographical id remains to break the tie.
      final sameCreatedAtA = _order(
        id: 'a-id',
        serviceDate: sameTime,
        createdAt: DateTime(2026, 1, 3),
      );
      final sameCreatedAtB = _order(
        id: 'b-id',
        serviceDate: sameTime,
        createdAt: DateTime(2026, 1, 3),
      );

      final byCreatedAt =
          buildProfessionalAiDailyPlan([createdLater, createdEarlier]);
      expect(byCreatedAt[0].order.id, 'a-created-earlier');
      expect(byCreatedAt[1].order.id, 'z-created-later');

      final byId =
          buildProfessionalAiDailyPlan([sameCreatedAtB, sameCreatedAtA]);
      expect(byId[0].order.id, 'a-id');
      expect(byId[1].order.id, 'b-id');
    });
  });

  group('schedule-proximity warning', () {
    test('same-time appointments trigger the warning', () {
      final time = DateTime(2026, 7, 27, 11, 30);
      final a = _order(id: 'a', serviceDate: time);
      final b = _order(id: 'b', serviceDate: time);

      final plan = buildProfessionalAiDailyPlan([a, b]);

      expect(plan[0].hasProximityWarning, isTrue);
      expect(plan[1].hasProximityWarning, isTrue);
    });

    test('exactly thirty minutes apart triggers the warning', () {
      final a = _order(id: 'a', serviceDate: DateTime(2026, 7, 27, 11, 0));
      final b = _order(id: 'b', serviceDate: DateTime(2026, 7, 27, 11, 30));

      final plan = buildProfessionalAiDailyPlan([a, b]);

      expect(plan[0].hasProximityWarning, isTrue);
      expect(plan[1].hasProximityWarning, isTrue);
    });

    test('more than thirty minutes apart does not trigger the warning', () {
      final a = _order(id: 'a', serviceDate: DateTime(2026, 7, 27, 11, 0));
      final b = _order(id: 'b', serviceDate: DateTime(2026, 7, 27, 11, 31));

      final plan = buildProfessionalAiDailyPlan([a, b]);

      expect(plan[0].hasProximityWarning, isFalse);
      expect(plan[1].hasProximityWarning, isFalse);
    });
  });

  group('today filtering stays separate from the eligible-orders set', () {
    test('a non-today order is excluded from the daily plan input', () {
      final now = DateTime(2026, 7, 27, 8, 0);
      final today = _order(id: 'today', serviceDate: DateTime(2026, 7, 27, 9, 0));
      final tomorrow =
          _order(id: 'tomorrow', serviceDate: DateTime(2026, 7, 28, 9, 0));
      final eligible = [today, tomorrow];

      final todayOnly = eligible
          .where((o) => isProfessionalAiOrderToday(o.serviceDate, now))
          .toList();
      final plan = buildProfessionalAiDailyPlan(todayOnly);

      expect(plan.length, 1);
      expect(plan.single.order.id, 'today');
      // The non-today order is still present in the original eligible list
      // (i.e. still selectable elsewhere) — this test only proves it never
      // reaches the daily-plan computation.
      expect(eligible.map((o) => o.id), contains('tomorrow'));
    });
  });

  // ─── Professional AI Response Language ──────────────────────────────────
  // Pure, Firebase-free tests for the explicit response-language selector:
  // the enum's backend-code/RTL mapping, and the isolated
  // ProfessionalAiAssistantState.withResponseLanguageSelected pure
  // state-transition (extracted specifically so this contract is testable
  // without constructing a real ProfessionalAiAssistantRepository/
  // controller, which would require Firebase). Matches the existing
  // pattern in this file and in contractor_ai_planner_test.dart of testing
  // standalone pure functions/state-transitions directly.
  group('ProfessionalAiResponseLanguage', () {
    test('1. default response language is English', () {
      expect(kProfessionalAiDefaultResponseLanguage,
          ProfessionalAiResponseLanguage.english);
      expect(const ProfessionalAiAssistantState().selectedResponseLanguage,
          ProfessionalAiResponseLanguage.english);
    });

    test('2. English maps exactly to "en"', () {
      expect(ProfessionalAiResponseLanguage.english.wireValue, 'en');
    });

    test('3. Arabic maps exactly to "ar"', () {
      expect(ProfessionalAiResponseLanguage.arabic.wireValue, 'ar');
    });

    test('4. Hebrew maps exactly to "he"', () {
      expect(ProfessionalAiResponseLanguage.hebrew.wireValue, 'he');
    });

    test('5. English is LTR', () {
      expect(ProfessionalAiResponseLanguage.english.isRtl, isFalse);
    });

    test('6. Arabic is RTL', () {
      expect(ProfessionalAiResponseLanguage.arabic.isRtl, isTrue);
    });

    test('7. Hebrew is RTL', () {
      expect(ProfessionalAiResponseLanguage.hebrew.isRtl, isTrue);
    });

    test('15. a freshly constructed state (as autoDispose creates on '
        'reopen) defaults to English', () {
      const freshState = ProfessionalAiAssistantState();
      expect(freshState.selectedResponseLanguage,
          ProfessionalAiResponseLanguage.english);
    });
  });

  group('ProfessionalAiAssistantState.withResponseLanguageSelected', () {
    test('8. changing language preserves the selected order', () {
      const state = ProfessionalAiAssistantState(selectedOrderId: 'order-1');
      final next = state
          .withResponseLanguageSelected(ProfessionalAiResponseLanguage.arabic);
      expect(next, isNotNull);
      expect(next!.selectedOrderId, 'order-1');
    });

    test('9. changing language preserves the selected message intent', () {
      const state = ProfessionalAiAssistantState(
        selectedMessageIntent: ProfessionalAiMessageIntent.requestPhotos,
      );
      final next = state
          .withResponseLanguageSelected(ProfessionalAiResponseLanguage.hebrew);
      expect(next, isNotNull);
      expect(next!.selectedMessageIntent,
          ProfessionalAiMessageIntent.requestPhotos);
    });

    test('10. changing language clears the previous result', () {
      const result = ProfessionalAiAnalysisResult(
        schemaVersion: 1,
        orderId: 'order-1',
        summary: 'A short summary.',
        questions: ['Any access restrictions?'],
        toolsAndMaterials: ['Ladder'],
        suggestedSteps: ['Step one', 'Step two'],
        safetyWarnings: ['Wear gloves.'],
        customerMessage: 'We will arrive as scheduled.',
      );
      const state = ProfessionalAiAssistantState(result: result);
      final next = state
          .withResponseLanguageSelected(ProfessionalAiResponseLanguage.arabic);
      expect(next, isNotNull);
      expect(next!.result, isNull);
    });

    test('11. changing language clears the previous error', () {
      const state = ProfessionalAiAssistantState(
        errorCode: 'unknown',
        errorReason: 'professional_ai_cooldown',
      );
      final next = state
          .withResponseLanguageSelected(ProfessionalAiResponseLanguage.hebrew);
      expect(next, isNotNull);
      expect(next!.errorCode, isNull);
      expect(next.errorReason, isNull);
    });

    test('12. selecting the already-selected language is a no-op', () {
      const state = ProfessionalAiAssistantState(); // defaults to English
      final next = state.withResponseLanguageSelected(
          ProfessionalAiResponseLanguage.english);
      expect(next, isNull);
    });

    test('13. language cannot change while a request is loading', () {
      const state = ProfessionalAiAssistantState(isLoading: true);
      final next = state
          .withResponseLanguageSelected(ProfessionalAiResponseLanguage.arabic);
      expect(next, isNull);
    });
  });

  group('ProfessionalAiRequestGenerationGuard', () {
    test(
        '14. a stale request generation cannot overwrite state after a '
        'change invalidates it', () {
      final guard = ProfessionalAiRequestGenerationGuard();
      final inFlightGeneration = guard.start();
      expect(guard.isCurrent(inFlightGeneration), isTrue);

      // Simulates the invalidation selectResponseLanguage performs on any
      // in-flight generation before applying the new language.
      guard.invalidate();

      expect(guard.isCurrent(inFlightGeneration), isFalse);
    });
  });

  // ─── Professional AI Result-Section Titles ──────────────────────────────
  // Pure, Firebase/widget-free tests for the deterministic, local
  // section-title mapping keyed only by ProfessionalAiResponseLanguage —
  // never derived from the generated text, never an AI/translation call,
  // never automatic language detection.
  group('ProfessionalAiResultSectionTitle', () {
    test('1. English Summary title is "Summary"', () {
      expect(
        ProfessionalAiResultSection.summary
            .titleFor(ProfessionalAiResponseLanguage.english),
        'Summary',
      );
    });

    test('2. Arabic Summary title is "الملخص"', () {
      expect(
        ProfessionalAiResultSection.summary
            .titleFor(ProfessionalAiResponseLanguage.arabic),
        'الملخص',
      );
    });

    test('3. Hebrew Summary title is "סיכום"', () {
      expect(
        ProfessionalAiResultSection.summary
            .titleFor(ProfessionalAiResponseLanguage.hebrew),
        'סיכום',
      );
    });

    test('4. English Questions title is "Questions to Ask"', () {
      expect(
        ProfessionalAiResultSection.questions
            .titleFor(ProfessionalAiResponseLanguage.english),
        'Questions to Ask',
      );
    });

    test('5. Arabic Questions title is "أسئلة للعميل"', () {
      expect(
        ProfessionalAiResultSection.questions
            .titleFor(ProfessionalAiResponseLanguage.arabic),
        'أسئلة للعميل',
      );
    });

    test('6. Hebrew Questions title is "שאלות ללקוח"', () {
      expect(
        ProfessionalAiResultSection.questions
            .titleFor(ProfessionalAiResponseLanguage.hebrew),
        'שאלות ללקוח',
      );
    });

    test('7. English Tools title is "Tools and Materials"', () {
      expect(
        ProfessionalAiResultSection.toolsAndMaterials
            .titleFor(ProfessionalAiResponseLanguage.english),
        'Tools and Materials',
      );
    });

    test('8. Arabic Tools title is "الأدوات والمواد"', () {
      expect(
        ProfessionalAiResultSection.toolsAndMaterials
            .titleFor(ProfessionalAiResponseLanguage.arabic),
        'الأدوات والمواد',
      );
    });

    test('9. Hebrew Tools title is "כלים וחומרים"', () {
      expect(
        ProfessionalAiResultSection.toolsAndMaterials
            .titleFor(ProfessionalAiResponseLanguage.hebrew),
        'כלים וחומרים',
      );
    });

    test('10. Suggested Steps titles are correct in all three languages', () {
      expect(
        ProfessionalAiResultSection.suggestedSteps
            .titleFor(ProfessionalAiResponseLanguage.english),
        'Suggested Steps',
      );
      expect(
        ProfessionalAiResultSection.suggestedSteps
            .titleFor(ProfessionalAiResponseLanguage.arabic),
        'الخطوات المقترحة',
      );
      expect(
        ProfessionalAiResultSection.suggestedSteps
            .titleFor(ProfessionalAiResponseLanguage.hebrew),
        'שלבים מוצעים',
      );
    });

    test('11. Safety Warnings titles are correct in all three languages', () {
      expect(
        ProfessionalAiResultSection.safetyWarnings
            .titleFor(ProfessionalAiResponseLanguage.english),
        'Safety Warnings',
      );
      expect(
        ProfessionalAiResultSection.safetyWarnings
            .titleFor(ProfessionalAiResponseLanguage.arabic),
        'تحذيرات السلامة',
      );
      expect(
        ProfessionalAiResultSection.safetyWarnings
            .titleFor(ProfessionalAiResponseLanguage.hebrew),
        'אזהרות בטיחות',
      );
    });

    test('12. Customer Message titles are correct in all three languages',
        () {
      expect(
        ProfessionalAiResultSection.customerMessage
            .titleFor(ProfessionalAiResponseLanguage.english),
        'Customer Message',
      );
      expect(
        ProfessionalAiResultSection.customerMessage
            .titleFor(ProfessionalAiResponseLanguage.arabic),
        'رسالة للعميل',
      );
      expect(
        ProfessionalAiResultSection.customerMessage
            .titleFor(ProfessionalAiResponseLanguage.hebrew),
        'הודעה ללקוח',
      );
    });

    test('13. English title direction is LTR', () {
      expect(ProfessionalAiResponseLanguage.english.isRtl, isFalse);
    });

    test('14. Arabic title direction is RTL', () {
      expect(ProfessionalAiResponseLanguage.arabic.isRtl, isTrue);
    });

    test('15. Hebrew title direction is RTL', () {
      expect(ProfessionalAiResponseLanguage.hebrew.isRtl, isTrue);
    });
  });
}
