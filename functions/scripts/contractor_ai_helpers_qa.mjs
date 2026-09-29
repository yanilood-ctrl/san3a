#!/usr/bin/env node
'use strict';

// QA-only assertion script for functions/src/contractor_ai_helpers.ts
// (Contractor AI Crew & Order Planner — pure helper module).
//
//   - This script is a development test asset only: never imported by
//     production code, and functions/src/index.ts never references it.
//   - Uses only Node.js built-ins (`node:assert`, `node:path`,
//     `node:url`) plus a plain import of the already-compiled helper
//     module. No Firebase (Admin/client SDK), no Gemini/GenAI package,
//     no network access, no emulator.
//   - Imports functions/lib/contractor_ai_helpers.js, so `npm run build`
//     must be run first.
//   - Every helper under test is pure — no Firestore reads/writes ever
//     happen here.
//
// Run with:
//   npm run build
//   node functions/scripts/contractor_ai_helpers_qa.mjs

import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const helpersPath = path.join(__dirname, '..', 'lib', 'contractor_ai_helpers.js');
const helpers = await import(pathToFileURL(helpersPath).href);

let passCount = 0;
let failCount = 0;
const failures = [];

function test(id, description, fn) {
  try {
    fn();
    passCount++;
    console.log(`[PASS] #${id} ${description}`);
  } catch (err) {
    failCount++;
    failures.push({ id, description, err });
    console.log(`[FAIL] #${id} ${description} — ${err.message}`);
  }
}

function deepClone(value) {
  return JSON.parse(JSON.stringify(value));
}

// ── Order sanitizer (1-6) ──────────────────────────────────────────────

test(1, 'sanitizeContractorOrderForAi allows only approved fields', () => {
  const raw = {
    title: 'Fix leaking pipe',
    description: 'Kitchen pipe is leaking',
    categoryId: 'cat_plumbing',
    categoryNameKey: 'category_plumbing',
    priority: 'urgent',
    selectedServices: [
      { id: 'svc_1', name: 'Pipe repair', description: 'Fix pipe', categoryId: 'cat_plumbing', price: 100 },
    ],
  };
  const result = helpers.sanitizeContractorOrderForAi(raw);
  const allowedKeys = ['title', 'description', 'categoryId', 'categoryNameKey', 'priority', 'selectedServices'];
  for (const key of Object.keys(result)) {
    assert.ok(allowedKeys.includes(key), `unexpected top-level key: ${key}`);
  }
  const allowedServiceKeys = ['name', 'description', 'categoryId'];
  for (const service of result.selectedServices) {
    for (const key of Object.keys(service)) {
      assert.ok(allowedServiceKeys.includes(key), `unexpected service key: ${key}`);
    }
  }
});

test(2, 'sanitizeContractorOrderForAi removes customer/provider/price/worker fields', () => {
  const raw = {
    id: 'order_123',
    title: 'Fix leaking pipe',
    description: 'Kitchen pipe is leaking',
    providerId: 'contractor_uid_1',
    providerName: 'Ahmad Contracting',
    providerRole: 'contractor',
    customerId: 'customer_uid_1',
    customerName: 'Jane Doe',
    customerPhone: '+123456789',
    customerEmail: 'jane@example.com',
    area: 'Downtown',
    selectedServicePrice: 250,
    imageUrls: ['https://example.com/a.jpg'],
    assignedWorkerId: 'worker_1',
    assignedWorkerName: 'Omar',
    assignedWorkers: [{ id: 'worker_1', name: 'Omar', specialties: ['plumbing'] }],
    createdAt: '2026-01-01T00:00:00.000Z',
    serviceDate: '2026-02-01T09:00:00.000Z',
    status: 'inProgress',
  };
  const result = helpers.sanitizeContractorOrderForAi(raw);
  const serialized = JSON.stringify(result);
  const forbidden = [
    'order_123', 'contractor_uid_1', 'Ahmad Contracting', 'contractor',
    'customer_uid_1', 'Jane Doe', '+123456789', 'jane@example.com',
    'Downtown', '250', 'example.com', 'worker_1', 'Omar', 'inProgress',
  ];
  for (const value of forbidden) {
    assert.ok(!serialized.includes(value), `forbidden value leaked: ${value}`);
  }
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'id'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'providerId'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'customerId'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'assignedWorkers'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'assignedWorkerId'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'createdAt'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'serviceDate'));
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'status'));
});

test(3, 'sanitizeContractorOrderForAi trims and caps strings', () => {
  const overlongTitle = 'x'.repeat(200);
  const result = helpers.sanitizeContractorOrderForAi({
    title: '   padded title   ',
    description: overlongTitle,
  });
  assert.strictEqual(result.title, 'padded title');
  assert.strictEqual(result.description.length, helpers.MAX_CONTRACTOR_AI_ORDER_DESCRIPTION_LENGTH < overlongTitle.length ? helpers.MAX_CONTRACTOR_AI_ORDER_DESCRIPTION_LENGTH : overlongTitle.length);
  assert.strictEqual(result.description, overlongTitle.slice(0, helpers.MAX_CONTRACTOR_AI_ORDER_DESCRIPTION_LENGTH));

  const overlongCategoryTitle = 'y'.repeat(helpers.MAX_CONTRACTOR_AI_ORDER_TITLE_LENGTH + 20);
  const capped = helpers.sanitizeContractorOrderForAi({ title: overlongCategoryTitle });
  assert.strictEqual(capped.title.length, helpers.MAX_CONTRACTOR_AI_ORDER_TITLE_LENGTH);
});

test(4, 'sanitizeContractorOrderForAi handles malformed selectedServices safely', () => {
  const result = helpers.sanitizeContractorOrderForAi({
    title: 'Some repairs',
    selectedServices: [
      { name: 'Valid service', description: 'Works fine' },
      null,
      'not-an-object',
      42,
      { description: 'Missing name entirely' },
      { name: '   ', description: 'Blank name after trim' },
      [],
    ],
  });
  assert.strictEqual(result.selectedServices.length, 1);
  assert.strictEqual(result.selectedServices[0].name, 'Valid service');
});

test(5, 'sanitizeContractorOrderForAi supports the proven legacy service fallback', () => {
  const result = helpers.sanitizeContractorOrderForAi({
    title: 'Legacy order',
    selectedServiceId: 'legacy_svc_1',
    selectedServiceName: 'Legacy Drain Cleaning',
    selectedServicePrice: 500,
  });
  assert.strictEqual(result.selectedServices.length, 1);
  assert.strictEqual(result.selectedServices[0].name, 'Legacy Drain Cleaning');
  assert.strictEqual(result.selectedServices[0].description, '');
  assert.ok(!JSON.stringify(result).includes('500'));
});

test(6, 'sanitizeContractorOrderForAi does not mutate input', () => {
  const raw = {
    title: '  Fix leaking pipe  ',
    description: 'desc',
    selectedServices: [{ name: 'Pipe repair', description: 'Fix pipe' }],
  };
  const before = deepClone(raw);
  helpers.sanitizeContractorOrderForAi(raw);
  assert.deepStrictEqual(raw, before);
});

// ── Worker normalization (7-12) ────────────────────────────────────────

test(7, 'normalizeContractorWorker uses canonical specialties array', () => {
  const result = helpers.normalizeContractorWorker(
    { specialties: [' Plumbing ', 'Electrical', 'Plumbing'], specialty: 'Carpentry' },
    'w1',
  );
  assert.deepStrictEqual(result.specialties, ['Plumbing', 'Electrical']);
});

test(8, 'normalizeContractorWorker falls back to legacy scalar specialty', () => {
  const result = helpers.normalizeContractorWorker(
    { specialty: 'Carpentry' },
    'w1',
  );
  assert.deepStrictEqual(result.specialties, ['Carpentry']);
});

test(9, 'normalizeContractorWorker uses workArea, falling back to legacy city', () => {
  const withWorkArea = helpers.normalizeContractorWorker(
    { workArea: 'North Region', city: 'Cairo' },
    'w1',
  );
  assert.strictEqual(withWorkArea.workArea, 'North Region');

  const legacyOnly = helpers.normalizeContractorWorker({ city: 'Cairo' }, 'w1');
  assert.strictEqual(legacyOnly.workArea, 'Cairo');

  const neither = helpers.normalizeContractorWorker({}, 'w1');
  assert.strictEqual(neither.workArea, null);
});

test(10, 'normalizeContractorWorker keeps explicit statuses unchanged (available/busy/offline), trimming whitespace', () => {
  assert.strictEqual(helpers.normalizeContractorWorker({ status: 'available' }, 'w1').status, 'available');
  assert.strictEqual(helpers.normalizeContractorWorker({ status: 'busy' }, 'w1').status, 'busy');
  assert.strictEqual(helpers.normalizeContractorWorker({ status: 'offline' }, 'w1').status, 'offline');
  // Surrounding whitespace is trimmed before matching, consistent with
  // this module's other string-field normalization (asTrimmedString).
  assert.strictEqual(helpers.normalizeContractorWorker({ status: '  busy  ' }, 'w1').status, 'busy');
});

test(11, 'normalizeContractorWorker uses the conservative "offline" fallback for missing/empty/unknown/wrong-type status', () => {
  // Missing status.
  assert.strictEqual(helpers.normalizeContractorWorker({}, 'w1').status, 'offline');
  // Empty string status.
  assert.strictEqual(helpers.normalizeContractorWorker({ status: '' }, 'w1').status, 'offline');
  assert.strictEqual(helpers.normalizeContractorWorker({ status: '   ' }, 'w1').status, 'offline');
  // Unknown string status.
  assert.strictEqual(helpers.normalizeContractorWorker({ status: 'on_leave' }, 'w1').status, 'offline');
  // Wrong-type status.
  assert.strictEqual(helpers.normalizeContractorWorker({ status: 123 }, 'w1').status, 'offline');
  assert.strictEqual(helpers.normalizeContractorWorker({ status: null }, 'w1').status, 'offline');
  assert.strictEqual(helpers.normalizeContractorWorker({ status: {} }, 'w1').status, 'offline');
  assert.strictEqual(helpers.normalizeContractorWorker({ status: ['available'] }, 'w1').status, 'offline');
  // A malformed status must never become "available" without evidence.
  assert.notStrictEqual(helpers.normalizeContractorWorker({ status: 'on_leave' }, 'w1').status, 'available');
});

test(12, 'normalizeContractorWorker never includes PII', () => {
  const raw = {
    name: 'Omar Hassan',
    fullName: 'Omar Hassan',
    phone: '+201234567',
    email: 'omar@example.com',
    imageUrl: 'https://example.com/omar.jpg',
    rating: 4.8,
    skills: ['tiling'],
    description: 'Great worker, pays well',
    workHours: '08:00 – 18:00',
    workStartTime: '08:00',
    workEndTime: '18:00',
    contractorId: 'contractor_1',
    specialties: ['plumbing'],
    workArea: 'North',
    languages: ['ar', 'en'],
    status: 'available',
    currentJobs: 999,
    completedJobs: 40,
  };
  const result = helpers.normalizeContractorWorker(raw, 'w1');
  const allowedKeys = [
    'id', 'contractorId', 'specialties', 'workArea', 'languages',
    'status', 'workStartTime', 'workEndTime',
  ];
  assert.deepStrictEqual(Object.keys(result).sort(), allowedKeys.sort());
  const serialized = JSON.stringify(result);
  for (const value of ['Omar Hassan', '+201234567', 'omar@example.com', 'example.com/omar.jpg', '4.8', 'pays well']) {
    assert.ok(!serialized.includes(value), `PII leaked: ${value}`);
  }
  assert.ok(!Object.prototype.hasOwnProperty.call(result, 'currentJobs'));
});

// ── Workload (13-17) ────────────────────────────────────────────────────

test(13, 'computeContractorWorkerActiveWorkload counts assignedWorkers array', () => {
  const counts = helpers.computeContractorWorkerActiveWorkload([
    { status: 'inProgress', assignedWorkers: [{ id: 'w1' }, { id: 'w2' }] },
  ]);
  assert.strictEqual(counts.get('w1'), 1);
  assert.strictEqual(counts.get('w2'), 1);
});

test(14, 'computeContractorWorkerActiveWorkload supports legacy assignedWorkerId', () => {
  const counts = helpers.computeContractorWorkerActiveWorkload([
    { status: 'inProgress', assignedWorkerId: 'w3' },
  ]);
  assert.strictEqual(counts.get('w3'), 1);
});

test(15, 'computeContractorWorkerActiveWorkload counts multi-worker orders correctly, at most once per order', () => {
  const counts = helpers.computeContractorWorkerActiveWorkload([
    { status: 'inProgress', assignedWorkers: [{ id: 'w1' }, { id: 'w2' }] },
    { status: 'inProgress', assignedWorkers: [{ id: 'w1' }, { id: 'w1' }] }, // duplicate id, same order
  ]);
  assert.strictEqual(counts.get('w1'), 2); // one per distinct order, not 3
  assert.strictEqual(counts.get('w2'), 1);
});

test(16, 'computeContractorWorkerActiveWorkload ignores pending/completed/cancelled orders', () => {
  const counts = helpers.computeContractorWorkerActiveWorkload([
    { status: 'pending', assignedWorkers: [{ id: 'w1' }] },
    { status: 'completed', assignedWorkers: [{ id: 'w1' }] },
    { status: 'cancelled', assignedWorkers: [{ id: 'w1' }] },
  ]);
  assert.strictEqual(counts.get('w1') ?? 0, 0);
});

test(17, 'computeContractorWorkerActiveWorkload never reads a stored currentJobs field', () => {
  const counts = helpers.computeContractorWorkerActiveWorkload([
    { status: 'inProgress', assignedWorkers: [{ id: 'w1' }], currentJobs: 999 },
  ]);
  assert.strictEqual(counts.get('w1'), 1); // derived only from assignment + status
  const normalized = helpers.normalizeContractorWorker({ currentJobs: 999, status: 'available' }, 'w1');
  assert.ok(!Object.prototype.hasOwnProperty.call(normalized, 'currentJobs'));
});

// ── Matching (18-21) ─────────────────────────────────────────────────────

test(18, 'matching category/specialty succeeds', () => {
  const order = helpers.sanitizeContractorOrderForAi({ categoryId: 'plumbing' });
  const worker = helpers.normalizeContractorWorker({ specialties: ['Plumbing'] }, 'w1');
  const requiredKeys = helpers.getContractorOrderRequiredCategoryKeys(order);
  const workerKeys = helpers.getContractorWorkerSpecialtyKeys(worker);
  assert.strictEqual(helpers.contractorWorkerMatchesOrderCategories(workerKeys, requiredKeys), true);
});

test(19, 'no category on the order does not produce a match', () => {
  const order = helpers.sanitizeContractorOrderForAi({ title: 'No category info' });
  const worker = helpers.normalizeContractorWorker({ specialties: ['Plumbing'] }, 'w1');
  const requiredKeys = helpers.getContractorOrderRequiredCategoryKeys(order);
  const workerKeys = helpers.getContractorWorkerSpecialtyKeys(worker);
  assert.strictEqual(requiredKeys.size, 0);
  assert.strictEqual(helpers.contractorWorkerMatchesOrderCategories(workerKeys, requiredKeys), false);
});

test(20, 'empty worker specialties is not a wildcard', () => {
  const order = helpers.sanitizeContractorOrderForAi({ categoryId: 'plumbing' });
  const worker = helpers.normalizeContractorWorker({}, 'w1');
  const requiredKeys = helpers.getContractorOrderRequiredCategoryKeys(order);
  const workerKeys = helpers.getContractorWorkerSpecialtyKeys(worker);
  assert.strictEqual(workerKeys.size, 0);
  assert.strictEqual(helpers.contractorWorkerMatchesOrderCategories(workerKeys, requiredKeys), false);
});

test(21, 'matching normalizes case and whitespace', () => {
  const order = helpers.sanitizeContractorOrderForAi({ categoryId: '  Plumbing  ' });
  const worker = helpers.normalizeContractorWorker({ specialties: ['plumbing'] }, 'w1');
  const requiredKeys = helpers.getContractorOrderRequiredCategoryKeys(order);
  const workerKeys = helpers.getContractorWorkerSpecialtyKeys(worker);
  assert.strictEqual(helpers.contractorWorkerMatchesOrderCategories(workerKeys, requiredKeys), true);
});

// ── Working hours (22-25) ────────────────────────────────────────────────

test(22, 'appointment inside general working hours returns within', () => {
  const worker = { workStartTime: '08:00', workEndTime: '18:00' };
  const appointment = new Date(Date.UTC(2026, 5, 1, 10, 0, 0));
  assert.strictEqual(
    helpers.computeContractorWorkerGeneralWorkingHoursSignal(appointment, worker),
    'within',
  );
});

test(23, 'appointment outside general working hours returns outside', () => {
  const worker = { workStartTime: '08:00', workEndTime: '18:00' };
  const appointment = new Date(Date.UTC(2026, 5, 1, 20, 0, 0));
  assert.strictEqual(
    helpers.computeContractorWorkerGeneralWorkingHoursSignal(appointment, worker),
    'outside',
  );
});

test(24, 'missing/malformed working hours returns unknown', () => {
  const appointment = new Date(Date.UTC(2026, 5, 1, 10, 0, 0));
  assert.strictEqual(
    helpers.computeContractorWorkerGeneralWorkingHoursSignal(appointment, { workStartTime: null, workEndTime: null }),
    'unknown',
  );
  assert.strictEqual(
    helpers.computeContractorWorkerGeneralWorkingHoursSignal(appointment, { workStartTime: '9am', workEndTime: '5pm' }),
    'unknown',
  );
  assert.strictEqual(
    helpers.computeContractorWorkerGeneralWorkingHoursSignal(appointment, { workStartTime: '18:00', workEndTime: '08:00' }),
    'unknown',
  );
});

test(25, 'the working-hours result is never described as confirmed availability', () => {
  const worker = { workStartTime: '08:00', workEndTime: '18:00' };
  const allowedValues = new Set(['within', 'outside', 'unknown']);
  const samples = [
    new Date(Date.UTC(2026, 5, 1, 6, 0, 0)),
    new Date(Date.UTC(2026, 5, 1, 12, 0, 0)),
    new Date(Date.UTC(2026, 5, 1, 23, 0, 0)),
  ];
  for (const sample of samples) {
    const signal = helpers.computeContractorWorkerGeneralWorkingHoursSignal(sample, worker);
    assert.ok(allowedValues.has(signal), `unexpected signal value: ${signal}`);
    assert.notStrictEqual(signal, true);
    assert.notStrictEqual(signal, 'confirmed');
    assert.notStrictEqual(signal, 'available');
  }
});

// ── Proximity (26-28) ────────────────────────────────────────────────────

test(26, 'same-time appointments trigger the proximity warning', () => {
  const t = new Date(Date.UTC(2026, 5, 1, 9, 0, 0));
  assert.strictEqual(helpers.areContractorOrdersScheduleProximate(t, new Date(t.getTime())), true);
});

test(27, 'exactly 30 minutes apart triggers the proximity warning', () => {
  const a = new Date(Date.UTC(2026, 5, 1, 9, 0, 0));
  const b = new Date(a.getTime() + helpers.kContractorAiScheduleProximityMinutes * 60 * 1000);
  assert.strictEqual(helpers.areContractorOrdersScheduleProximate(a, b), true);
});

test(28, 'more than 30 minutes apart does not trigger the proximity warning', () => {
  const a = new Date(Date.UTC(2026, 5, 1, 9, 0, 0));
  const b = new Date(a.getTime() + helpers.kContractorAiScheduleProximityMinutes * 60 * 1000 + 1);
  assert.strictEqual(helpers.areContractorOrdersScheduleProximate(a, b), false);
});

// ── Ranking (29-35) ──────────────────────────────────────────────────────

function baseRankingInput(overrides) {
  return Object.assign(
    {
      workerId: 'w1',
      isAlreadyAssigned: false,
      specialtyMatches: false,
      status: 'available',
      activeWorkload: 0,
      hasProximityWarning: false,
      workingHoursSignal: 'within',
    },
    overrides,
  );
}

test(29, 'an already-assigned worker wins the ranking', () => {
  const assigned = baseRankingInput({ workerId: 'assigned', isAlreadyAssigned: true });
  const notAssigned = baseRankingInput({ workerId: 'not_assigned', isAlreadyAssigned: false });
  const ranked = helpers.rankContractorWorkers([notAssigned, assigned]);
  assert.strictEqual(ranked[0].workerId, 'assigned');
});

test(30, 'a specialty match wins the ranking (all else equal)', () => {
  const matches = baseRankingInput({ workerId: 'matches', specialtyMatches: true });
  const noMatch = baseRankingInput({ workerId: 'no_match', specialtyMatches: false });
  const ranked = helpers.rankContractorWorkers([noMatch, matches]);
  assert.strictEqual(ranked[0].workerId, 'matches');
});

test(31, 'available beats busy beats offline', () => {
  const offline = baseRankingInput({ workerId: 'offline', status: 'offline' });
  const busy = baseRankingInput({ workerId: 'busy', status: 'busy' });
  const available = baseRankingInput({ workerId: 'available', status: 'available' });
  const ranked = helpers.rankContractorWorkers([offline, busy, available]);
  assert.deepStrictEqual(ranked.map((r) => r.workerId), ['available', 'busy', 'offline']);
});

test(32, 'lower active workload wins (all else equal)', () => {
  const busyWorker = baseRankingInput({ workerId: 'busier', activeWorkload: 3 });
  const freeWorker = baseRankingInput({ workerId: 'freer', activeWorkload: 1 });
  const ranked = helpers.rankContractorWorkers([busyWorker, freeWorker]);
  assert.strictEqual(ranked[0].workerId, 'freer');
});

test(33, 'no proximity warning wins (all else equal)', () => {
  const warned = baseRankingInput({ workerId: 'warned', hasProximityWarning: true });
  const clear = baseRankingInput({ workerId: 'clear', hasProximityWarning: false });
  const ranked = helpers.rankContractorWorkers([warned, clear]);
  assert.strictEqual(ranked[0].workerId, 'clear');
});

test(34, 'working-hours signal ordering is stable (within < unknown < outside)', () => {
  const outside = baseRankingInput({ workerId: 'outside', workingHoursSignal: 'outside' });
  const unknown = baseRankingInput({ workerId: 'unknown', workingHoursSignal: 'unknown' });
  const within = baseRankingInput({ workerId: 'within', workingHoursSignal: 'within' });
  const ranked = helpers.rankContractorWorkers([outside, unknown, within]);
  assert.deepStrictEqual(ranked.map((r) => r.workerId), ['within', 'unknown', 'outside']);
});

test(35, 'worker document id is the final stable tie-breaker', () => {
  const b = baseRankingInput({ workerId: 'b_worker' });
  const a = baseRankingInput({ workerId: 'a_worker' });
  const c = baseRankingInput({ workerId: 'c_worker' });
  const ranked = helpers.rankContractorWorkers([b, c, a]);
  assert.deepStrictEqual(ranked.map((r) => r.workerId), ['a_worker', 'b_worker', 'c_worker']);
});

test(36, 'a malformed-status worker normalizes to offline and ranks below available and busy', () => {
  const malformedWorker = helpers.normalizeContractorWorker({ status: 'on_leave' }, 'malformed');
  assert.strictEqual(malformedWorker.status, 'offline');

  const available = baseRankingInput({ workerId: 'available', status: 'available' });
  const busy = baseRankingInput({ workerId: 'busy', status: 'busy' });
  const explicitOffline = baseRankingInput({ workerId: 'explicit_offline', status: 'offline' });
  const malformed = baseRankingInput({ workerId: 'malformed', status: malformedWorker.status });

  const ranked = helpers.rankContractorWorkers([malformed, available, busy, explicitOffline]);
  assert.deepStrictEqual(
    ranked.map((r) => r.workerId),
    ['available', 'busy', 'explicit_offline', 'malformed'],
  );
});

// ── Aggregate privacy (37-40) ────────────────────────────────────────────

test(37, 'buildAnonymousContractorWorkerAggregate produces correct counts', () => {
  const inputs = [
    baseRankingInput({ workerId: 'w1', status: 'available', specialtyMatches: true, isAlreadyAssigned: true, activeWorkload: 0, hasProximityWarning: false, workingHoursSignal: 'within' }),
    baseRankingInput({ workerId: 'w2', status: 'busy', specialtyMatches: true, isAlreadyAssigned: false, activeWorkload: 2, hasProximityWarning: true, workingHoursSignal: 'unknown' }),
    baseRankingInput({ workerId: 'w3', status: 'offline', specialtyMatches: false, isAlreadyAssigned: false, activeWorkload: 0, hasProximityWarning: false, workingHoursSignal: 'outside' }),
  ];
  const aggregate = helpers.buildAnonymousContractorWorkerAggregate(inputs);
  assert.strictEqual(aggregate.totalOwnedWorkers, 3);
  assert.strictEqual(aggregate.availableStatusCount, 1);
  assert.strictEqual(aggregate.busyStatusCount, 1);
  assert.strictEqual(aggregate.offlineStatusCount, 1);
  assert.strictEqual(aggregate.specialtyMatchCount, 2);
  assert.strictEqual(aggregate.alreadyAssignedCount, 1);
  assert.strictEqual(aggregate.zeroActiveJobCount, 2);
  assert.strictEqual(aggregate.workersWithProximityWarningCount, 1);
  assert.strictEqual(aggregate.withinGeneralWorkingHoursCount, 1);
  assert.strictEqual(aggregate.unknownGeneralWorkingHoursCount, 1);
});

test(38, 'the aggregate never contains a worker id or name', () => {
  const inputs = [
    baseRankingInput({ workerId: 'super_secret_worker_id_1' }),
    baseRankingInput({ workerId: 'super_secret_worker_id_2' }),
  ];
  const aggregate = helpers.buildAnonymousContractorWorkerAggregate(inputs);
  const serialized = JSON.stringify(aggregate);
  assert.ok(!serialized.includes('super_secret_worker_id'));
  const allowedKeys = [
    'totalOwnedWorkers', 'availableStatusCount', 'busyStatusCount',
    'offlineStatusCount', 'specialtyMatchCount', 'alreadyAssignedCount',
    'zeroActiveJobCount', 'workersWithProximityWarningCount',
    'withinGeneralWorkingHoursCount', 'unknownGeneralWorkingHoursCount',
  ];
  assert.deepStrictEqual(Object.keys(aggregate).sort(), allowedKeys.sort());
});

test(39, 'the aggregate never contains customer or order identity', () => {
  const inputs = [baseRankingInput({ workerId: 'w1' })];
  const aggregate = helpers.buildAnonymousContractorWorkerAggregate(inputs);
  for (const forbiddenKey of ['orderId', 'customerId', 'customerName', 'orderTitle']) {
    assert.ok(!Object.prototype.hasOwnProperty.call(aggregate, forbiddenKey));
  }
});

test(40, 'buildAnonymousContractorWorkerAggregate and rankContractorWorkers do not mutate inputs', () => {
  const inputs = [
    baseRankingInput({ workerId: 'w2' }),
    baseRankingInput({ workerId: 'w1', isAlreadyAssigned: true }),
  ];
  const before = deepClone(inputs);
  helpers.buildAnonymousContractorWorkerAggregate(inputs);
  helpers.rankContractorWorkers(inputs);
  assert.deepStrictEqual(inputs, before);
});

test(41, 'a malformed-status worker contributes to offlineStatusCount, not availableStatusCount', () => {
  const malformedWorker = helpers.normalizeContractorWorker({ status: 'on_leave' }, 'malformed');
  const inputs = [
    baseRankingInput({ workerId: 'malformed', status: malformedWorker.status }),
    baseRankingInput({ workerId: 'available', status: 'available' }),
  ];
  const aggregate = helpers.buildAnonymousContractorWorkerAggregate(inputs);
  assert.strictEqual(aggregate.offlineStatusCount, 1);
  assert.strictEqual(aggregate.availableStatusCount, 1);
});

// ── Summary ──────────────────────────────────────────────────────────────

console.log('');
console.log('─── Summary ───────────────────────────────────────────');
console.log(`PASS: ${passCount}  FAIL: ${failCount}  TOTAL: ${passCount + failCount}`);
if (failures.length > 0) {
  console.log('Failures:');
  for (const f of failures) {
    console.log(`  #${f.id} ${f.description}: ${f.err.stack || f.err.message}`);
  }
}
process.exit(failCount > 0 ? 1 : 0);
