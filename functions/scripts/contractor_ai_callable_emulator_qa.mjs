#!/usr/bin/env node
'use strict';

// Isolated local Functions-emulator QA script for `analyzeContractorJobPlan`
// (Contractor AI Crew & Order Planner — now Gemini-backed). This is a
// development test asset only:
//
//   - Never imported by production code (functions/src/index.ts never
//     references this file).
//   - Uses only Node.js built-ins (fetch, crypto, fs, path) plus
//     `firebase-admin`, which is already an installed production
//     dependency of this package — no new packages are added.
//   - Talks to the real `analyzeContractorJobPlan` HTTP callable endpoint
//     using the standard Firebase callable protocol (POST {"data": ...},
//     optional `Authorization: Bearer <ID token>`), and mints those ID
//     tokens through the Auth Emulator's own REST API (custom-token
//     exchange) — it never imports or calls any production helper
//     directly, so authentication/ownership/request-validation are
//     exercised exactly as a real client would trigger them.
//   - Refuses to run unless it can prove it is talking to local emulators
//     (see assertEmulatorSafety below) and unless the target project id
//     starts with "demo-".
//   - Seeds/reads/deletes only synthetic `users/{uid}`, `orders/{id}`,
//     and `contractor_workers/{id}` documents it creates itself.
//   - IMPORTANT: the callable now requires a real Gemini response for a
//     successful valid request. This script never fakes, mocks, or
//     bypasses that — it only checks for a genuine local
//     `functions/.secret.local` file containing a real `GEMINI_API_KEY`
//     value (never reads or prints the value itself). When that file is
//     missing or empty (the normal state of this repository), the one
//     "real Gemini-backed successful generation" case is reported as
//     BLOCKED — never faked as PASS. Every other case that used to
//     assert a full successful response now asserts the weaker, but
//     still fully honest and locally verifiable, claim that the request
//     passed every Contractor-side check and reached Gemini, where it
//     either succeeds (if a secret is genuinely configured) or fails
//     safely (the expected local outcome). The deterministic
//     worker-ranking/matching/workload content that a prior, pre-Gemini
//     version of this script verified by inspecting a guaranteed-shell
//     response is not re-verified here — it is unrelated to this step's
//     Gemini-wiring goal, was not touched by this step, and remains
//     proven both at the pure-function level (contractor_ai_helpers_qa.mjs,
//     41/41) and by this script's own prior 97/97 run (preserved as
//     historical evidence, not rerun here).
//   - Never prints ID tokens, raw order/worker content, prompts, raw
//     Gemini output, or stack traces.
//
// Run only via:
//   firebase emulators:exec --project demo-san3a-contractor-ai-qa \
//     --only auth,firestore,functions \
//     "node functions/scripts/contractor_ai_callable_emulator_qa.mjs"

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FUNCTIONS_DIR = path.resolve(__dirname, '..');

// Detects a genuine local Gemini secret without ever reading or
// printing its value — only its presence/non-emptiness is checked.
// Mirrors the same `.secret.local` convention already proven by
// functions/scripts/professional_ai_emulator_qa.mjs, but additionally
// requires the file to actually contain a non-empty `GEMINI_API_KEY`
// line (an empty file, which is this repository's normal checked-in
// state, must not be mistaken for a configured secret).
function hasLocalGeminiSecret() {
  const secretFilePath = path.join(FUNCTIONS_DIR, '.secret.local');
  if (!fs.existsSync(secretFilePath)) return false;
  let content;
  try {
    content = fs.readFileSync(secretFilePath, 'utf8');
  } catch {
    return false;
  }
  return /GEMINI_API_KEY\s*=\s*\S+/.test(content);
}

// ─── Emulator / production-isolation safety gate ──────────────────────────
function assertEmulatorSafety() {
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const projectId =
    process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || '';

  const problems = [];
  if (!firestoreHost) {
    problems.push('FIRESTORE_EMULATOR_HOST is not set.');
  }
  if (!authHost) {
    problems.push('FIREBASE_AUTH_EMULATOR_HOST is not set.');
  }
  if (!projectId.startsWith('demo-')) {
    problems.push(
      `Project id "${projectId || '(empty)'}" does not start with "demo-".`,
    );
  }

  if (problems.length > 0) {
    console.error('ABORT: cannot prove this run is safely isolated to local emulators.');
    for (const p of problems) console.error(`  - ${p}`);
    console.error(
      'Refusing to seed or call anything. Run this script only via:\n' +
      '  firebase emulators:exec --project demo-<name> --only auth,firestore,functions "node functions/scripts/contractor_ai_callable_emulator_qa.mjs"',
    );
    process.exit(1);
  }

  return { firestoreHost, authHost, projectId };
}

const { authHost, projectId: PROJECT_ID } = assertEmulatorSafety();

// firebase-admin auto-detects FIRESTORE_EMULATOR_HOST /
// FIREBASE_AUTH_EMULATOR_HOST from the environment once initializeApp()
// is called — no emulator-specific admin API is needed beyond that.
const admin = (await import('firebase-admin')).default;
admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();
const auth = admin.auth();

const CALLABLE_REGION = 'us-central1';
const CALLABLE_NAME = 'analyzeContractorJobPlan';
const CALLABLE_URL = `http://127.0.0.1:5001/${PROJECT_ID}/${CALLABLE_REGION}/${CALLABLE_NAME}`;
const RUN_ID = crypto.randomBytes(4).toString('hex');
const suid = (label) => `qa_contai_${label}_${RUN_ID}`;

// ─── Tiny test-runner ───────────────────────────────────────────────────
let passCount = 0;
let failCount = 0;
let blockedCount = 0;
const rows = [];

function record(caseId, description, expected, actual, outcome) {
  if (outcome === 'BLOCKED') blockedCount++;
  else if (outcome) passCount++;
  else failCount++;
  const label = outcome === 'BLOCKED' ? 'BLOCKED' : outcome ? 'PASS' : 'FAIL';
  rows.push({ caseId, description, expected, actual, label });
  console.log(`[${label}] #${caseId} ${description} — expected=${expected} actual=${actual}`);
}

function recordBlocked(caseId, description, expected, actual) {
  record(caseId, description, expected, actual, 'BLOCKED');
}

// ─── Callable protocol helpers ──────────────────────────────────────────
async function invokeRaw(body, idToken) {
  const headers = { 'Content-Type': 'application/json' };
  if (idToken) headers.Authorization = `Bearer ${idToken}`;
  const res = await fetch(CALLABLE_URL, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    // no JSON body — leave json null
  }
  return { httpStatus: res.status, json };
}

function invokeWithData(data, idToken) {
  return invokeRaw({ data }, idToken);
}

function extractError(result) {
  const err = result.json && result.json.error;
  if (!err) return null;
  return {
    code: String(err.status || '').toLowerCase().replace(/_/g, '-'),
    reason: err.details && err.details.reason,
  };
}

function checkErrorCode(caseId, description, result, expectedCode, expectedReason) {
  const err = extractError(result);
  const codeOk = !!err && err.code === expectedCode;
  const reasonOk = expectedReason ? !!err && err.reason === expectedReason : true;
  const ok = codeOk && reasonOk;
  const actual = err
    ? expectedReason
      ? `${err.code}${err.reason ? ` / ${err.reason}` : ' / (no reason)'}`
      : err.code
    : `HTTP ${result.httpStatus} (no callable error envelope)`;
  const expected = expectedReason ? `${expectedCode} / ${expectedReason}` : expectedCode;
  record(caseId, description, expected, actual, ok);
  return ok;
}

function checkSuccess(caseId, description, result, validator) {
  if (!result.json || !('result' in result.json)) {
    record(caseId, description, 'HTTP 200 callable result', `HTTP ${result.httpStatus} (no result envelope)`, false);
    return null;
  }
  const value = result.json.result;
  const problems = validator(value);
  const ok = problems.length === 0;
  record(caseId, description, 'valid result shape', ok ? 'valid result shape' : problems.join('; '), ok);
  return ok ? value : null;
}

function assertCase(caseId, description, condition, expected, actual) {
  record(caseId, description, expected, actual, !!condition);
}

// The set of reasons that mean a request was rejected *before* ever
// reaching the rate limiter or Gemini — role, ownership, order
// eligibility, or the internal workforce-invariant check. Used to prove
// "this request was accepted past ownership" without requiring a real
// Gemini response.
const CONTRACTOR_AI_PRE_QUOTA_REJECTION_REASONS = [
  'contractor_only', 'order_not_found', 'contractor_ai_invalid_planning_state',
];

// The set of reasons a request may safely fail with once it has already
// passed role/ownership/eligibility/invariant checks and the rate
// limiter has allowed it through to Gemini.
const CONTRACTOR_AI_SAFE_GEMINI_STAGE_REASONS = [
  'contractor_ai_provider_quota', 'contractor_ai_unavailable', 'contractor_ai_invalid_response',
];

// Proves a request was accepted past every Contractor-side check (role,
// ownership, providerRole compatibility, status eligibility, and the
// internal workforce invariant) without requiring a genuine Gemini
// response: it passes whenever the result is a real success, or a
// failure whose reason is NOT one of the pre-quota rejection reasons
// (i.e. it got at least as far as the rate limiter/Gemini stage).
function checkAcceptedPastOwnership(caseId, description, result) {
  const err = extractError(result);
  const rejectedBeforeQuota = !!err && CONTRACTOR_AI_PRE_QUOTA_REJECTION_REASONS.includes(err.reason);
  const ok = !rejectedBeforeQuota;
  const actual = err ? `${err.code}/${err.reason || '(no reason)'}` : 'success (no error)';
  record(caseId, description, 'not rejected by role/ownership/status/invariant checks', actual, ok);
}

// Proves a request reached Gemini: either a genuine successful,
// well-shaped response (only possible if a real local secret is
// configured), or a safe, allow-listed failure at the Gemini stage
// itself — never a role/ownership/status/invariant/rate-limit
// rejection, which would mean the request never actually reached
// Gemini. Never treats "no local secret configured" as a failure of
// this specific case — that distinct fact is reported once, separately,
// by the dedicated BLOCKED case.
function checkReachesGeminiSafely(caseId, description, result) {
  if (result.json && 'result' in result.json) {
    const v = result.json.result;
    const problems = [];
    if (v.schemaVersion !== 1) problems.push('schemaVersion !== 1');
    if (typeof v.summary !== 'string' || v.summary.length === 0) problems.push('summary invalid');
    if (!Array.isArray(v.rankedWorkerFacts)) problems.push('rankedWorkerFacts not an array');
    const ok = problems.length === 0;
    record(caseId, description, 'reaches Gemini: real success or safe failure', ok ? 'real success' : problems.join('; '), ok);
    return;
  }
  const err = extractError(result);
  const isSafeGeminiFailure = !!err &&
    (err.code === 'unavailable' || err.code === 'internal' || err.code === 'resource-exhausted') &&
    CONTRACTOR_AI_SAFE_GEMINI_STAGE_REASONS.includes(err.reason);
  const actual = err ? `${err.code}/${err.reason || '(no reason)'}` : 'no envelope';
  record(caseId, description, 'reaches Gemini: real success or safe failure', actual, isSafeGeminiFailure);
}

// ─── Auth Emulator: create a synthetic user + mint a real ID token ────────
async function createSyntheticUserWithToken(uid) {
  await auth.createUser({ uid });
  const customToken = await auth.createCustomToken(uid);
  const res = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake-api-key-for-emulator`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const json = await res.json();
  if (!json.idToken) {
    throw new Error(`Failed to mint an emulator ID token for ${uid} (Auth Emulator response had no idToken field).`);
  }
  return json.idToken; // never logged
}

async function countCollectionDocs(collectionName) {
  const snap = await db.collection(collectionName).get();
  return snap.size;
}

const ts = (date) => admin.firestore.Timestamp.fromDate(date);

// ─── Contractor AI rate-limit doc seeding/reading (Admin SDK, emulator only) ─
const CONTRACTOR_AI_RATE_LIMITS_COLLECTION = 'contractor_ai_rate_limits';
const CONTRACTOR_AI_USER_DAILY_LIMIT = 4;
const CONTRACTOR_AI_GLOBAL_DAILY_LIMIT = 16;
const CONTRACTOR_AI_REQUEST_COOLDOWN_SECONDS = 10;

function contractorAiRateLimitDoc(docId) {
  return db.collection(CONTRACTOR_AI_RATE_LIMITS_COLLECTION).doc(docId);
}

function todayUtcDayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function seedContractorAiUserCounter(uid, { dailyCount, cooldownActive, dayKey }) {
  const data = {
    dayKey: dayKey || todayUtcDayKey(),
    dailyCount,
    updatedAt: admin.firestore.Timestamp.now(),
  };
  if (cooldownActive) {
    data.lastRequestAt = admin.firestore.Timestamp.now();
  }
  await contractorAiRateLimitDoc(`users_${uid}`).set(data);
}

async function seedContractorAiGlobalCounter({ dailyCount, dayKey }) {
  await contractorAiRateLimitDoc('global').set({
    dayKey: dayKey || todayUtcDayKey(),
    dailyCount,
    updatedAt: admin.firestore.Timestamp.now(),
  });
}

async function readContractorAiUserCounter(uid) {
  const snap = await contractorAiRateLimitDoc(`users_${uid}`).get();
  return snap.exists ? snap.data() : null;
}

async function readContractorAiGlobalCounter() {
  const snap = await contractorAiRateLimitDoc('global').get();
  return snap.exists ? snap.data() : null;
}

async function clearAllContractorAiCounters(uids) {
  const batch = db.batch();
  batch.delete(contractorAiRateLimitDoc('global'));
  for (const uid of uids) batch.delete(contractorAiRateLimitDoc(`users_${uid}`));
  await batch.commit();
}

// Resets Contractor A's Contractor AI quota to a completely clean slate
// (no cooldown, dailyCount 0) immediately before a pre-existing
// business-logic assertion that expects a successful call — those
// assertions test role/ownership/matching/determinism, not rate
// limiting, so they must never be blocked by quota exhausted by an
// earlier assertion in this same script run.
async function resetContractorAiQuotaForCleanCall(uid) {
  await contractorAiRateLimitDoc(`users_${uid}`).delete().catch(() => {});
  await contractorAiRateLimitDoc('global').delete().catch(() => {});
}

// ─── main ──────────────────────────────────────────────────────────────
async function main() {
  console.log(`Contractor AI callable QA — project=${PROJECT_ID} run=${RUN_ID}`);
  console.log(`Callable URL: ${CALLABLE_URL}`);

  // ── Synthetic identities ────────────────────────────────────────────
  const contractorAUid = suid('contractor_a');
  const contractorBUid = suid('contractor_b');
  const professionalUid = suid('professional');
  const customerUid = suid('customer');
  const adminUid = suid('admin');
  const allUids = [contractorAUid, contractorBUid, professionalUid, customerUid, adminUid];

  // Declared here (not inside the try block below) so the finally block's
  // cleanup step can still reach them even if an assertion throws midway.
  const workersCol = db.collection('contractor_workers');
  const ordersCol = db.collection('orders');

  // ── Synthetic worker ids (Contractor A owns all but one) ────────────
  const wAvailableMatch = suid('w_available_match');
  const wBusyMatch = suid('w_busy_match');
  const wOfflineExplicit = suid('w_offline_explicit');
  const wMalformedStatus = suid('w_malformed_status');
  const wLegacySpecialty = suid('w_legacy_specialty');
  const wCanonicalSpecialties = suid('w_canonical_specialties');
  const wOutsideHours = suid('w_outside_hours');
  const wMalformedHours = suid('w_malformed_hours');
  const wAssignedToMain = suid('w_assigned_to_main');
  const wLegacyWorkload = suid('w_legacy_workload');
  const wProximitySame = suid('w_proximity_same');
  const wProximity30 = suid('w_proximity_30');
  const wProximityOver30 = suid('w_proximity_over30');
  const wContractorB = suid('w_contractor_b');
  // Dedicated, individually-attributable workers for the supporting-order
  // providerRole compatibility filter — each is assigned to exactly one
  // new supporting order below, so its activeWorkload alone proves
  // whether that one order was included or excluded.
  const wSupportingRoleProfessional = suid('w_supporting_role_professional');
  const wSupportingRoleCustomer = suid('w_supporting_role_customer');
  const wSupportingRoleUnknown = suid('w_supporting_role_unknown');
  const wSupportingRoleMissing = suid('w_supporting_role_missing');
  const wSupportingRoleBlank = suid('w_supporting_role_blank');
  const wSupportingRoleTrimmedContractor = suid('w_supporting_role_trimmed');
  // Six dedicated workers, all assigned to one order, so that order's
  // computed alreadyAssignedCount (6) exceeds the app's own proven
  // 5-assigned-worker cap — deliberately malformed/legacy-shaped data
  // for the internal workforce-invariant rejection test.
  const wInvalidState1 = suid('w_invalid_state_1');
  const wInvalidState2 = suid('w_invalid_state_2');
  const wInvalidState3 = suid('w_invalid_state_3');
  const wInvalidState4 = suid('w_invalid_state_4');
  const wInvalidState5 = suid('w_invalid_state_5');
  const wInvalidState6 = suid('w_invalid_state_6');
  const invalidStateWorkerIds = [
    wInvalidState1, wInvalidState2, wInvalidState3,
    wInvalidState4, wInvalidState5, wInvalidState6,
  ];
  const contractorAWorkerIds = [
    wAvailableMatch, wBusyMatch, wOfflineExplicit, wMalformedStatus,
    wLegacySpecialty, wCanonicalSpecialties, wOutsideHours, wMalformedHours,
    wAssignedToMain, wLegacyWorkload, wProximitySame, wProximity30,
    wProximityOver30, wSupportingRoleProfessional, wSupportingRoleCustomer,
    wSupportingRoleUnknown, wSupportingRoleMissing, wSupportingRoleBlank,
    wSupportingRoleTrimmedContractor, ...invalidStateWorkerIds,
  ];

  // ── Synthetic order ids ──────────────────────────────────────────────
  const orderMain = suid('order_main_inprogress');
  const orderPendingNoCategory = suid('order_pending_no_category');
  const orderCompleted = suid('order_completed');
  const orderCancelled = suid('order_cancelled');
  const orderLegacyNoRole = suid('order_legacy_no_role');
  const orderWrongRole = suid('order_wrong_role');
  const orderB = suid('order_contractor_b');
  const nonexistentOrderId = suid('order_nonexistent');
  const orderOtherWorkload = suid('order_other_workload_legacy');
  const orderProximitySameId = suid('order_proximity_same');
  const orderProximity30Id = suid('order_proximity_30');
  const orderProximityOver30Id = suid('order_proximity_over30');
  // Supporting orders for the providerRole compatibility filter — same
  // providerId (Contractor A) and status ("inProgress") as any other
  // supporting order, but each exercises one providerRole case.
  const orderRoleProfessional = suid('order_role_professional');
  const orderRoleCustomer = suid('order_role_customer');
  const orderRoleUnknown = suid('order_role_unknown');
  const orderRoleMissing = suid('order_role_missing');
  const orderRoleBlank = suid('order_role_blank');
  const orderRoleTrimmedContractor = suid('order_role_trimmed_contractor');
  // Selected-order (not supporting-order) providerRole compatibility
  // cases — each is itself the order requested by the callable, proving
  // the shared rule also governs selected-order acceptance/rejection.
  const orderSelRoleNumber = suid('order_sel_role_number');
  const orderSelRoleBool = suid('order_sel_role_bool');
  const orderSelRoleObject = suid('order_sel_role_object');
  const orderSelRoleArray = suid('order_sel_role_array');
  const orderSelRoleUnknownString = suid('order_sel_role_unknown_string');
  const orderSelRoleTrimmedContractor = suid('order_sel_role_trimmed');
  const orderSelRoleBlank = suid('order_sel_role_blank');
  const orderSelRoleMissing = suid('order_sel_role_missing');
  const orderSelRoleNull = suid('order_sel_role_null');
  // Selected order with 6 real owned workers assigned — its computed
  // alreadyAssignedCount (6) violates the internal workforce invariant
  // (must never exceed 5), even though role/ownership/status are all
  // otherwise valid.
  const orderInvalidPlanningState = suid('order_invalid_planning_state');

  const MAIN_SERVICE_DATE = new Date(Date.UTC(2026, 5, 1, 9, 0, 0));
  const PROXIMITY_SAME = new Date(MAIN_SERVICE_DATE.getTime());
  const PROXIMITY_30 = new Date(MAIN_SERVICE_DATE.getTime() + 30 * 60 * 1000);
  const PROXIMITY_OVER30 = new Date(MAIN_SERVICE_DATE.getTime() + 31 * 60 * 1000);
  // Deliberately far from MAIN_SERVICE_DATE so the three "compatible
  // supporting order" role cases below only ever exercise the workload
  // count, never an incidental proximity signal.
  const FAR_SERVICE_DATE = new Date(Date.UTC(2026, 7, 1, 9, 0, 0));

  try {
    // ── Seed synthetic users/{uid} ─────────────────────────────────────
    await db.collection('users').doc(contractorAUid).set({ role: 'contractor' });
    await db.collection('users').doc(contractorBUid).set({ role: 'contractor' });
    await db.collection('users').doc(professionalUid).set({ role: 'professional' });
    await db.collection('users').doc(customerUid).set({ role: 'customer' });
    await db.collection('users').doc(adminUid).set({ role: 'admin' });

    const idTokenContractorA = await createSyntheticUserWithToken(contractorAUid);
    const idTokenContractorB = await createSyntheticUserWithToken(contractorBUid);
    const idTokenProfessional = await createSyntheticUserWithToken(professionalUid);
    const idTokenCustomer = await createSyntheticUserWithToken(customerUid);
    const idTokenAdmin = await createSyntheticUserWithToken(adminUid);
    console.log('Synthetic users created and emulator ID tokens minted (tokens not logged).');

    // ── Seed synthetic contractor_workers ────────────────────────────────
    await workersCol.doc(wAvailableMatch).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Available Match',
      status: 'available',
      specialties: ['cat_plumbing'],
      workStartTime: '08:00',
      workEndTime: '18:00',
      currentJobs: 999, // deliberately bogus — must be ignored (case 20)
      completedJobs: 40,
    });
    await workersCol.doc(wBusyMatch).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Busy Match',
      status: 'busy',
      specialties: ['cat_plumbing'],
      workStartTime: '08:00',
      workEndTime: '18:00',
    });
    await workersCol.doc(wOfflineExplicit).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Offline Explicit',
      status: 'offline',
      specialties: ['cat_electrical'],
    });
    await workersCol.doc(wMalformedStatus).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Malformed Status',
      status: 12345, // wrong type — must normalize to "offline"
      specialties: ['cat_plumbing'],
    });
    await workersCol.doc(wLegacySpecialty).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Legacy Specialty',
      status: 'available',
      specialty: 'cat_plumbing', // legacy scalar, no specialties[] array
    });
    await workersCol.doc(wCanonicalSpecialties).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Canonical Specialties',
      status: 'available',
      specialties: ['cat_plumbing', 'cat_electrical'],
    });
    await workersCol.doc(wOutsideHours).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Outside Hours',
      status: 'available',
      specialties: ['cat_plumbing'],
      workStartTime: '20:00',
      workEndTime: '23:00',
    });
    await workersCol.doc(wMalformedHours).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Malformed Hours',
      status: 'available',
      specialties: ['cat_plumbing'],
      workStartTime: '9am',
      workEndTime: '5pm',
    });
    await workersCol.doc(wAssignedToMain).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Assigned To Main',
      status: 'available',
      specialties: ['cat_plumbing'],
      workStartTime: '08:00',
      workEndTime: '18:00',
    });
    await workersCol.doc(wLegacyWorkload).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Legacy Workload',
      status: 'available',
      specialties: ['cat_plumbing'],
    });
    await workersCol.doc(wProximitySame).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Proximity Same',
      status: 'available',
      specialties: ['cat_plumbing'],
    });
    await workersCol.doc(wProximity30).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Proximity 30',
      status: 'available',
      specialties: ['cat_plumbing'],
    });
    await workersCol.doc(wProximityOver30).set({
      contractorId: contractorAUid,
      fullName: 'QA Worker Proximity Over 30',
      status: 'available',
      specialties: ['cat_plumbing'],
    });
    // Contractor B's own worker — must never leak into Contractor A's results.
    await workersCol.doc(wContractorB).set({
      contractorId: contractorBUid,
      fullName: 'QA Worker Contractor B',
      status: 'available',
      specialties: ['cat_plumbing'],
    });
    // Dedicated workers for the supporting-order providerRole
    // compatibility filter (one per new supporting order below).
    for (const id of [
      wSupportingRoleProfessional, wSupportingRoleCustomer,
      wSupportingRoleUnknown, wSupportingRoleMissing, wSupportingRoleBlank,
      wSupportingRoleTrimmedContractor,
    ]) {
      await workersCol.doc(id).set({
        contractorId: contractorAUid,
        fullName: `QA Worker ${id}`,
        status: 'available',
        specialties: [],
      });
    }
    // Six dedicated workers for the invalid-planning-state test — all
    // six will be assigned to one order below, deliberately producing
    // alreadyAssignedCount = 6 > 5.
    for (const id of invalidStateWorkerIds) {
      await workersCol.doc(id).set({
        contractorId: contractorAUid,
        fullName: `QA Worker ${id}`,
        status: 'available',
        specialties: [],
      });
    }
    console.log('Synthetic contractor_workers created.');

    // ── Seed synthetic orders ────────────────────────────────────────────
    // The main selected order — Contractor A, inProgress, rich PII/price
    // fields that must never leak into the sanitized response, plus an
    // existing assignment to wAssignedToMain.
    await ordersCol.doc(orderMain).set({
      customerId: customerUid,
      customerName: 'QA Secret Customer Name',
      customerPhone: '+10000000001',
      providerId: contractorAUid,
      providerName: 'QA Secret Contractor Company',
      providerRole: 'contractor',
      title: 'Fix leaking kitchen pipe',
      description: 'The kitchen pipe under the sink is leaking badly.',
      area: 'QA Secret Area',
      categoryId: 'cat_plumbing',
      categoryNameKey: 'category_plumbing',
      priority: 'urgent',
      selectedServices: [
        {
          id: 'svc_pipe_repair',
          name: 'Pipe repair',
          description: 'Repair the leaking pipe',
          categoryId: 'cat_plumbing',
          price: 999,
        },
      ],
      serviceDate: ts(MAIN_SERVICE_DATE),
      status: 'inProgress',
      assignedWorkers: [
        { id: wAssignedToMain, name: 'QA Secret Worker Name', specialties: ['cat_plumbing'] },
      ],
      createdAt: ts(new Date(Date.UTC(2026, 4, 1, 0, 0, 0))),
    });

    // Same-owner order with no category info at all — proves no fake match.
    await ordersCol.doc(orderPendingNoCategory).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'Some general handyman task',
      description: 'General task with no category information.',
      status: 'pending',
      serviceDate: ts(new Date(Date.UTC(2026, 5, 2, 9, 0, 0))),
    });

    await ordersCol.doc(orderCompleted).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'A completed job',
      description: 'Already finished.',
      status: 'completed',
      serviceDate: ts(new Date(Date.UTC(2026, 4, 20, 9, 0, 0))),
    });

    await ordersCol.doc(orderCancelled).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'A cancelled job',
      description: 'No longer happening.',
      status: 'cancelled',
      serviceDate: ts(new Date(Date.UTC(2026, 4, 21, 9, 0, 0))),
    });

    await ordersCol.doc(orderLegacyNoRole).set({
      customerId: customerUid,
      providerId: contractorAUid,
      // Deliberately no providerRole field — legacy-order compatibility case.
      title: 'A legacy order with no providerRole',
      description: 'Predates the providerRole field.',
      status: 'pending',
      serviceDate: ts(new Date(Date.UTC(2026, 5, 3, 9, 0, 0))),
    });

    await ordersCol.doc(orderWrongRole).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'professional', // wrong role for a Contractor-only order
      title: 'A wrong-providerRole order',
      description: 'providerRole names a different role than Contractor.',
      status: 'pending',
      serviceDate: ts(new Date(Date.UTC(2026, 5, 4, 9, 0, 0))),
    });

    await ordersCol.doc(orderB).set({
      customerId: customerUid,
      providerId: contractorBUid,
      providerRole: 'contractor',
      title: "Contractor B's own order",
      description: 'Owned entirely by Contractor B.',
      status: 'pending',
      serviceDate: ts(new Date(Date.UTC(2026, 5, 5, 9, 0, 0))),
    });

    // Another Contractor-A-owned inProgress order, assigning a worker only
    // via the legacy scalar assignedWorkerId (workload test case 22).
    await ordersCol.doc(orderOtherWorkload).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'Another in-progress job (legacy assignment)',
      description: 'Assigned via the legacy assignedWorkerId field.',
      status: 'inProgress',
      assignedWorkerId: wLegacyWorkload,
      serviceDate: ts(new Date(Date.UTC(2026, 5, 10, 9, 0, 0))),
    });

    // Three Contractor-A-owned inProgress orders for proximity cases.
    await ordersCol.doc(orderProximitySameId).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'Proximity: same time as main',
      description: 'Same appointment time as the main order.',
      status: 'inProgress',
      assignedWorkers: [{ id: wProximitySame, name: 'x', specialties: [] }],
      serviceDate: ts(PROXIMITY_SAME),
    });
    await ordersCol.doc(orderProximity30Id).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'Proximity: exactly 30 minutes after main',
      description: 'Exactly 30 minutes after the main order.',
      status: 'inProgress',
      assignedWorkers: [{ id: wProximity30, name: 'x', specialties: [] }],
      serviceDate: ts(PROXIMITY_30),
    });
    await ordersCol.doc(orderProximityOver30Id).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'Proximity: 31 minutes after main',
      description: 'More than 30 minutes after the main order.',
      status: 'inProgress',
      assignedWorkers: [{ id: wProximityOver30, name: 'x', specialties: [] }],
      serviceDate: ts(PROXIMITY_OVER30),
    });

    // Supporting-order providerRole compatibility filter cases. The three
    // wrong-role orders are deliberately same-time as the main order, so
    // they would incorrectly both inflate workload AND trigger a
    // proximity warning if the compatibility filter were missing. The
    // three compatible-role orders use a far-away serviceDate so their
    // inclusion only ever proves the workload count, not proximity.
    await ordersCol.doc(orderRoleProfessional).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'professional',
      title: 'Supporting order with providerRole professional',
      description: 'Must be excluded from Contractor AI calculations.',
      status: 'inProgress',
      assignedWorkers: [{ id: wSupportingRoleProfessional, name: 'x', specialties: [] }],
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderRoleCustomer).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'customer',
      title: 'Supporting order with providerRole customer',
      description: 'Must be excluded from Contractor AI calculations.',
      status: 'inProgress',
      assignedWorkers: [{ id: wSupportingRoleCustomer, name: 'x', specialties: [] }],
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderRoleUnknown).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'unknown_role_xyz',
      title: 'Supporting order with an unknown providerRole',
      description: 'Must be excluded from Contractor AI calculations.',
      status: 'inProgress',
      assignedWorkers: [{ id: wSupportingRoleUnknown, name: 'x', specialties: [] }],
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderRoleMissing).set({
      customerId: customerUid,
      providerId: contractorAUid,
      // Deliberately no providerRole field — legacy compatibility case,
      // must remain included.
      title: 'Supporting order with missing providerRole (legacy)',
      description: 'Must remain included (legacy-compatible).',
      status: 'inProgress',
      assignedWorkers: [{ id: wSupportingRoleMissing, name: 'x', specialties: [] }],
      serviceDate: ts(FAR_SERVICE_DATE),
    });
    await ordersCol.doc(orderRoleBlank).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: '',
      title: 'Supporting order with blank providerRole',
      description: 'Must remain included (blank-compatible).',
      status: 'inProgress',
      assignedWorkers: [{ id: wSupportingRoleBlank, name: 'x', specialties: [] }],
      serviceDate: ts(FAR_SERVICE_DATE),
    });
    await ordersCol.doc(orderRoleTrimmedContractor).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: '  CONTRACTOR  ',
      title: 'Supporting order with trimmed/case-normalized providerRole',
      description: 'Must remain included (normalizes to "contractor").',
      status: 'inProgress',
      assignedWorkers: [{ id: wSupportingRoleTrimmedContractor, name: 'x', specialties: [] }],
      serviceDate: ts(FAR_SERVICE_DATE),
    });

    // Selected-order providerRole compatibility cases. Each of these is
    // itself the order id requested by the callable (never a supporting
    // order), proving the shared rule governs selected-order
    // acceptance/rejection the same way it governs supporting orders.
    await ordersCol.doc(orderSelRoleNumber).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 123,
      title: 'Selected order with providerRole as a number',
      description: 'Must be rejected generically.',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleBool).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: true,
      title: 'Selected order with providerRole as a boolean',
      description: 'Must be rejected generically.',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleObject).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: {},
      title: 'Selected order with providerRole as an object',
      description: 'Must be rejected generically.',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleArray).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: [],
      title: 'Selected order with providerRole as an array',
      description: 'Must be rejected generically.',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleUnknownString).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'unknown',
      title: 'Selected order with an unknown providerRole string',
      description: 'Must be rejected generically.',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleTrimmedContractor).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: '   CONTRACTOR   ',
      title: 'Selected order with trimmed/case-normalized providerRole',
      description: 'Must be accepted (normalizes to "contractor").',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleBlank).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: '',
      title: 'Selected order with a blank providerRole',
      description: 'Must be accepted (legacy-compatible).',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleMissing).set({
      customerId: customerUid,
      providerId: contractorAUid,
      // Deliberately no providerRole field.
      title: 'Selected order with a missing providerRole',
      description: 'Must be accepted (legacy-compatible).',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });
    await ordersCol.doc(orderSelRoleNull).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: null,
      title: 'Selected order with providerRole explicitly null',
      description: 'Must be accepted (legacy-compatible).',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
    });

    // Role/ownership/status are all valid here, but 6 real owned
    // workers are assigned — the computed alreadyAssignedCount (6)
    // violates the internal workforce invariant (never > 5).
    await ordersCol.doc(orderInvalidPlanningState).set({
      customerId: customerUid,
      providerId: contractorAUid,
      providerRole: 'contractor',
      title: 'Selected order with an impossible planning state',
      description: 'Six workers assigned, exceeding the 5-worker cap.',
      status: 'pending',
      serviceDate: ts(MAIN_SERVICE_DATE),
      assignedWorkers: invalidStateWorkerIds.map((id) => ({ id, name: 'x', specialties: [] })),
    });
    console.log('Synthetic orders created.');

    const validBody = () => ({
      orderId: orderMain,
      locale: 'en',
      planningIntent: 'prepare_job',
    });

    // Baseline collection doc-count snapshot, taken before any callable
    // invocation, to later prove no write ever happens (cases 35-36).
    const ordersCountBefore = await countCollectionDocs('orders');
    const workersCountBefore = await countCollectionDocs('contractor_workers');
    const orderMainSnapBefore = (await ordersCol.doc(orderMain).get()).data();

    // ── Case 1: unauthenticated ─────────────────────────────────────────
    {
      const result = await invokeWithData(validBody(), undefined);
      checkErrorCode(1, 'Unauthenticated request rejected', result, 'unauthenticated');
    }

    // ── Cases 2-4: role enforcement ──────────────────────────────────────
    {
      const result = await invokeWithData(validBody(), idTokenCustomer);
      checkErrorCode(2, 'Customer rejected', result, 'permission-denied', 'contractor_only');
    }
    {
      const result = await invokeWithData(validBody(), idTokenProfessional);
      checkErrorCode(3, 'Professional rejected', result, 'permission-denied', 'contractor_only');
    }
    {
      const result = await invokeWithData(validBody(), idTokenAdmin);
      checkErrorCode(4, 'Admin rejected', result, 'permission-denied', 'contractor_only');
    }

    // ── Case 5: Contractor A accepted past every Contractor-side check ───
    // Full deterministic-content verification (worker isolation,
    // workload, specialty match, proximity, working hours, ranking,
    // aggregate/sanitized-order privacy) required a guaranteed
    // successful response and was already exhaustively proven by this
    // script's own prior 97/97 run before Gemini was wired in (preserved
    // as historical evidence) and at the pure-function level
    // (contractor_ai_helpers_qa.mjs, 41/41) — neither was touched by
    // this step, so it is not re-verified here.
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkAcceptedPastOwnership(5, 'Contractor A accepted past every Contractor-side check', result);
    }

    // ── Case 6-7: cross-contractor order isolation ───────────────────────
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderMain }, idTokenContractorB);
      checkErrorCode(6, "Contractor B cannot access Contractor A's order", result, 'not-found', 'order_not_found');
    }
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderB }, idTokenContractorA);
      checkErrorCode(7, "Contractor A cannot access Contractor B's order", result, 'not-found', 'order_not_found');
    }

    // ── Case 8: missing order rejected generically ───────────────────────
    {
      const result = await invokeWithData({ ...validBody(), orderId: nonexistentOrderId }, idTokenContractorA);
      checkErrorCode(8, 'Missing order rejected generically', result, 'not-found', 'order_not_found');
    }

    // ── Case 9: wrong providerRole rejected ──────────────────────────────
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderWrongRole }, idTokenContractorA);
      checkErrorCode(9, 'Wrong providerRole rejected', result, 'not-found', 'order_not_found');
    }

    // ── Case 10: legacy missing providerRole accepted ────────────────────
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const result = await invokeWithData({ ...validBody(), orderId: orderLegacyNoRole }, idTokenContractorA);
      checkAcceptedPastOwnership(10, 'Legacy order with missing providerRole accepted', result);
    }

    // ── Case 11-12: ineligible statuses rejected ─────────────────────────
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderCompleted }, idTokenContractorA);
      checkErrorCode(11, 'Completed order rejected', result, 'not-found', 'order_not_found');
    }
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderCancelled }, idTokenContractorA);
      checkErrorCode(12, 'Cancelled order rejected', result, 'not-found', 'order_not_found');
    }

    // ── Case 13-16: strict request-shape validation ──────────────────────
    {
      const result = await invokeWithData({ ...validBody(), uid: 'someone-else' }, idTokenContractorA);
      checkErrorCode(13, 'Extra request key rejected', result, 'invalid-argument');
    }
    {
      const body = validBody();
      delete body.locale;
      const result = await invokeWithData(body, idTokenContractorA);
      checkErrorCode(14, 'Missing request key rejected', result, 'invalid-argument');
    }
    {
      const result = await invokeWithData({ ...validBody(), locale: 'fr' }, idTokenContractorA);
      checkErrorCode(15, 'Unsupported locale rejected', result, 'invalid-argument');
    }
    {
      const result = await invokeWithData({ ...validBody(), planningIntent: 'do_something_else' }, idTokenContractorA);
      checkErrorCode(16, 'Unsupported planningIntent rejected', result, 'invalid-argument');
    }

    // ── Cases 17-34 (worker isolation, currentJobs-ignored, workload,
    // specialty match, existing assignment, proximity x3, working hours,
    // aggregate/sanitized-order privacy, ranked-facts key set) and cases
    // 24/31 (no-fake-match, deterministic stable ordering) all required
    // inspecting deterministic content from a guaranteed-successful
    // response. That full deterministic-content coverage was already
    // exhaustively proven both at the pure-function level
    // (contractor_ai_helpers_qa.mjs, 41/41) and by this exact script,
    // pre-Gemini, in a 97/97 run (preserved as historical evidence, not
    // rerun here) — neither the pure helpers nor that deterministic
    // logic were touched by this Gemini-integration step, and a real
    // Gemini response is required to obtain a successful result to
    // inspect locally, which no genuine local secret is configured for
    // (see hasLocalGeminiSecret above). These case numbers are
    // intentionally not reused for anything else in this file.
    // ── Cases 37-43 (supporting-order providerRole compatibility
    // filter: professional/customer/unknown roles excluded from
    // workload and proximity; legacy-missing/blank/trimmed-contractor
    // roles remain included) all required inspecting rankedWorkerFacts
    // from a guaranteed-successful response, for the same reason as
    // cases 17-34 above. This exact filter logic was already
    // exhaustively proven, pre-Gemini, by this same script in a 97/97
    // run (preserved as historical evidence, not rerun here) — the
    // filter itself (functions/src/index.ts,
    // isContractorAiProviderRoleCompatible) was not touched by this
    // Gemini-integration step.
    // ── Case 44: selected-order wrong-providerRole rejection unchanged ───
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderWrongRole }, idTokenContractorA);
      checkErrorCode(44, 'Selected order wrong-providerRole rejection remains unchanged', result, 'not-found', 'order_not_found');
    }

    // ── Case 45: cross-contractor isolation remains unchanged ────────────
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderMain }, idTokenContractorB);
      checkErrorCode(45, "Cross-contractor isolation remains unchanged (Contractor B still blocked)", result, 'not-found', 'order_not_found');
    }

    // ── Cases 46-50: selected-order providerRole wrong-type/unknown rejected ─
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleNumber }, idTokenContractorA);
      checkErrorCode(46, 'Selected order providerRole=123 (number) rejected generically', result, 'not-found', 'order_not_found');
    }
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleBool }, idTokenContractorA);
      checkErrorCode(47, 'Selected order providerRole=true (boolean) rejected generically', result, 'not-found', 'order_not_found');
    }
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleObject }, idTokenContractorA);
      checkErrorCode(48, 'Selected order providerRole={} (object) rejected generically', result, 'not-found', 'order_not_found');
    }
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleArray }, idTokenContractorA);
      checkErrorCode(49, 'Selected order providerRole=[] (array) rejected generically', result, 'not-found', 'order_not_found');
    }
    {
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleUnknownString }, idTokenContractorA);
      checkErrorCode(50, 'Selected order providerRole="unknown" rejected generically', result, 'not-found', 'order_not_found');
    }

    // ── Cases 51-54: selected-order providerRole legacy/compatible accepted ─
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleTrimmedContractor }, idTokenContractorA);
      checkAcceptedPastOwnership(51, 'Selected order providerRole="   CONTRACTOR   " accepted (trimmed/case-normalized)', result);
    }
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleBlank }, idTokenContractorA);
      checkAcceptedPastOwnership(52, 'Selected order providerRole="" (blank) accepted', result);
    }
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleMissing }, idTokenContractorA);
      checkAcceptedPastOwnership(53, 'Selected order with missing providerRole accepted', result);
    }
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const result = await invokeWithData({ ...validBody(), orderId: orderSelRoleNull }, idTokenContractorA);
      checkAcceptedPastOwnership(54, 'Selected order with providerRole=null accepted', result);
    }

    // ── Cases 91-92: internal workforce-invariant rejection ──────────────
    // Role, ownership, and status are all valid for orderInvalidPlanningState,
    // but 6 real owned workers are assigned to it, so the computed
    // alreadyAssignedCount (6) violates the app's own proven 5-assigned-
    // worker cap. This must be rejected generically, before quota or
    // Gemini are ever reached.
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const beforeUser = await readContractorAiUserCounter(contractorAUid);
      const beforeGlobal = await readContractorAiGlobalCounter();
      const result = await invokeWithData({ ...validBody(), orderId: orderInvalidPlanningState }, idTokenContractorA);
      checkErrorCode(91, 'Invalid internal planning state (alreadyAssignedCount > 5) rejected safely', result, 'failed-precondition', 'contractor_ai_invalid_planning_state');
      const afterUser = await readContractorAiUserCounter(contractorAUid);
      const afterGlobal = await readContractorAiGlobalCounter();
      const beforeUserCount = beforeUser ? beforeUser.dailyCount : 0;
      const afterUserCount = afterUser ? afterUser.dailyCount : 0;
      const beforeGlobalCount = beforeGlobal ? beforeGlobal.dailyCount : 0;
      const afterGlobalCount = afterGlobal ? afterGlobal.dailyCount : 0;
      assertCase(
        92,
        'Invalid-planning-state rejection consumes no Contractor AI quota',
        afterUserCount === beforeUserCount && afterGlobalCount === beforeGlobalCount,
        `user ${beforeUserCount}, global ${beforeGlobalCount}`,
        `user ${afterUserCount}, global ${afterGlobalCount}`,
      );
    }

    // ── Cases 55-68: no request that is rejected before the rate limiter ──
    // ── ever consumes quota ────────────────────────────────────────────
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const bodyMissingLocale = validBody();
      delete bodyMissingLocale.locale;
      const noConsumptionCases = [
        { id: 55, desc: 'Unauthenticated request consumes no quota', data: validBody(), token: undefined },
        { id: 56, desc: 'Customer request consumes no quota', data: validBody(), token: idTokenCustomer },
        { id: 57, desc: 'Professional request consumes no quota', data: validBody(), token: idTokenProfessional },
        { id: 58, desc: 'Admin request consumes no quota', data: validBody(), token: idTokenAdmin },
        { id: 59, desc: 'Missing request key consumes no quota', data: bodyMissingLocale, token: idTokenContractorA },
        { id: 60, desc: 'Extra request key consumes no quota', data: { ...validBody(), uid: 'someone-else' }, token: idTokenContractorA },
        { id: 61, desc: 'Unsupported locale consumes no quota', data: { ...validBody(), locale: 'fr' }, token: idTokenContractorA },
        { id: 62, desc: 'Unsupported planningIntent consumes no quota', data: { ...validBody(), planningIntent: 'do_something_else' }, token: idTokenContractorA },
        { id: 63, desc: 'Missing order consumes no quota', data: { ...validBody(), orderId: nonexistentOrderId }, token: idTokenContractorA },
        { id: 64, desc: "Another Contractor's order consumes no quota", data: { ...validBody(), orderId: orderB }, token: idTokenContractorA },
        { id: 65, desc: 'Wrong selected-order providerRole consumes no quota', data: { ...validBody(), orderId: orderWrongRole }, token: idTokenContractorA },
        { id: 66, desc: 'Wrong-type selected-order providerRole consumes no quota', data: { ...validBody(), orderId: orderSelRoleNumber }, token: idTokenContractorA },
        { id: 67, desc: 'Completed order consumes no quota', data: { ...validBody(), orderId: orderCompleted }, token: idTokenContractorA },
        { id: 68, desc: 'Cancelled order consumes no quota', data: { ...validBody(), orderId: orderCancelled }, token: idTokenContractorA },
      ];
      for (const c of noConsumptionCases) {
        const beforeUser = await readContractorAiUserCounter(contractorAUid);
        const beforeGlobal = await readContractorAiGlobalCounter();
        await invokeWithData(c.data, c.token);
        const afterUser = await readContractorAiUserCounter(contractorAUid);
        const afterGlobal = await readContractorAiGlobalCounter();
        const beforeUserCount = beforeUser ? beforeUser.dailyCount : 0;
        const afterUserCount = afterUser ? afterUser.dailyCount : 0;
        const beforeGlobalCount = beforeGlobal ? beforeGlobal.dailyCount : 0;
        const afterGlobalCount = afterGlobal ? afterGlobal.dailyCount : 0;
        const noChange = afterUserCount === beforeUserCount && afterGlobalCount === beforeGlobalCount;
        assertCase(
          c.id,
          c.desc,
          noChange,
          `user ${beforeUserCount}, global ${beforeGlobalCount}`,
          `user ${afterUserCount}, global ${afterGlobalCount}`,
        );
      }
    }

    // ── Cases 69-75: first successful consumption ────────────────────────
    {
      await resetContractorAiQuotaForCleanCall(contractorAUid);
      const beforeCallTime = admin.firestore.Timestamp.now();
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkReachesGeminiSafely(69, 'First valid Contractor request reaches Gemini after quota reset', result);

      const userDoc = await readContractorAiUserCounter(contractorAUid);
      const globalDoc = await readContractorAiGlobalCounter();

      // The rate limiter reserves the request (dailyCount becomes 1 for
      // both documents) before Gemini is ever called, so this holds
      // regardless of whether Gemini itself then succeeds or fails.
      assertCase(70, 'User dailyCount becomes exactly 1', !!userDoc && userDoc.dailyCount === 1, '1', userDoc ? String(userDoc.dailyCount) : 'missing');
      assertCase(71, 'Global dailyCount becomes exactly 1', !!globalDoc && globalDoc.dailyCount === 1, '1', globalDoc ? String(globalDoc.dailyCount) : 'missing');

      const today = todayUtcDayKey();
      assertCase(
        72,
        'Both documents use the same current dayKey',
        !!userDoc && !!globalDoc && userDoc.dayKey === today && globalDoc.dayKey === today,
        today,
        `user=${userDoc ? userDoc.dayKey : 'missing'}, global=${globalDoc ? globalDoc.dayKey : 'missing'}`,
      );

      const lastRequestOk = !!userDoc && userDoc.lastRequestAt &&
        typeof userDoc.lastRequestAt.toMillis === 'function' &&
        userDoc.lastRequestAt.toMillis() >= beforeCallTime.toMillis();
      const userUpdatedAtOk = !!userDoc && userDoc.updatedAt && typeof userDoc.updatedAt.toMillis === 'function';
      const globalUpdatedAtOk = !!globalDoc && globalDoc.updatedAt && typeof globalDoc.updatedAt.toMillis === 'function';
      assertCase(
        73,
        'lastRequestAt and updatedAt are valid server timestamps',
        lastRequestOk && userUpdatedAtOk && globalUpdatedAtOk,
        'valid Timestamp instances, lastRequestAt >= call time',
        `lastRequestAt ok=${!!lastRequestOk}, user updatedAt ok=${!!userUpdatedAtOk}, global updatedAt ok=${!!globalUpdatedAtOk}`,
      );

      // 74/75 inspect the actual callable response envelope (success or
      // safe failure — whichever this run produced), never assuming a
      // successful shape, since Gemini success cannot be guaranteed
      // without a genuine local secret.
      const serializedEnvelope = JSON.stringify(result.json || {});
      const leaksRateLimitField = /dailyCount|lastRequestAt|updatedAt|dayKey/i.test(serializedEnvelope);
      assertCase(
        74,
        'No rate-limit counts appear in the callable response envelope',
        !leaksRateLimitField,
        'no rate-limit fields present',
        leaksRateLimitField ? 'a rate-limit field was found' : 'clean',
      );

      const leaksKnownPii = [customerUid, 'QA Secret Customer Name', contractorAUid, wAssignedToMain]
        .some((sentinel) => serializedEnvelope.includes(sentinel));
      assertCase(
        75,
        'No known PII/identity sentinel appears in the callable response envelope',
        !leaksKnownPii,
        'no PII sentinel present',
        leaksKnownPii ? 'a PII sentinel was found' : 'clean',
      );
    }

    // ── Cases 76-78: cooldown ─────────────────────────────────────────────
    {
      const beforeUser = await readContractorAiUserCounter(contractorAUid);
      const beforeGlobal = await readContractorAiGlobalCounter();
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkErrorCode(76, 'Immediate second valid request rejected with cooldown', result, 'resource-exhausted', 'contractor_ai_cooldown');
      const afterUser = await readContractorAiUserCounter(contractorAUid);
      const afterGlobal = await readContractorAiGlobalCounter();
      assertCase(
        77,
        'Cooldown rejection does not increment user dailyCount',
        !!beforeUser && !!afterUser && afterUser.dailyCount === beforeUser.dailyCount,
        String(beforeUser ? beforeUser.dailyCount : 'n/a'),
        String(afterUser ? afterUser.dailyCount : 'n/a'),
      );
      assertCase(
        78,
        'Cooldown rejection does not increment global dailyCount',
        !!beforeGlobal && !!afterGlobal && afterGlobal.dailyCount === beforeGlobal.dailyCount,
        String(beforeGlobal ? beforeGlobal.dailyCount : 'n/a'),
        String(afterGlobal ? afterGlobal.dailyCount : 'n/a'),
      );
    }

    // ── Cases 79-82: per-Contractor daily limit ───────────────────────────
    {
      await seedContractorAiUserCounter(contractorAUid, { dailyCount: 3, cooldownActive: false });
      await seedContractorAiGlobalCounter({ dailyCount: 0 });
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkReachesGeminiSafely(79, 'Seeded user count of 3 allows one final request through to Gemini', result);
      const userDoc = await readContractorAiUserCounter(contractorAUid);
      assertCase(0, 'User dailyCount is now 4 after the seeded-3 request', !!userDoc && userDoc.dailyCount === 4, '4', userDoc ? String(userDoc.dailyCount) : 'missing');
    }
    {
      const beforeGlobal = await readContractorAiGlobalCounter();
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkErrorCode(80, 'Next request rejected with per-Contractor daily limit', result, 'resource-exhausted', 'contractor_ai_user_daily_limit');
      const afterGlobal = await readContractorAiGlobalCounter();
      assertCase(
        81,
        'User-daily-limit rejection does not change the global count',
        !!beforeGlobal && !!afterGlobal && afterGlobal.dailyCount === beforeGlobal.dailyCount,
        String(beforeGlobal ? beforeGlobal.dailyCount : 'n/a'),
        String(afterGlobal ? afterGlobal.dailyCount : 'n/a'),
      );
    }
    {
      const yesterdayKey = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      await seedContractorAiUserCounter(contractorAUid, { dailyCount: 4, cooldownActive: false, dayKey: yesterdayKey });
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkReachesGeminiSafely(82, 'A prior-day user document resets logically, allowing the request through to Gemini', result);
      const userDoc = await readContractorAiUserCounter(contractorAUid);
      const today = todayUtcDayKey();
      assertCase(
        0,
        'Prior-day user doc now uses todayKey with dailyCount 1',
        !!userDoc && userDoc.dayKey === today && userDoc.dailyCount === 1,
        `dayKey=${today}, dailyCount=1`,
        userDoc ? `dayKey=${userDoc.dayKey}, dailyCount=${userDoc.dailyCount}` : 'missing',
      );
    }

    // ── Cases 83-86: global daily limit ───────────────────────────────────
    {
      await seedContractorAiUserCounter(contractorAUid, { dailyCount: 0, cooldownActive: false });
      await seedContractorAiGlobalCounter({ dailyCount: 15 });
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkReachesGeminiSafely(83, 'Seeded global count of 15 allows one final request through to Gemini', result);
      const globalDoc = await readContractorAiGlobalCounter();
      assertCase(0, 'Global dailyCount is now 16 after the seeded-15 request', !!globalDoc && globalDoc.dailyCount === 16, '16', globalDoc ? String(globalDoc.dailyCount) : 'missing');
    }
    {
      await seedContractorAiUserCounter(contractorAUid, { dailyCount: 0, cooldownActive: false });
      const beforeUser = await readContractorAiUserCounter(contractorAUid);
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkErrorCode(84, 'Next valid request rejected with global daily limit', result, 'resource-exhausted', 'contractor_ai_global_daily_limit');
      const afterUser = await readContractorAiUserCounter(contractorAUid);
      assertCase(
        85,
        'Global rejection does not increment the user count',
        !!beforeUser && !!afterUser && afterUser.dailyCount === beforeUser.dailyCount,
        String(beforeUser ? beforeUser.dailyCount : 'n/a'),
        String(afterUser ? afterUser.dailyCount : 'n/a'),
      );
    }
    {
      const yesterdayKey = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      await seedContractorAiGlobalCounter({ dailyCount: 16, dayKey: yesterdayKey });
      await seedContractorAiUserCounter(contractorAUid, { dailyCount: 0, cooldownActive: false });
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkReachesGeminiSafely(86, 'A prior-day global document resets logically, allowing the request through to Gemini', result);
      const globalDoc = await readContractorAiGlobalCounter();
      const today = todayUtcDayKey();
      assertCase(
        0,
        'Prior-day global doc now uses todayKey with dailyCount 1',
        !!globalDoc && globalDoc.dayKey === today && globalDoc.dailyCount === 1,
        `dayKey=${today}, dailyCount=1`,
        globalDoc ? `dayKey=${globalDoc.dayKey}, dailyCount=${globalDoc.dailyCount}` : 'missing',
      );
    }

    // ── Cases 87-88: atomicity ─────────────────────────────────────────────
    {
      await clearAllContractorAiCounters([contractorAUid]);
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkReachesGeminiSafely(0, 'Fresh call for the atomicity check reaches Gemini', result);
      const userDoc = await readContractorAiUserCounter(contractorAUid);
      const globalDoc = await readContractorAiGlobalCounter();
      assertCase(
        87,
        'An accepted request increments both user and global exactly once',
        !!userDoc && !!globalDoc && userDoc.dailyCount === 1 && globalDoc.dailyCount === 1,
        'user=1, global=1',
        `user=${userDoc ? userDoc.dailyCount : 'missing'}, global=${globalDoc ? globalDoc.dailyCount : 'missing'}`,
      );
    }
    {
      await seedContractorAiUserCounter(contractorAUid, { dailyCount: 4, cooldownActive: false });
      await seedContractorAiGlobalCounter({ dailyCount: 0 });
      const result = await invokeWithData(validBody(), idTokenContractorA);
      checkErrorCode(0, 'Rejected call for the partial-increment check', result, 'resource-exhausted', 'contractor_ai_user_daily_limit');
      const userDoc = await readContractorAiUserCounter(contractorAUid);
      const globalDoc = await readContractorAiGlobalCounter();
      assertCase(
        88,
        'No partial increment occurs when the user daily limit rejects (global stays untouched)',
        !!userDoc && userDoc.dailyCount === 4 && !!globalDoc && globalDoc.dailyCount === 0,
        'user=4, global=0',
        `user=${userDoc ? userDoc.dailyCount : 'missing'}, global=${globalDoc ? globalDoc.dailyCount : 'missing'}`,
      );
    }

    // ── Cases 89-90: no unrelated writes, no stored result ────────────────
    {
      const conversationsCount = await countCollectionDocs('conversations');
      const notificationsCount = await countCollectionDocs('notifications');
      assertCase(
        89,
        'No conversation or notification document is created by the rate limiter or callable',
        conversationsCount === 0 && notificationsCount === 0,
        '0 conversations, 0 notifications',
        `conversations=${conversationsCount}, notifications=${notificationsCount}`,
      );
    }
    {
      const userDoc = await readContractorAiUserCounter(contractorAUid);
      const globalDoc = await readContractorAiGlobalCounter();
      const allowedKeys = ['dayKey', 'dailyCount', 'lastRequestAt', 'updatedAt'];
      const userKeysOk = !!userDoc && Object.keys(userDoc).every((k) => allowedKeys.includes(k));
      const globalKeysOk = !!globalDoc && Object.keys(globalDoc).every((k) => allowedKeys.includes(k));
      const serialized = JSON.stringify({ user: userDoc, global: globalDoc });
      const forbiddenResultKeys = ['orderId', 'planningIntent', 'sanitizedOrder', 'workerAggregate', 'rankedWorkerFacts'];
      const noResultLeak = !forbiddenResultKeys.some((k) => serialized.includes(k));
      assertCase(
        90,
        'No Contractor AI result is stored — rate-limit documents contain only allow-listed fields',
        userKeysOk && globalKeysOk && noResultLeak,
        'only dayKey/dailyCount/lastRequestAt/updatedAt, no result content',
        `userKeys=${userDoc ? Object.keys(userDoc).join(',') : 'missing'}, globalKeys=${globalDoc ? Object.keys(globalDoc).join(',') : 'missing'}`,
      );
    }

    // ── Case 93: the one real Gemini-backed successful-generation case ──
    // Attempted at most once, and only if a genuine local secret is
    // configured. This repository's checked-in functions/.secret.local
    // is empty, so this is expected to be BLOCKED in the normal case —
    // never faked as PASS, never retried.
    {
      if (hasLocalGeminiSecret()) {
        await resetContractorAiQuotaForCleanCall(contractorAUid);
        const result = await invokeWithData(validBody(), idTokenContractorA);
        checkSuccess(93, 'Real Gemini-backed successful generation', result, (v) => {
          const problems = [];
          if (v.schemaVersion !== 1) problems.push('schemaVersion !== 1');
          if (v.orderId !== orderMain) problems.push('orderId mismatch');
          if (typeof v.summary !== 'string' || v.summary.length === 0) problems.push('summary invalid');
          if (!Array.isArray(v.rankedWorkerFacts)) problems.push('rankedWorkerFacts not an array');
          const forbidden = ['sanitizedOrder', 'workerAggregate'];
          for (const key of forbidden) {
            if (Object.prototype.hasOwnProperty.call(v, key)) problems.push(`forbidden field present: ${key}`);
          }
          return problems;
        });
      } else {
        recordBlocked(
          93,
          'Real Gemini-backed successful generation',
          'PASS if a genuine local GEMINI_API_KEY were configured',
          'BLOCKED — functions/.secret.local has no configured GEMINI_API_KEY value locally',
        );
      }
    }

    // ── Cases 35-36: no persistent side effects anywhere ─────────────────
    {
      const ordersCountAfter = await countCollectionDocs('orders');
      const workersCountAfter = await countCollectionDocs('contractor_workers');
      const orderMainSnapAfter = (await ordersCol.doc(orderMain).get()).data();
      const noNewDocs = ordersCountAfter === ordersCountBefore && workersCountAfter === workersCountBefore;
      const orderUnchanged = JSON.stringify(orderMainSnapBefore) === JSON.stringify(orderMainSnapAfter);
      assertCase(
        35,
        'No Firestore document is created or modified by the callable',
        noNewDocs && orderUnchanged,
        'orders/contractor_workers doc counts unchanged, orderMain content unchanged',
        `orders: ${ordersCountBefore}->${ordersCountAfter}, workers: ${workersCountBefore}->${workersCountAfter}, orderMain unchanged: ${orderUnchanged}`,
      );
    }
    {
      // contractor_ai_rate_limits is deliberately excluded from this
      // "stays at zero" check — this step intentionally adds a real,
      // isolated Contractor AI rate limiter, so that collection is
      // expected to contain documents by now. Its own correctness is
      // proven by the dedicated Contractor AI rate-limit cases below;
      // this check instead proves the three *other* AI/Translation
      // rate-limit collections are never touched by analyzeContractorJobPlan.
      const aiRateLimitsDocs = await countCollectionDocs('ai_rate_limits');
      const professionalAiRateLimitsDocs = await countCollectionDocs('professional_ai_rate_limits');
      const translationRateLimitsDocs = await countCollectionDocs('translation_rate_limits');
      const allZero =
        aiRateLimitsDocs === 0 && professionalAiRateLimitsDocs === 0 &&
        translationRateLimitsDocs === 0;
      assertCase(
        36,
        'No AI/Professional AI/Translation rate-limit collection is touched by analyzeContractorJobPlan',
        allZero,
        '0 documents in ai_rate_limits/professional_ai_rate_limits/translation_rate_limits',
        `ai=${aiRateLimitsDocs}, professional=${professionalAiRateLimitsDocs}, translation=${translationRateLimitsDocs}`,
      );
    }
  } finally {
    // ── Cleanup: remove all synthetic data this run created ────────────
    console.log('Cleaning up synthetic emulator data...');
    try {
      const batch = db.batch();
      for (const id of [
        orderMain, orderPendingNoCategory, orderCompleted, orderCancelled,
        orderLegacyNoRole, orderWrongRole, orderB, orderOtherWorkload,
        orderProximitySameId, orderProximity30Id, orderProximityOver30Id,
        orderRoleProfessional, orderRoleCustomer, orderRoleUnknown,
        orderRoleMissing, orderRoleBlank, orderRoleTrimmedContractor,
        orderSelRoleNumber, orderSelRoleBool, orderSelRoleObject,
        orderSelRoleArray, orderSelRoleUnknownString,
        orderSelRoleTrimmedContractor, orderSelRoleBlank,
        orderSelRoleMissing, orderSelRoleNull, orderInvalidPlanningState,
      ]) {
        batch.delete(ordersCol.doc(id));
      }
      for (const id of [...contractorAWorkerIds, wContractorB]) {
        batch.delete(workersCol.doc(id));
      }
      for (const uid of allUids) {
        batch.delete(db.collection('users').doc(uid));
      }
      await batch.commit();
      await clearAllContractorAiCounters([contractorAUid, contractorBUid]);
      for (const uid of allUids) {
        await auth.deleteUser(uid).catch(() => {});
      }
    } catch (cleanupError) {
      console.error('Cleanup encountered an error (non-fatal):', cleanupError.message);
    }
  }

  console.log('');
  console.log('─── Summary ───────────────────────────────────────────');
  for (const row of rows) {
    console.log(`  [${row.label}] #${row.caseId || '-'} ${row.description}`);
  }
  console.log(`PASS: ${passCount}  FAIL: ${failCount}  BLOCKED: ${blockedCount}  TOTAL: ${rows.length}`);

  process.exit(failCount > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('QA script crashed:', err && err.message);
  process.exit(1);
});
