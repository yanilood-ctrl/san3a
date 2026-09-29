// Contractor AI Crew & Order Planner — isolated, pure helper module.
//
// This file contains ONLY deterministic, side-effect-free TypeScript
// functions. It must never be imported by functions/src/index.ts and must
// never be exported as a Cloud Function. It has no dependency on
// firebase-admin, firebase-functions, any Gemini/GenAI package, or any
// network API — every function here accepts plain data and returns plain
// data. A later step will add a private Firestore loader (in a separate
// file/section) that reads real `orders`/`contractor_workers` documents,
// converts Firestore Timestamps to `Date`, and passes the resulting plain
// objects into these helpers. No such loader, callable, or Gemini call
// exists yet.
//
// Every helper here is defensive: malformed/missing input never throws —
// it degrades to a safe default (empty string, empty array, "unknown",
// etc.), mirroring the same defensive-parsing convention already used by
// OrderModel.fromMap / WorkerModel.fromFirestore on the Flutter side and by
// the Professional AI sanitizers in functions/src/index.ts.

// ─── Shared primitive helpers ──────────────────────────────────────────────

/**
 * Narrows a value to a non-null, non-array plain object.
 * @param {unknown} value The value to check.
 * @return {boolean} Whether `value` is a plain object.
 */
function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/**
 * Returns a trimmed string, or "" for anything that is not a string.
 * @param {unknown} value The raw value.
 * @return {string} The trimmed string, or "".
 */
function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Truncates a string to at most `maxLength` characters.
 * @param {string} value The already-trimmed string.
 * @param {number} maxLength The maximum allowed length.
 * @return {string} The possibly-truncated string.
 */
function clampString(value: string, maxLength: number): string {
  return value.length > maxLength ? value.slice(0, maxLength) : value;
}

/**
 * Defensively parses a raw value into a deduplicated list of non-empty
 * trimmed strings, dropping any non-string entry instead of throwing.
 * @param {unknown} value The raw (expected) array value.
 * @return {string[]} The normalized, deduplicated string list.
 */
function asTrimmedStringSet(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const entry of value) {
    if (typeof entry !== "string") continue;
    const trimmed = entry.trim();
    if (trimmed.length === 0 || seen.has(trimmed)) continue;
    seen.add(trimmed);
    result.push(trimmed);
  }
  return result;
}

// ─── 1. Order sanitization ─────────────────────────────────────────────────
// Field-length caps are independently defined for this isolated feature —
// never imported from the Professional/Customer AI sections of index.ts —
// following this codebase's established convention of each AI feature
// owning a private copy of every constant it needs.

export const MAX_CONTRACTOR_AI_ORDER_TITLE_LENGTH = 120;
export const MAX_CONTRACTOR_AI_ORDER_DESCRIPTION_LENGTH = 1200;
export const MAX_CONTRACTOR_AI_CATEGORY_ID_LENGTH = 200;
export const MAX_CONTRACTOR_AI_CATEGORY_NAME_KEY_LENGTH = 200;
export const MAX_CONTRACTOR_AI_SERVICE_NAME_LENGTH = 300;
export const MAX_CONTRACTOR_AI_SERVICE_DESCRIPTION_LENGTH = 300;
export const MAX_CONTRACTOR_AI_SELECTED_SERVICES = 50;

export interface SanitizedContractorOrderService {
  name: string;
  description: string;
  categoryId?: string;
}

export interface SanitizedContractorOrderForAi {
  title: string;
  description: string;
  categoryId?: string;
  categoryNameKey?: string;
  priority: "normal" | "urgent";
  selectedServices: SanitizedContractorOrderService[];
}

/**
 * Sanitizes one raw `selectedServices` array entry. Returns null for any
 * entry that is not an object or has no usable `name`, so a malformed
 * array never crashes the caller — it is simply skipped.
 * @param {unknown} rawService One raw `selectedServices` array entry.
 * @return {SanitizedContractorOrderService | null} The sanitized entry, or
 * null if the entry is unusable.
 */
function sanitizeContractorOrderSelectedService(
  rawService: unknown,
): SanitizedContractorOrderService | null {
  if (!isPlainObject(rawService)) return null;
  const name = clampString(
    asTrimmedString(rawService.name),
    MAX_CONTRACTOR_AI_SERVICE_NAME_LENGTH,
  );
  if (name.length === 0) return null;
  const description = clampString(
    asTrimmedString(rawService.description),
    MAX_CONTRACTOR_AI_SERVICE_DESCRIPTION_LENGTH,
  );
  const categoryId = clampString(
    asTrimmedString(rawService.categoryId),
    MAX_CONTRACTOR_AI_CATEGORY_ID_LENGTH,
  );
  const service: SanitizedContractorOrderService = {name, description};
  if (categoryId.length > 0) service.categoryId = categoryId;
  return service;
}

/**
 * Produces a minimal, allow-listed projection of a raw `orders/{id}`
 * document safe to eventually send to Gemini. Never copies unknown
 * fields and never includes order id, provider/customer identity,
 * contact info, prices, images, assigned-worker data, Firestore paths,
 * rate-limit values, or any timestamp. Never mutates `rawOrder`.
 * @param {unknown} rawOrder The raw Firestore `orders/{id}` document data.
 * @return {SanitizedContractorOrderForAi} The sanitized projection.
 */
export function sanitizeContractorOrderForAi(
  rawOrder: unknown,
): SanitizedContractorOrderForAi {
  const source = isPlainObject(rawOrder) ? rawOrder : {};

  const title = clampString(
    asTrimmedString(source.title),
    MAX_CONTRACTOR_AI_ORDER_TITLE_LENGTH,
  );
  const description = clampString(
    asTrimmedString(source.description),
    MAX_CONTRACTOR_AI_ORDER_DESCRIPTION_LENGTH,
  );
  const categoryId = clampString(
    asTrimmedString(source.categoryId),
    MAX_CONTRACTOR_AI_CATEGORY_ID_LENGTH,
  );
  const categoryNameKey = clampString(
    asTrimmedString(source.categoryNameKey),
    MAX_CONTRACTOR_AI_CATEGORY_NAME_KEY_LENGTH,
  );
  const priority: "normal" | "urgent" =
    source.priority === "urgent" ? "urgent" : "normal";

  const rawSelectedServices = Array.isArray(source.selectedServices) ?
    source.selectedServices :
    [];
  const selectedServices: SanitizedContractorOrderService[] = [];
  for (const rawService of rawSelectedServices) {
    if (selectedServices.length >= MAX_CONTRACTOR_AI_SELECTED_SERVICES) break;
    const sanitized = sanitizeContractorOrderSelectedService(rawService);
    if (sanitized) selectedServices.push(sanitized);
  }

  // Legacy single-service fallback — only used when the modern
  // `selectedServices` list produced nothing usable. Mirrors OrderModel's
  // own top-level legacy `selectedServiceName` scalar field. Never reads
  // `selectedServicePrice`.
  if (selectedServices.length === 0) {
    const legacyName = clampString(
      asTrimmedString(source.selectedServiceName),
      MAX_CONTRACTOR_AI_SERVICE_NAME_LENGTH,
    );
    if (legacyName.length > 0) {
      selectedServices.push({name: legacyName, description: ""});
    }
  }

  const result: SanitizedContractorOrderForAi = {
    title,
    description,
    priority,
    selectedServices,
  };
  if (categoryId.length > 0) result.categoryId = categoryId;
  if (categoryNameKey.length > 0) result.categoryNameKey = categoryNameKey;
  return result;
}

// ─── 2. Worker normalization ───────────────────────────────────────────────

export type ContractorWorkerStatus = "available" | "busy" | "offline";

const CONTRACTOR_WORKER_STATUS_VALUES: ReadonlySet<string> = new Set([
  "available",
  "busy",
  "offline",
]);

const CONTRACTOR_WORKER_TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;

export interface NormalizedContractorWorker {
  id: string;
  contractorId: string | null;
  specialties: string[];
  workArea: string | null;
  languages: string[];
  status: ContractorWorkerStatus;
  workStartTime: string | null;
  workEndTime: string | null;
}

/**
 * Normalizes a raw worker `status` value. Missing, empty, unknown, or
 * wrong-type values fall back to "offline" — a deliberately conservative
 * default for this advisory ranking feature, so a worker can never be
 * ranked or counted as available without positive evidence. This is an
 * intentional divergence from the legacy Flutter
 * `WorkerModel.fromFirestore`'s own `_statusFromString`, which defaults
 * unknown values to "available"; that legacy behavior is left unchanged
 * on the Flutter side and is not reused here. Trims surrounding
 * whitespace before matching, consistent with this module's other
 * string-field normalization.
 * @param {unknown} value The raw `status` field.
 * @return {ContractorWorkerStatus} The normalized status.
 */
function normalizeContractorWorkerStatus(
  value: unknown,
): ContractorWorkerStatus {
  const trimmed = asTrimmedString(value);
  return CONTRACTOR_WORKER_STATUS_VALUES.has(trimmed) ?
    (trimmed as ContractorWorkerStatus) :
    "offline";
}

/**
 * Validates a raw stored working-hours time string against the proven
 * "HH:mm" (24-hour, zero-padded) format written by WorkingHoursField.
 * Returns null for anything else instead of guessing.
 * @param {unknown} value The raw `workStartTime`/`workEndTime` field.
 * @return {string | null} The validated "HH:mm" string, or null.
 */
function parseStoredContractorWorkerTime(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return CONTRACTOR_WORKER_TIME_PATTERN.test(trimmed) ? trimmed : null;
}

/**
 * Normalizes one raw `contractor_workers/{id}` document into the minimal
 * internal shape this feature is allowed to use. Never includes worker
 * name, phone, email, image, rating, or any other PII/contact field —
 * those are simply never read. Ignores the stored `currentJobs` field
 * entirely (see computeContractorWorkerActiveWorkload for why).
 * @param {unknown} rawData The raw Firestore `contractor_workers`
 * document data.
 * @param {string} id The Firestore document id of the worker.
 * @return {NormalizedContractorWorker} The normalized internal worker.
 */
export function normalizeContractorWorker(
  rawData: unknown,
  id: string,
): NormalizedContractorWorker {
  const source = isPlainObject(rawData) ? rawData : {};

  const canonicalSpecialties = asTrimmedStringSet(source.specialties);
  const legacySpecialty = asTrimmedString(source.specialty);
  const specialties = canonicalSpecialties.length > 0 ?
    canonicalSpecialties :
    (legacySpecialty.length > 0 ? [legacySpecialty] : []);

  const structuredWorkArea = asTrimmedString(source.workArea);
  const legacyCity = asTrimmedString(source.city);
  const workArea = structuredWorkArea.length > 0 ?
    structuredWorkArea :
    (legacyCity.length > 0 ? legacyCity : null);

  const trimmedContractorId = asTrimmedString(source.contractorId);

  return {
    id: asTrimmedString(id),
    contractorId: trimmedContractorId.length > 0 ? trimmedContractorId : null,
    specialties,
    workArea,
    languages: asTrimmedStringSet(source.languages),
    status: normalizeContractorWorkerStatus(source.status),
    workStartTime: parseStoredContractorWorkerTime(source.workStartTime),
    workEndTime: parseStoredContractorWorkerTime(source.workEndTime),
  };
}

// ─── 3. Real workload calculation ──────────────────────────────────────────

/**
 * Extracts the set of assigned worker ids from one raw order, preferring
 * the modern `assignedWorkers[].id` array and falling back to the legacy
 * scalar `assignedWorkerId` only when that array is absent/empty — the
 * same fallback rule already used by the Flutter
 * `_isAssignedToWorker`/worker-profile workload display.
 * @param {Record<string, unknown>} rawOrder One raw order document.
 * @return {Set<string>} The deduplicated set of assigned worker ids.
 */
function extractContractorOrderAssignedWorkerIds(
  rawOrder: Record<string, unknown>,
): Set<string> {
  const ids = new Set<string>();
  const assignedWorkers = rawOrder.assignedWorkers;
  if (Array.isArray(assignedWorkers) && assignedWorkers.length > 0) {
    for (const entry of assignedWorkers) {
      if (!isPlainObject(entry)) continue;
      const workerId = asTrimmedString(entry.id);
      if (workerId.length > 0) ids.add(workerId);
    }
  } else {
    const legacyWorkerId = asTrimmedString(rawOrder.assignedWorkerId);
    if (legacyWorkerId.length > 0) ids.add(legacyWorkerId);
  }
  return ids;
}

/**
 * Computes each worker's real active (`inProgress`) workload from a list
 * of the contractor's own raw orders. Pending/completed/cancelled orders
 * are ignored. Each order counts at most once per worker even if a
 * malformed document lists the same worker id twice. The stored
 * `currentJobs` field on a worker document is never read anywhere — it is
 * not trustworthy (WorkerModel.fromFirestore always hardcodes it to 0).
 * @param {unknown} rawOrders The contractor's raw `orders` array.
 * @return {Map<string, number>} Active workload count keyed by worker id.
 */
export function computeContractorWorkerActiveWorkload(
  rawOrders: unknown,
): Map<string, number> {
  const counts = new Map<string, number>();
  if (!Array.isArray(rawOrders)) return counts;
  for (const rawOrder of rawOrders) {
    if (!isPlainObject(rawOrder)) continue;
    if (asTrimmedString(rawOrder.status) !== "inProgress") continue;
    const workerIds = extractContractorOrderAssignedWorkerIds(rawOrder);
    for (const workerId of workerIds) {
      counts.set(workerId, (counts.get(workerId) ?? 0) + 1);
    }
  }
  return counts;
}

// ─── 4. Specialty/category matching ────────────────────────────────────────

/**
 * Normalizes a raw category/specialty value into a lowercase, trimmed
 * matching key, or null when it is not a usable non-empty string.
 * @param {unknown} value The raw category id/nameKey/specialty value.
 * @return {string | null} The normalized key, or null.
 */
export function normalizeContractorMatchKey(value: unknown): string | null {
  const trimmed = asTrimmedString(value).toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Computes the normalized set of category keys a sanitized order requires,
 * preferring each selected service's own `categoryId` and falling back to
 * the order-level `categoryId`/`categoryNameKey` only when no service
 * supplied one — mirroring `_orderRequiredCategoryKeys` in
 * contractor_home_screen.dart. Never guesses from title/description.
 * @param {SanitizedContractorOrderForAi} order The sanitized order.
 * @return {Set<string>} The normalized set of required category keys.
 */
export function getContractorOrderRequiredCategoryKeys(
  order: SanitizedContractorOrderForAi,
): Set<string> {
  const keys = new Set<string>();
  for (const service of order.selectedServices) {
    const key = normalizeContractorMatchKey(service.categoryId);
    if (key) keys.add(key);
  }
  if (keys.size === 0) {
    const categoryIdKey = normalizeContractorMatchKey(order.categoryId);
    if (categoryIdKey) keys.add(categoryIdKey);
    const categoryNameKeyKey = normalizeContractorMatchKey(
      order.categoryNameKey,
    );
    if (categoryNameKeyKey) keys.add(categoryNameKeyKey);
  }
  return keys;
}

/**
 * Computes a normalized worker's specialty matching keys.
 * @param {NormalizedContractorWorker} worker The normalized worker.
 * @return {Set<string>} The normalized set of specialty keys.
 */
export function getContractorWorkerSpecialtyKeys(
  worker: NormalizedContractorWorker,
): Set<string> {
  const keys = new Set<string>();
  for (const specialty of worker.specialties) {
    const key = normalizeContractorMatchKey(specialty);
    if (key) keys.add(key);
  }
  return keys;
}

/**
 * Decides whether a worker's specialties satisfy an order's required
 * category keys. Deliberately stricter than the Flutter assignment
 * sheet's own convenience filter: an order with no usable category
 * information never produces a fake match, and a worker with no
 * specialties is never treated as a wildcard match. This divergence is
 * intentional for AI-facing planning data, where overstated certainty is
 * unsafe.
 * @param {Set<string>} workerKeys The worker's normalized specialty keys.
 * @param {Set<string>} requiredKeys The order's normalized required keys.
 * @return {boolean} Whether at least one key is shared.
 */
export function contractorWorkerMatchesOrderCategories(
  workerKeys: Set<string>,
  requiredKeys: Set<string>,
): boolean {
  if (requiredKeys.size === 0 || workerKeys.size === 0) return false;
  for (const key of workerKeys) {
    if (requiredKeys.has(key)) return true;
  }
  return false;
}

// ─── 5. Worker status ranking ──────────────────────────────────────────────

/**
 * Maps a worker status to its deterministic ranking order: available
 * workers first, then busy, then offline. This is real stored data, not a
 * confirmed date-specific availability result — busy/offline workers are
 * never removed by this helper, only ranked lower.
 * @param {ContractorWorkerStatus} status The normalized worker status.
 * @return {number} The ranking weight (lower sorts first).
 */
export function contractorWorkerStatusRank(
  status: ContractorWorkerStatus,
): number {
  switch (status) {
  case "available":
    return 0;
  case "busy":
    return 1;
  case "offline":
    return 2;
  }
}

// ─── 6. General working-hours signal ───────────────────────────────────────

export type ContractorWorkerGeneralWorkingHoursSignal =
  | "within"
  | "outside"
  | "unknown";

/**
 * Computes a conservative signal for whether an order's `serviceDate`
 * clock time falls inside a worker's stored general working-hours range.
 * This only compares time-of-day against a non-date-specific weekly
 * range — it is never a claim that the worker is actually available on
 * that specific date, and malformed/missing hours always return
 * "unknown" rather than guessing. No breaks, shifts, service duration, or
 * travel time are modeled.
 * @param {Date} appointmentDate The order's `serviceDate`, already
 * converted to a `Date` by the caller.
 * @param {Pick<NormalizedContractorWorker, "workStartTime" | "workEndTime">}
 * worker The normalized worker's stored working-hours fields.
 * @return {ContractorWorkerGeneralWorkingHoursSignal} The conservative
 * signal.
 */
export function computeContractorWorkerGeneralWorkingHoursSignal(
  appointmentDate: Date,
  worker: Pick<NormalizedContractorWorker, "workStartTime" | "workEndTime">,
): ContractorWorkerGeneralWorkingHoursSignal {
  if (
    !(appointmentDate instanceof Date) ||
    Number.isNaN(appointmentDate.getTime())
  ) {
    return "unknown";
  }
  const start = parseStoredContractorWorkerTime(worker.workStartTime);
  const end = parseStoredContractorWorkerTime(worker.workEndTime);
  if (start === null || end === null) return "unknown";

  const startMinutes = toMinutesSinceMidnight(start);
  const endMinutes = toMinutesSinceMidnight(end);
  if (startMinutes === null || endMinutes === null) return "unknown";
  if (startMinutes >= endMinutes) return "unknown";

  const appointmentMinutes =
    appointmentDate.getUTCHours() * 60 + appointmentDate.getUTCMinutes();
  const isWithinRange =
    appointmentMinutes >= startMinutes && appointmentMinutes <= endMinutes;
  return isWithinRange ? "within" : "outside";
}

/**
 * Converts an already-validated "HH:mm" string to minutes since midnight.
 * @param {string} value A string already matched against the proven
 * "HH:mm" pattern.
 * @return {number | null} Minutes since midnight, or null if unparsable.
 */
function toMinutesSinceMidnight(value: string): number | null {
  const match = CONTRACTOR_WORKER_TIME_PATTERN.exec(value);
  if (!match) return null;
  return Number(match[1]) * 60 + Number(match[2]);
}

// ─── 7. Schedule proximity ─────────────────────────────────────────────────

/** Proximity threshold, in minutes, for a schedule-proximity warning. */
export const kContractorAiScheduleProximityMinutes = 30;

/**
 * Decides whether two real order `serviceDate` values are close enough to
 * warrant a proximity warning. Compares the precise millisecond
 * difference (never a truncated "minutes" difference), so exactly 30
 * minutes apart still triggers the warning. This is only ever a
 * scheduling proximity warning for the contractor to review manually —
 * the project stores no service-duration or travel-time data, so this
 * must never be described as a confirmed conflict.
 * @param {Date} a One order's `serviceDate`.
 * @param {Date} b Another order's `serviceDate`.
 * @return {boolean} Whether the two times are within the threshold.
 */
export function areContractorOrdersScheduleProximate(
  a: Date,
  b: Date,
): boolean {
  if (
    !(a instanceof Date) || !(b instanceof Date) ||
    Number.isNaN(a.getTime()) || Number.isNaN(b.getTime())
  ) {
    return false;
  }
  const diffMs = Math.abs(a.getTime() - b.getTime());
  return diffMs <= kContractorAiScheduleProximityMinutes * 60 * 1000;
}

// ─── 8. Deterministic worker ranking ───────────────────────────────────────

export interface ContractorWorkerRankingInput {
  workerId: string;
  isAlreadyAssigned: boolean;
  specialtyMatches: boolean;
  status: ContractorWorkerStatus;
  activeWorkload: number;
  hasProximityWarning: boolean;
  workingHoursSignal: ContractorWorkerGeneralWorkingHoursSignal;
}

/**
 * Maps a working-hours signal to its deterministic ranking order: within
 * the stored hours first, then unknown, then outside.
 * @param {ContractorWorkerGeneralWorkingHoursSignal} signal The signal.
 * @return {number} The ranking weight (lower sorts first).
 */
function contractorWorkingHoursSignalRank(
  signal: ContractorWorkerGeneralWorkingHoursSignal,
): number {
  switch (signal) {
  case "within":
    return 0;
  case "unknown":
    return 1;
  case "outside":
    return 2;
  }
}

/**
 * Stable comparator implementing the exact deterministic ranking order:
 * already-assigned first, then specialty match, then worker status
 * (available/busy/offline), then lower active workload, then no
 * proximity warning, then the general working-hours signal, and finally
 * the worker document id as a lexicographic tie-breaker. Never uses
 * worker names, ratings, prices, wages, or any random ordering.
 * @param {ContractorWorkerRankingInput} a One worker's ranking input.
 * @param {ContractorWorkerRankingInput} b Another worker's ranking input.
 * @return {number} A negative, zero, or positive comparator result.
 */
export function compareContractorWorkerRankingInputs(
  a: ContractorWorkerRankingInput,
  b: ContractorWorkerRankingInput,
): number {
  if (a.isAlreadyAssigned !== b.isAlreadyAssigned) {
    return a.isAlreadyAssigned ? -1 : 1;
  }
  if (a.specialtyMatches !== b.specialtyMatches) {
    return a.specialtyMatches ? -1 : 1;
  }
  const statusDiff =
    contractorWorkerStatusRank(a.status) - contractorWorkerStatusRank(b.status);
  if (statusDiff !== 0) return statusDiff;

  const workloadDiff = a.activeWorkload - b.activeWorkload;
  if (workloadDiff !== 0) return workloadDiff;

  if (a.hasProximityWarning !== b.hasProximityWarning) {
    return a.hasProximityWarning ? 1 : -1;
  }

  const hoursDiff =
    contractorWorkingHoursSignalRank(a.workingHoursSignal) -
    contractorWorkingHoursSignalRank(b.workingHoursSignal);
  if (hoursDiff !== 0) return hoursDiff;

  if (a.workerId < b.workerId) return -1;
  if (a.workerId > b.workerId) return 1;
  return 0;
}

/**
 * Returns a new, stably-sorted array of worker ranking inputs. Never
 * mutates the input array.
 * @param {ContractorWorkerRankingInput[]} inputs The unranked worker
 * ranking inputs.
 * @return {ContractorWorkerRankingInput[]} A new, ranked array.
 */
export function rankContractorWorkers(
  inputs: readonly ContractorWorkerRankingInput[],
): ContractorWorkerRankingInput[] {
  return [...inputs].sort(compareContractorWorkerRankingInputs);
}

// ─── 9. Anonymous aggregate builder ────────────────────────────────────────

export interface ContractorAiWorkerAggregate {
  totalOwnedWorkers: number;
  availableStatusCount: number;
  busyStatusCount: number;
  offlineStatusCount: number;
  specialtyMatchCount: number;
  alreadyAssignedCount: number;
  zeroActiveJobCount: number;
  workersWithProximityWarningCount: number;
  withinGeneralWorkingHoursCount: number;
  unknownGeneralWorkingHoursCount: number;
}

/**
 * Builds a brand-new, allow-listed anonymous aggregate object — counts
 * only — safe for future Gemini input. Never includes a worker id,
 * worker name, contact information, any worker-level object, an order
 * id, or customer information; only the count fields listed on
 * `ContractorAiWorkerAggregate` are ever produced. Never mutates `inputs`.
 * @param {ContractorWorkerRankingInput[]} inputs The deterministic
 * per-worker ranking inputs to summarize.
 * @return {ContractorAiWorkerAggregate} The anonymous aggregate.
 */
export function buildAnonymousContractorWorkerAggregate(
  inputs: readonly ContractorWorkerRankingInput[],
): ContractorAiWorkerAggregate {
  const aggregate: ContractorAiWorkerAggregate = {
    totalOwnedWorkers: inputs.length,
    availableStatusCount: 0,
    busyStatusCount: 0,
    offlineStatusCount: 0,
    specialtyMatchCount: 0,
    alreadyAssignedCount: 0,
    zeroActiveJobCount: 0,
    workersWithProximityWarningCount: 0,
    withinGeneralWorkingHoursCount: 0,
    unknownGeneralWorkingHoursCount: 0,
  };

  for (const input of inputs) {
    if (input.status === "available") aggregate.availableStatusCount++;
    else if (input.status === "busy") aggregate.busyStatusCount++;
    else aggregate.offlineStatusCount++;

    if (input.specialtyMatches) aggregate.specialtyMatchCount++;
    if (input.isAlreadyAssigned) aggregate.alreadyAssignedCount++;
    if (input.activeWorkload === 0) aggregate.zeroActiveJobCount++;
    if (input.hasProximityWarning) {
      aggregate.workersWithProximityWarningCount++;
    }
    if (input.workingHoursSignal === "within") {
      aggregate.withinGeneralWorkingHoursCount++;
    }
    if (input.workingHoursSignal === "unknown") {
      aggregate.unknownGeneralWorkingHoursCount++;
    }
  }

  return aggregate;
}
