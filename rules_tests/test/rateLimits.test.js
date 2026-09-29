'use strict';

// Field shapes proven from Rules Phase 5D1 investigation —
// checkAndConsumeAiRateLimit() / checkAndConsumeTranslationRateLimit() /
// checkAndConsumeProfessionalAiRateLimit() /
// checkAndConsumeContractorAiRateLimit() (functions/src/index.ts). All
// four collections (`ai_rate_limits`, `translation_rate_limits`,
// `professional_ai_rate_limits`, `contractor_ai_rate_limits`) share the
// identical two-document shape (`global` + `users_{uid}`,
// dayKey/dailyCount/lastRequestAt/updatedAt) and are read/written
// exclusively by those Cloud Functions via the Admin SDK, which bypasses
// these Rules entirely — no client of any role, including Admin, has any
// legitimate reason to read or write any of them. This file proves that
// with the Firestore emulator (client SDK only); it says nothing about —
// and cannot affect — Admin SDK access.

const { assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');
const { getTestEnv } = require('./helpers');
const { customerData, professionalData, contractorData, adminData } = require('./fixtures');

function globalCounterData(overrides = {}) {
  return {
    dayKey: '2020-01-01',
    dailyCount: 5,
    updatedAt: '2020-01-01T00:00:00.000Z',
    ...overrides,
  };
}

function userCounterData(overrides = {}) {
  return {
    dayKey: '2020-01-01',
    dailyCount: 2,
    lastRequestAt: '2020-01-01T00:00:00.000Z',
    updatedAt: '2020-01-01T00:00:00.000Z',
    ...overrides,
  };
}

// Runs the full deny-everything test matrix against one rate-limit
// collection. `ai_rate_limits`, `translation_rate_limits`,
// `professional_ai_rate_limits`, and `contractor_ai_rate_limits` all
// share the identical Rules shape (match /{collection}/{document=**} {
// allow read, write: if false; }), so this is deliberately the same
// suite run four times rather than duplicated verbatim per collection.
function describeRateLimitCollection(collectionName) {
  describe(`${collectionName}/{document=**} security rules`, function () {
    this.timeout(20000);
    let testEnv;

    const custUid = `${collectionName}_rl_cust`;
    const proUid = `${collectionName}_rl_pro`;
    const conUid = `${collectionName}_rl_con`;
    const adminUid = `${collectionName}_rl_admin`;
    const targetUid = `${collectionName}_rl_target`; // the "own" counter owner
    const otherUid = `${collectionName}_rl_other`; // a different real user

    before(async () => {
      testEnv = await getTestEnv();
    });

    beforeEach(async () => {
      await testEnv.clearFirestore();
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const db = ctx.firestore();
        await setDoc(doc(db, 'users', custUid), customerData(custUid));
        await setDoc(doc(db, 'users', proUid), professionalData(proUid));
        await setDoc(doc(db, 'users', conUid), contractorData(conUid));
        await setDoc(doc(db, 'users', adminUid), adminData(adminUid));
        await setDoc(doc(db, 'users', targetUid), customerData(targetUid));
        await setDoc(doc(db, 'users', otherUid), customerData(otherUid));

        // Real-shaped seed documents so denial is proven against genuine
        // counter data, not just against documents that happen not to exist.
        await setDoc(doc(db, collectionName, 'global'), globalCounterData());
        await setDoc(doc(db, collectionName, `users_${targetUid}`), userCounterData());
        // A nested document under a counter doc — proves {document=**}
        // covers subcollections too, not just the two top-level documents.
        await setDoc(
          doc(db, collectionName, `users_${targetUid}`, 'debug', 'state'),
          { note: 'nested', updatedAt: '2020-01-01T00:00:00.000Z' },
        );
      });
    });

    // ── reads ─────────────────────────────────────────────────────────────
    describe('reads', () => {
      it('unauthenticated global read denied', async () => {
        const db = testEnv.unauthenticatedContext().firestore();
        await assertFails(getDoc(doc(db, collectionName, 'global')));
      });

      it('Customer global read denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, 'global')));
      });

      it('Professional global read denied', async () => {
        const db = testEnv.authenticatedContext(proUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, 'global')));
      });

      it('Contractor global read denied', async () => {
        const db = testEnv.authenticatedContext(conUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, 'global')));
      });

      it('Admin client global read denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, 'global')));
      });

      it("Customer own users_{uid} read denied", async () => {
        const db = testEnv.authenticatedContext(targetUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, `users_${targetUid}`)));
      });

      it("Customer another user's counter read denied", async () => {
        const db = testEnv.authenticatedContext(otherUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, `users_${targetUid}`)));
      });

      it('Admin users_{uid} read denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(getDoc(doc(db, collectionName, `users_${targetUid}`)));
      });
    });

    // ── creates ───────────────────────────────────────────────────────────
    describe('creates', () => {
      it('own users_{uid} create denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(setDoc(doc(db, collectionName, `users_${custUid}`), userCounterData()));
      });

      it("another user's counter create denied", async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(setDoc(doc(db, collectionName, `users_${otherUid}`), userCounterData()));
      });

      it('global create denied', async () => {
        await testEnv.withSecurityRulesDisabled(async (ctx) => {
          await deleteDoc(doc(ctx.firestore(), collectionName, 'global'));
        });
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(setDoc(doc(db, collectionName, 'global'), globalCounterData()));
      });

      it('Admin client create denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(setDoc(doc(db, collectionName, `users_${adminUid}`), userCounterData()));
      });

      it('malformed counter create denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(setDoc(doc(db, collectionName, `users_${custUid}`), {
          dayKey: 12345, // wrong type
          dailyCount: 'not-a-number',
        }));
      });
    });

    // ── updates ───────────────────────────────────────────────────────────
    describe('updates', () => {
      it('own count reset denied', async () => {
        const db = testEnv.authenticatedContext(targetUid).firestore();
        await assertFails(updateDoc(doc(db, collectionName, `users_${targetUid}`), { dailyCount: 0 }));
      });

      it('own cooldown reset denied', async () => {
        const db = testEnv.authenticatedContext(targetUid).firestore();
        await assertFails(updateDoc(
          doc(db, collectionName, `users_${targetUid}`),
          { lastRequestAt: '1970-01-01T00:00:00.000Z' },
        ));
      });

      it("another user's count change denied", async () => {
        const db = testEnv.authenticatedContext(otherUid).firestore();
        await assertFails(updateDoc(doc(db, collectionName, `users_${targetUid}`), { dailyCount: 999 }));
      });

      it('global dailyCount decrease denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(updateDoc(doc(db, collectionName, 'global'), { dailyCount: -1 }));
      });

      it('global dailyCount increase denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(updateDoc(doc(db, collectionName, 'global'), { dailyCount: 999999 }));
      });

      it('future dayKey/global time-bomb write denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(updateDoc(doc(db, collectionName, 'global'), {
          dayKey: '2999-01-01',
          dailyCount: 999999,
        }));
      });

      it('Admin client update denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(updateDoc(doc(db, collectionName, 'global'), { dailyCount: 0 }));
      });
    });

    // ── deletes ───────────────────────────────────────────────────────────
    describe('deletes', () => {
      it('own counter delete denied', async () => {
        const db = testEnv.authenticatedContext(targetUid).firestore();
        await assertFails(deleteDoc(doc(db, collectionName, `users_${targetUid}`)));
      });

      it("another user's counter delete denied", async () => {
        const db = testEnv.authenticatedContext(otherUid).firestore();
        await assertFails(deleteDoc(doc(db, collectionName, `users_${targetUid}`)));
      });

      it('global counter delete denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(deleteDoc(doc(db, collectionName, 'global')));
      });

      it('Admin client delete denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(deleteDoc(doc(db, collectionName, 'global')));
      });
    });

    // ── recursive / nested denial ────────────────────────────────────────
    describe('recursive/nested denial ({document=**})', () => {
      it('read a valid nested document path under the collection denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(getDoc(
          doc(db, collectionName, `users_${targetUid}`, 'debug', 'state'),
        ));
      });

      it('create a nested document denied', async () => {
        const db = testEnv.authenticatedContext(custUid).firestore();
        await assertFails(setDoc(
          doc(db, collectionName, `users_${custUid}`, 'debug', 'state'),
          { note: 'hack', updatedAt: '2020-01-01T00:00:00.000Z' },
        ));
      });

      it('update a nested document denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(updateDoc(
          doc(db, collectionName, `users_${targetUid}`, 'debug', 'state'),
          { note: 'hacked' },
        ));
      });

      it('delete a nested document denied', async () => {
        const db = testEnv.authenticatedContext(adminUid).firestore();
        await assertFails(deleteDoc(
          doc(db, collectionName, `users_${targetUid}`, 'debug', 'state'),
        ));
      });
    });
  });
}

describeRateLimitCollection('ai_rate_limits');
describeRateLimitCollection('translation_rate_limits');
describeRateLimitCollection('professional_ai_rate_limits');
describeRateLimitCollection('contractor_ai_rate_limits');
