import 'package:flutter_test/flutter_test.dart';
import 'package:san3a/features/contractor_ai_planner/models/contractor_ai_plan_result.dart';
import 'package:san3a/features/contractor_ai_planner/presentation/providers/contractor_ai_planner_provider.dart';
import 'package:san3a/features/contractor_ai_planner/presentation/screens/contractor_ai_planner_screen.dart';
import 'package:san3a/shared/models/models.dart';

// Pure unit tests for the Contractor AI Crew & Order Planner's strict
// response-parsing contract and local worker-identity mapping helper — no
// Firestore/Riverpod/widget wiring involved, matching the existing
// professional_ai_daily_plan_test.dart / conversation_pending_gate_test.dart
// pattern for testing standalone pure functions and model parsers directly.

Map<String, dynamic> _validFact({
  String workerId = 'worker-1',
  bool alreadyAssigned = false,
  bool specialtyMatch = false,
  String status = 'available',
  int activeWorkload = 0,
  bool hasScheduleProximityWarning = false,
  String generalWorkingHoursSignal = 'unknown',
}) =>
    {
      'workerId': workerId,
      'alreadyAssigned': alreadyAssigned,
      'specialtyMatch': specialtyMatch,
      'status': status,
      'activeWorkload': activeWorkload,
      'hasScheduleProximityWarning': hasScheduleProximityWarning,
      'generalWorkingHoursSignal': generalWorkingHoursSignal,
    };

Map<String, dynamic> _validResponse({
  String orderId = 'order-1',
  String planningIntent = 'plan_crew',
  int recommendedWorkerCount = 2,
  List<Map<String, dynamic>>? rankedWorkerFacts,
}) =>
    {
      'schemaVersion': 1,
      'orderId': orderId,
      'planningIntent': planningIntent,
      'summary': 'A short summary.',
      'recommendedWorkerCount': recommendedWorkerCount,
      'crewGuidance': 'Bring two workers.',
      'questions': <String>['Any access restrictions?'],
      'toolsAndMaterials': <String>['Ladder'],
      'suggestedSteps': <String>['Step one', 'Step two'],
      'coordinationNotes': <String>['Coordinate arrival time.'],
      'safetyWarnings': <String>['Wear gloves.'],
      'customerMessage': 'We will arrive as scheduled.',
      'rankedWorkerFacts': rankedWorkerFacts ?? <Map<String, dynamic>>[],
    };

WorkerModel _worker(String id, {String name = 'Real Worker'}) => WorkerModel(
      id: id,
      name: name,
      specialty: 'plumbing',
    );

OrderModel _order({
  String id = 'order-1',
  OrderStatus status = OrderStatus.pending,
  List<AssignedWorkerSnapshot> assignedWorkers = const [],
  String? assignedWorkerId,
}) =>
    OrderModel(
      id: id,
      customerId: 'customer-1',
      providerId: 'provider-1',
      providerName: 'Provider',
      title: 'Title',
      description: 'Description',
      area: 'Area',
      serviceDate: DateTime(2026, 1, 1),
      status: status,
      createdAt: DateTime(2026, 1, 1),
      assignedWorkers: assignedWorkers,
      assignedWorkerId: assignedWorkerId,
    );

void main() {
  group('ContractorAiPlanResult.fromMap', () {
    test('1. accepts a fully valid, exact-key-set response', () {
      final result = ContractorAiPlanResult.fromMap(_validResponse());
      expect(result.orderId, 'order-1');
      expect(result.planningIntent, 'plan_crew');
      expect(result.recommendedWorkerCount, 2);
      expect(result.suggestedSteps, ['Step one', 'Step two']);
      expect(result.rankedWorkerFacts, isEmpty);
    });

    test('2. rejects a response missing a required top-level key', () {
      final raw = _validResponse()..remove('crewGuidance');
      expect(
        () => ContractorAiPlanResult.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('3. rejects a response with an extra top-level key', () {
      final raw = _validResponse();
      raw['sanitizedOrder'] = {'unexpected': true};
      expect(
        () => ContractorAiPlanResult.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        '9. rejects recommendedWorkerCount above the 0-5 bound '
        '(e.g. 6)', () {
      final raw = _validResponse(recommendedWorkerCount: 6);
      expect(
        () => ContractorAiPlanResult.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('9b. rejects a negative recommendedWorkerCount', () {
      final raw = _validResponse(recommendedWorkerCount: -1);
      expect(
        () => ContractorAiPlanResult.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'preserves orderId exactly, enabling the screen\'s '
        'order/result consistency check (stale-orderId detection)', () {
      final result =
          ContractorAiPlanResult.fromMap(_validResponse(orderId: 'order-9'));
      expect(result.orderId == 'order-9', isTrue);
      expect(result.orderId == 'some-other-order', isFalse);
    });
  });

  group('ContractorAiRankedWorkerFact.fromMap', () {
    test('4. accepts a fully valid, exact-key-set fact', () {
      final fact = ContractorAiRankedWorkerFact.fromMap(_validFact());
      expect(fact.workerId, 'worker-1');
      expect(fact.status, 'available');
      expect(fact.generalWorkingHoursSignal, 'unknown');
    });

    test('4b. rejects a fact missing a required key', () {
      final raw = _validFact()..remove('status');
      expect(
        () => ContractorAiRankedWorkerFact.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('4c. rejects a fact with an extra key', () {
      final raw = _validFact();
      raw['workerName'] = 'Should never appear';
      expect(
        () => ContractorAiRankedWorkerFact.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('5. rejects an unknown status value', () {
      final raw = _validFact(status: 'on_leave');
      expect(
        () => ContractorAiRankedWorkerFact.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('6. rejects an unknown generalWorkingHoursSignal value', () {
      final raw = _validFact(generalWorkingHoursSignal: 'sometimes');
      expect(
        () => ContractorAiRankedWorkerFact.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('7. rejects a negative activeWorkload', () {
      final raw = _validFact(activeWorkload: -1);
      expect(
        () => ContractorAiRankedWorkerFact.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('8. rejects a non-integer (decimal) activeWorkload', () {
      final raw = _validFact()..['activeWorkload'] = 1.5;
      expect(
        () => ContractorAiRankedWorkerFact.fromMap(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-map ranked worker fact entry', () {
      expect(
        () => ContractorAiRankedWorkerFact.fromMap('not-a-map'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('resolveContractorAiVisibleWorkerFacts', () {
    test(
        '10. preserves server rank order among facts that resolve '
        'locally', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(_validFact(workerId: 'w1')),
        ContractorAiRankedWorkerFact.fromMap(_validFact(workerId: 'w2')),
        ContractorAiRankedWorkerFact.fromMap(_validFact(workerId: 'w3')),
      ];
      final workersById = {
        'w1': _worker('w1', name: 'Alice'),
        'w2': _worker('w2', name: 'Bob'),
        'w3': _worker('w3', name: 'Carol'),
      };

      final resolved =
          resolveContractorAiVisibleWorkerFacts(facts, workersById);

      expect(resolved.visible.map((f) => f.workerId).toList(),
          ['w1', 'w2', 'w3']);
      expect(resolved.hasMissingWorkers, isFalse);
    });

    test(
        '11. omits a fact whose worker is no longer present locally, '
        'without exposing/inventing anything, and flags '
        'hasMissingWorkers', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(_validFact(workerId: 'w1')),
        ContractorAiRankedWorkerFact.fromMap(_validFact(workerId: 'stale')),
        ContractorAiRankedWorkerFact.fromMap(_validFact(workerId: 'w3')),
      ];
      final workersById = {
        'w1': _worker('w1', name: 'Alice'),
        'w3': _worker('w3', name: 'Carol'),
      };

      final resolved =
          resolveContractorAiVisibleWorkerFacts(facts, workersById);

      expect(
          resolved.visible.map((f) => f.workerId).toList(), ['w1', 'w3']);
      expect(resolved.visible.any((f) => f.workerId == 'stale'), isFalse);
      expect(resolved.hasMissingWorkers, isTrue);
    });

    test(
        '12. reports no missing workers for an empty rankedWorkerFacts '
        'input (a genuinely empty backend result is not a "stale data" '
        'case)', () {
      final resolved =
          resolveContractorAiVisibleWorkerFacts(const [], <String, WorkerModel>{});
      expect(resolved.visible, isEmpty);
      expect(resolved.hasMissingWorkers, isFalse);
    });
  });

  group('contractorAiAssignedWorkersMayHaveChanged', () {
    test('1. same assignments produce no changed warning', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'w1', alreadyAssigned: true)),
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'w2', alreadyAssigned: false)),
      ];
      final order = _order(assignedWorkers: const [
        AssignedWorkerSnapshot(id: 'w1', name: 'Alice'),
      ]);
      expect(
          contractorAiAssignedWorkersMayHaveChanged(facts, order), isFalse);
    });

    test('2. an added worker produces a changed warning', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'w1', alreadyAssigned: true)),
      ];
      final order = _order(assignedWorkers: const [
        AssignedWorkerSnapshot(id: 'w1', name: 'Alice'),
        AssignedWorkerSnapshot(id: 'w2', name: 'Bob'),
      ]);
      expect(contractorAiAssignedWorkersMayHaveChanged(facts, order), isTrue);
    });

    test('3. a removed worker produces a changed warning', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'w1', alreadyAssigned: true)),
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'w2', alreadyAssigned: true)),
      ];
      final order = _order(assignedWorkers: const [
        AssignedWorkerSnapshot(id: 'w1', name: 'Alice'),
      ]);
      expect(contractorAiAssignedWorkersMayHaveChanged(facts, order), isTrue);
    });

    test('4. the legacy assignedWorkerId is handled when no modern '
        'assignedWorkers snapshot is present', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'legacy-1', alreadyAssigned: true)),
      ];
      final sameOrder = _order(assignedWorkerId: 'legacy-1');
      expect(contractorAiAssignedWorkersMayHaveChanged(facts, sameOrder),
          isFalse);

      final changedOrder = _order(assignedWorkerId: 'legacy-2');
      expect(contractorAiAssignedWorkersMayHaveChanged(facts, changedOrder),
          isTrue);
    });

    test('5. duplicate ids do not produce a false difference', () {
      final facts = [
        ContractorAiRankedWorkerFact.fromMap(
            _validFact(workerId: 'w1', alreadyAssigned: true)),
      ];
      final order = _order(assignedWorkers: const [
        AssignedWorkerSnapshot(id: 'w1', name: 'Alice'),
        AssignedWorkerSnapshot(id: 'w1', name: 'Alice Duplicate'),
      ]);
      expect(
          contractorAiAssignedWorkersMayHaveChanged(facts, order), isFalse);
    });
  });

  // ─── Contractor AI Response Language ────────────────────────────────────
  // Pure, Firebase-free tests for the explicit response-language selector:
  // the enum's backend-code/RTL mapping, and the isolated
  // ContractorAiPlannerState.withResponseLanguageSelected pure
  // state-transition (extracted specifically so this contract is testable
  // without constructing a real ContractorAiPlannerRepository/controller,
  // which would require Firebase). Matches the existing pattern in this
  // file of testing standalone pure functions/parsers directly.
  group('ContractorAiResponseLanguage', () {
    test('1. default response language is English', () {
      expect(kContractorAiDefaultResponseLanguage,
          ContractorAiResponseLanguage.english);
      expect(const ContractorAiPlannerState().selectedResponseLanguage,
          ContractorAiResponseLanguage.english);
    });

    test('2. English maps exactly to "en"', () {
      expect(ContractorAiResponseLanguage.english.wireValue, 'en');
    });

    test('3. Arabic maps exactly to "ar"', () {
      expect(ContractorAiResponseLanguage.arabic.wireValue, 'ar');
    });

    test('4. Hebrew maps exactly to "he"', () {
      expect(ContractorAiResponseLanguage.hebrew.wireValue, 'he');
    });

    test('5. English is LTR', () {
      expect(ContractorAiResponseLanguage.english.isRtl, isFalse);
    });

    test('6. Arabic is RTL', () {
      expect(ContractorAiResponseLanguage.arabic.isRtl, isTrue);
    });

    test('7. Hebrew is RTL', () {
      expect(ContractorAiResponseLanguage.hebrew.isRtl, isTrue);
    });

    test('15. a freshly constructed state (as autoDispose creates on '
        'reopen) defaults to English', () {
      const freshState = ContractorAiPlannerState();
      expect(freshState.selectedResponseLanguage,
          ContractorAiResponseLanguage.english);
    });
  });

  group('ContractorAiPlannerState.withResponseLanguageSelected', () {
    test('8. changing language preserves the selected order', () {
      const state = ContractorAiPlannerState(selectedOrderId: 'order-1');
      final next =
          state.withResponseLanguageSelected(ContractorAiResponseLanguage.arabic);
      expect(next, isNotNull);
      expect(next!.selectedOrderId, 'order-1');
    });

    test('9. changing language preserves the selected planning intent', () {
      const state = ContractorAiPlannerState(
        selectedPlanningIntent: ContractorAiPlanningIntent.requestCustomerInfo,
      );
      final next =
          state.withResponseLanguageSelected(ContractorAiResponseLanguage.hebrew);
      expect(next, isNotNull);
      expect(next!.selectedPlanningIntent,
          ContractorAiPlanningIntent.requestCustomerInfo);
    });

    test('10. changing language clears the previous result', () {
      final result = ContractorAiPlanResult.fromMap(_validResponse());
      final state = ContractorAiPlannerState(result: result);
      final next =
          state.withResponseLanguageSelected(ContractorAiResponseLanguage.arabic);
      expect(next, isNotNull);
      expect(next!.result, isNull);
    });

    test('11. changing language clears the previous error', () {
      const state = ContractorAiPlannerState(
        errorCode: 'unknown',
        errorReason: 'contractor_ai_cooldown',
      );
      final next =
          state.withResponseLanguageSelected(ContractorAiResponseLanguage.hebrew);
      expect(next, isNotNull);
      expect(next!.errorCode, isNull);
      expect(next.errorReason, isNull);
    });

    test('12. selecting the already-selected language is a no-op', () {
      const state = ContractorAiPlannerState(); // defaults to English
      final next =
          state.withResponseLanguageSelected(ContractorAiResponseLanguage.english);
      expect(next, isNull);
    });

    test('13. language cannot change while a request is loading', () {
      const state = ContractorAiPlannerState(isLoading: true);
      final next =
          state.withResponseLanguageSelected(ContractorAiResponseLanguage.arabic);
      expect(next, isNull);
    });
  });

  group('ContractorAiRequestGenerationGuard', () {
    test(
        '14. a stale request generation cannot overwrite state after a '
        'change invalidates it', () {
      final guard = ContractorAiRequestGenerationGuard();
      final inFlightGeneration = guard.start();
      expect(guard.isCurrent(inFlightGeneration), isTrue);

      // Simulates the invalidation selectResponseLanguage performs on any
      // in-flight generation before applying the new language.
      guard.invalidate();

      expect(guard.isCurrent(inFlightGeneration), isFalse);
    });
  });

  // ─── Contractor AI Result-Section Titles & Captions ─────────────────────
  // Pure, Firebase/widget-free tests for the deterministic, local
  // section-title and caption mapping keyed only by
  // ContractorAiResponseLanguage — never derived from the generated text,
  // never an AI/translation call, never automatic language detection.
  group('ContractorAiResultSectionTitle', () {
    test('1. English Summary title is "Summary"', () {
      expect(
        ContractorAiResultSection.summary
            .titleFor(ContractorAiResponseLanguage.english),
        'Summary',
      );
    });

    test('2. Arabic Summary title is "الملخص"', () {
      expect(
        ContractorAiResultSection.summary
            .titleFor(ContractorAiResponseLanguage.arabic),
        'الملخص',
      );
    });

    test('3. Hebrew Summary title is "סיכום"', () {
      expect(
        ContractorAiResultSection.summary
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'סיכום',
      );
    });

    test('4. Recommended Crew Size title in all three languages', () {
      expect(
        ContractorAiResultSection.recommendedCrewSize
            .titleFor(ContractorAiResponseLanguage.english),
        'Recommended Crew Size',
      );
      expect(
        ContractorAiResultSection.recommendedCrewSize
            .titleFor(ContractorAiResponseLanguage.arabic),
        'حجم الطاقم المقترح',
      );
      expect(
        ContractorAiResultSection.recommendedCrewSize
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'גודל צוות מומלץ',
      );
    });

    test('5. Crew Guidance title in all three languages', () {
      expect(
        ContractorAiResultSection.crewGuidance
            .titleFor(ContractorAiResponseLanguage.english),
        'Crew Guidance',
      );
      expect(
        ContractorAiResultSection.crewGuidance
            .titleFor(ContractorAiResponseLanguage.arabic),
        'إرشادات الطاقم',
      );
      expect(
        ContractorAiResultSection.crewGuidance
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'הנחיות לצוות',
      );
    });

    test('6. Questions title in all three languages', () {
      expect(
        ContractorAiResultSection.questions
            .titleFor(ContractorAiResponseLanguage.english),
        'Questions to Ask',
      );
      expect(
        ContractorAiResultSection.questions
            .titleFor(ContractorAiResponseLanguage.arabic),
        'أسئلة للعميل',
      );
      expect(
        ContractorAiResultSection.questions
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'שאלות ללקוח',
      );
    });

    test('7. Tools title in all three languages', () {
      expect(
        ContractorAiResultSection.toolsAndMaterials
            .titleFor(ContractorAiResponseLanguage.english),
        'Tools and Materials',
      );
      expect(
        ContractorAiResultSection.toolsAndMaterials
            .titleFor(ContractorAiResponseLanguage.arabic),
        'الأدوات والمواد',
      );
      expect(
        ContractorAiResultSection.toolsAndMaterials
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'כלים וחומרים',
      );
    });

    test('8. Suggested Steps title in all three languages', () {
      expect(
        ContractorAiResultSection.suggestedSteps
            .titleFor(ContractorAiResponseLanguage.english),
        'Suggested Steps',
      );
      expect(
        ContractorAiResultSection.suggestedSteps
            .titleFor(ContractorAiResponseLanguage.arabic),
        'الخطوات المقترحة',
      );
      expect(
        ContractorAiResultSection.suggestedSteps
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'שלבים מוצעים',
      );
    });

    test('9. Coordination Notes title in all three languages', () {
      expect(
        ContractorAiResultSection.coordinationNotes
            .titleFor(ContractorAiResponseLanguage.english),
        'Coordination Notes',
      );
      expect(
        ContractorAiResultSection.coordinationNotes
            .titleFor(ContractorAiResponseLanguage.arabic),
        'ملاحظات التنسيق',
      );
      expect(
        ContractorAiResultSection.coordinationNotes
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'הערות תיאום',
      );
    });

    test('10. Safety Warnings title in all three languages', () {
      expect(
        ContractorAiResultSection.safetyWarnings
            .titleFor(ContractorAiResponseLanguage.english),
        'Safety Warnings',
      );
      expect(
        ContractorAiResultSection.safetyWarnings
            .titleFor(ContractorAiResponseLanguage.arabic),
        'تحذيرات السلامة',
      );
      expect(
        ContractorAiResultSection.safetyWarnings
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'אזהרות בטיחות',
      );
    });

    test('11. Customer Message title in all three languages', () {
      expect(
        ContractorAiResultSection.customerMessage
            .titleFor(ContractorAiResponseLanguage.english),
        'Customer Message',
      );
      expect(
        ContractorAiResultSection.customerMessage
            .titleFor(ContractorAiResponseLanguage.arabic),
        'رسالة للعميل',
      );
      expect(
        ContractorAiResultSection.customerMessage
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'הודעה ללקוח',
      );
    });

    test('12. Recommended Workers title in all three languages', () {
      expect(
        ContractorAiResultSection.recommendedWorkers
            .titleFor(ContractorAiResponseLanguage.english),
        'Recommended Workers',
      );
      expect(
        ContractorAiResultSection.recommendedWorkers
            .titleFor(ContractorAiResponseLanguage.arabic),
        'العمال المقترحون',
      );
      expect(
        ContractorAiResultSection.recommendedWorkers
            .titleFor(ContractorAiResponseLanguage.hebrew),
        'עובדים מומלצים',
      );
    });

    test('13. Advisory caption in all three languages', () {
      expect(
        ContractorAiResponseLanguage.english.recommendedCrewSizeAdvisoryCaption,
        'An advisory estimate only — you decide the final crew.',
      );
      expect(
        ContractorAiResponseLanguage.arabic.recommendedCrewSizeAdvisoryCaption,
        'تقدير استشاري فقط — أنت من يقرر الطاقم النهائي.',
      );
      expect(
        ContractorAiResponseLanguage.hebrew.recommendedCrewSizeAdvisoryCaption,
        'הערכה מייעצת בלבד — ההחלטה על הצוות הסופי היא שלך.',
      );
    });

    test('14. Manual-assignment caption in all three languages', () {
      expect(
        ContractorAiResponseLanguage.english.manualAssignmentCaption,
        'Worker assignment remains manual in Order Details.',
      );
      expect(
        ContractorAiResponseLanguage.arabic.manualAssignmentCaption,
        'يبقى تعيين العمال يدويًا من تفاصيل الطلب.',
      );
      expect(
        ContractorAiResponseLanguage.hebrew.manualAssignmentCaption,
        'הקצאת העובדים נשארת ידנית בפרטי ההזמנה.',
      );
    });

    test('15. English direction is LTR', () {
      expect(ContractorAiResponseLanguage.english.isRtl, isFalse);
    });

    test('16. Arabic direction is RTL', () {
      expect(ContractorAiResponseLanguage.arabic.isRtl, isTrue);
    });

    test('17. Hebrew direction is RTL', () {
      expect(ContractorAiResponseLanguage.hebrew.isRtl, isTrue);
    });
  });
}
